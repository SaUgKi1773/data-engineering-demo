"""
Prove a gold change did what you intended — and nothing else.

Gold is the product: 96 marts read it, and surrogate keys are baked into
incremental dimensions that must never be rebuilt. So every gold change ships
with evidence, not confidence.

Workflow:

    python scripts/pull_from_prod.py            # local gold == prod gold
    python scripts/gold_verify.py snapshot      # freeze that as gold_baseline
    cd dbt && ../.venv/bin/dbt run --select gold.*
    python scripts/gold_verify.py diff          # what actually changed?

`diff` exits 1 when anything differs, so it can gate a PR. A refactor that is
meant to change nothing should print "IDENTICAL" for every relation; a change
that adds rows should add exactly the rows you expect and touch nothing else.

Checks per relation:
  * schema drift        — columns added or removed
  * content             — rows only in baseline / only in candidate
                          (EXCEPT ALL both ways, over common columns)
  * surrogate-key drift — an existing natural key whose SK moved, or an SK
                          reassigned to a different entity. This is the one
                          that silently corrupts every historical fact.
  * orphan SKs          — fact rows pointing at dimension rows that do not
                          exist (checked on the candidate alone)

Usage:
    python scripts/gold_verify.py snapshot [--db PATH]
    python scripts/gold_verify.py diff [--db PATH] [--only TABLE ...] [--samples N]
"""

import argparse
import json
import logging
import os
import sys

import duckdb

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_MANIFEST = os.path.join(_PROJECT_ROOT, "dbt", "target", "manifest.json")

GOLD = "gold"
BASELINE = "gold_baseline"


def q(name: str) -> str:
    """Quote an identifier."""
    return '"' + name.replace('"', '""') + '"'


def natural_keys() -> dict[str, list[str]]:
    """Model name -> natural key columns, read from the models' own unique_key
    configs so the harness can never disagree with the models about grain."""
    if not os.path.exists(_MANIFEST):
        log.warning("No dbt manifest at %s — SK drift checks will be skipped", _MANIFEST)
        return {}
    manifest = json.load(open(_MANIFEST))
    keys = {}
    for node in manifest.get("nodes", {}).values():
        if node.get("resource_type") != "model":
            continue
        if not node.get("path", "").startswith("gold"):
            continue
        uk = node.get("config", {}).get("unique_key")
        if not uk:
            continue
        keys[node["name"]] = [uk] if isinstance(uk, str) else list(uk)
    return keys


def relations(conn, schema: str) -> dict[str, str]:
    """Relation name -> 'BASE TABLE' | 'VIEW'."""
    return {
        r[0]: r[1]
        for r in conn.execute(
            "SELECT table_name, table_type FROM information_schema.tables "
            "WHERE table_schema = ? ORDER BY table_name",
            [schema],
        ).fetchall()
    }


def columns(conn, schema: str, table: str) -> list[str]:
    return [
        r[0]
        for r in conn.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = ? AND table_name = ? ORDER BY ordinal_position",
            [schema, table],
        ).fetchall()
    ]


def cmd_snapshot(conn, args) -> int:
    tables = relations(conn, GOLD)
    if not tables:
        log.error("No relations in schema '%s' — pull from prod first", GOLD)
        return 1

    conn.execute(f"DROP SCHEMA IF EXISTS {BASELINE} CASCADE")
    conn.execute(f"CREATE SCHEMA {BASELINE}")
    for t in tables:
        # CTAS materialises views too, so the baseline is a stable copy even
        # when the candidate side is a view.
        conn.execute(f"CREATE TABLE {BASELINE}.{q(t)} AS SELECT * FROM {GOLD}.{q(t)}")
    log.info("Snapshotted %d relations into %s", len(tables), BASELINE)
    return 0


def sk_column(cols: list[str], table: str) -> str | None:
    """A dimension's surrogate key: <entity>_sk matching the table name."""
    expected = table.replace("dim_", "", 1) + "_sk"
    return expected if expected in cols else None


def check_sk_drift(conn, table: str, key_cols: list[str], sk: str, samples: int) -> list[str]:
    """An existing entity must keep its surrogate key forever."""
    findings = []
    on = " AND ".join(
        f"b.{q(c)} IS NOT DISTINCT FROM c.{q(c)}" for c in key_cols
    )
    # Sentinel rows (-1 Unknown / -2 Not Applicable) carry NULL natural keys.
    # They are not entities and cannot be identified by key, so they are
    # filtered out of the baseline side rather than added to the join
    # condition — a NULL key must exclude the row, not fail to match.
    real = " AND ".join(f"b.{q(c)} IS NOT NULL" for c in key_cols)
    moved = conn.execute(
        f"SELECT COUNT(*) FROM {BASELINE}.{q(table)} b "
        f"JOIN {GOLD}.{q(table)} c ON {on} "
        f"WHERE {real} AND b.{q(sk)} IS DISTINCT FROM c.{q(sk)}"
    ).fetchone()[0]
    if moved:
        findings.append(f"    !! {moved} entities changed surrogate key (CORRUPTS HISTORY)")
        rows = conn.execute(
            f"SELECT {', '.join('b.' + q(c) for c in key_cols)}, b.{q(sk)}, c.{q(sk)} "
            f"FROM {BASELINE}.{q(table)} b JOIN {GOLD}.{q(table)} c ON {on} "
            f"WHERE {real} AND b.{q(sk)} IS DISTINCT FROM c.{q(sk)} LIMIT {samples}"
        ).fetchall()
        for r in rows:
            findings.append(f"       key={r[:-2]} sk {r[-2]} -> {r[-1]}")

    reused = conn.execute(
        f"SELECT COUNT(*) FROM {BASELINE}.{q(table)} b "
        f"JOIN {GOLD}.{q(table)} c ON b.{q(sk)} = c.{q(sk)} "
        f"WHERE {real} AND NOT ({on})"
    ).fetchone()[0]
    if reused:
        findings.append(f"    !! {reused} surrogate keys now point at a different entity")

    lost = conn.execute(
        f"SELECT COUNT(*) FROM {BASELINE}.{q(table)} b "
        f"WHERE {real} AND NOT EXISTS (SELECT 1 FROM {GOLD}.{q(table)} c WHERE {on})"
    ).fetchone()[0]
    if lost:
        findings.append(f"    !! {lost} entities disappeared (facts would orphan)")
    return findings


def count_orphans(conn, schema: str, table: str, cols: list[str], dims: set[str]) -> dict[str, int]:
    """Fact rows referencing a dimension row that does not exist. Measured per
    schema so pre-existing breakage is never blamed on the change under test."""
    out = {}
    for col in cols:
        if not col.endswith("_sk"):
            continue
        dim = "dim_" + col[: -len("_sk")]
        if dim not in dims:
            continue
        n = conn.execute(
            f"SELECT COUNT(*) FROM {schema}.{q(table)} f "
            f"WHERE f.{q(col)} IS NOT NULL AND NOT EXISTS ("
            f"  SELECT 1 FROM {schema}.{q(dim)} d WHERE d.{q(col)} = f.{q(col)})"
        ).fetchone()[0]
        if n:
            out[f"{table}.{col} -> {dim}"] = n
    return out


def cmd_diff(conn, args) -> int:
    base_rel = relations(conn, BASELINE)
    if not base_rel:
        log.error("No baseline — run 'snapshot' first")
        return 1
    cand_rel = relations(conn, GOLD)
    base_tables, cand_tables = set(base_rel), set(cand_rel)
    dims = {t for t in cand_tables if t.startswith("dim_")}
    keys = natural_keys()

    todo = sorted(base_tables | cand_tables)
    if args.only:
        todo = [t for t in todo if t in set(args.only)]

    print(f"\n{'RELATION':<30}{'BASELINE':>10}{'CANDIDATE':>11}{'DELTA':>8}  STATUS")
    print("-" * 78)

    details: list[str] = []
    changed = 0

    for t in todo:
        if t not in cand_tables:
            print(f"{t:<30}{'—':>10}{'—':>11}{'—':>8}  DROPPED")
            changed += 1
            continue
        if t not in base_tables:
            n = conn.execute(f"SELECT COUNT(*) FROM {GOLD}.{q(t)}").fetchone()[0]
            if cand_rel[t] == "VIEW":
                # pull_from_prod copies tables only, so gold views have no
                # baseline. They are stored queries over the tables above: if
                # those are identical the view is too, and a changed view
                # definition shows up in the git diff.
                print(f"{t:<30}{'—':>10}{n:>11}{'—':>8}  view (no baseline)")
            else:
                print(f"{t:<30}{'—':>10}{n:>11}{'—':>8}  NEW RELATION")
                changed += 1
            continue

        bcols, ccols = columns(conn, BASELINE, t), columns(conn, GOLD, t)
        common = [c for c in bcols if c in ccols]
        added, removed = [c for c in ccols if c not in bcols], [c for c in bcols if c not in ccols]

        bn = conn.execute(f"SELECT COUNT(*) FROM {BASELINE}.{q(t)}").fetchone()[0]
        cn = conn.execute(f"SELECT COUNT(*) FROM {GOLD}.{q(t)}").fetchone()[0]

        sel = ", ".join(q(c) for c in common)
        only_base = conn.execute(
            f"SELECT COUNT(*) FROM (SELECT {sel} FROM {BASELINE}.{q(t)} "
            f"EXCEPT ALL SELECT {sel} FROM {GOLD}.{q(t)})"
        ).fetchone()[0]
        only_cand = conn.execute(
            f"SELECT COUNT(*) FROM (SELECT {sel} FROM {GOLD}.{q(t)} "
            f"EXCEPT ALL SELECT {sel} FROM {BASELINE}.{q(t)})"
        ).fetchone()[0]

        notes: list[str] = []
        if added:
            notes.append(f"    + columns: {', '.join(added)}")
        if removed:
            notes.append(f"    - columns: {', '.join(removed)}")
        if only_base:
            notes.append(f"    {only_base} rows only in baseline (lost or altered)")
        if only_cand:
            notes.append(f"    {only_cand} rows only in candidate (new or altered)")

        sk = sk_column(ccols, t)
        if sk and t in keys and all(c in common for c in keys[t]):
            notes.extend(check_sk_drift(conn, t, keys[t], sk, args.samples))

        if notes:
            changed += 1
            status = "CHANGED"
            details.append(f"\n  {t}")
            details.extend(notes)
            if only_base or only_cand:
                rows = conn.execute(
                    f"SELECT {sel} FROM {GOLD}.{q(t)} EXCEPT ALL SELECT {sel} FROM {BASELINE}.{q(t)} "
                    f"LIMIT {args.samples}"
                ).fetchall()
                if rows:
                    details.append("    sample candidate-only rows:")
                    details.extend(f"       {r}" for r in rows)
        else:
            status = "identical"

        print(f"{t:<30}{bn:>10}{cn:>11}{cn - bn:>+8}  {status}")

    if details:
        print("\n" + "=" * 78)
        print("DETAIL")
        for line in details:
            print(line)

    # Referential integrity is an absolute invariant, not a diff: report both
    # sides so a change is judged on the orphans it ADDS, while pre-existing
    # breakage still gets named rather than quietly tolerated.
    base_dims = {t for t in base_tables if t.startswith("dim_")}
    base_orphans, cand_orphans = {}, {}
    for t in todo:
        if t not in cand_tables or t in dims:
            continue
        cand_orphans |= count_orphans(conn, GOLD, t, columns(conn, GOLD, t), dims)
        if t in base_tables:
            base_orphans |= count_orphans(conn, BASELINE, t, columns(conn, BASELINE, t), base_dims)

    new_orphans = 0
    if base_orphans or cand_orphans:
        print("\n" + "=" * 78)
        print("REFERENTIAL INTEGRITY (facts pointing at missing dimension rows)")
        for ref in sorted(set(base_orphans) | set(cand_orphans)):
            b, c = base_orphans.get(ref, 0), cand_orphans.get(ref, 0)
            if c > b:
                new_orphans += 1
                print(f"  !! {ref}: {b} -> {c}  ({c - b} NEW — introduced by this change)")
            elif c < b:
                print(f"  ok {ref}: {b} -> {c}  ({b - c} fixed)")
            else:
                print(f"  -- {ref}: {c}  (pre-existing, unchanged)")

    print("\n" + "-" * 78)
    if changed or new_orphans:
        if changed:
            print(f"{changed} of {len(todo)} relations CHANGED — confirm every line above is intended.")
        if new_orphans:
            print(f"{new_orphans} reference(s) gained orphans — these are regressions.")
        return 1
    print(f"IDENTICAL across all {len(todo)} relations.")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["snapshot", "diff"])
    parser.add_argument("--db", default=None, help="local DuckDB path")
    parser.add_argument("--only", nargs="*", help="limit diff to these relations")
    parser.add_argument("--samples", type=int, default=5, help="example rows to show (default 5)")
    args = parser.parse_args()

    path = args.db or os.environ.get(
        "DUCKDB_PATH", os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")
    )
    if not os.path.exists(path):
        log.error("No local DuckDB at %s", path)
        sys.exit(1)

    conn = duckdb.connect(path)
    try:
        sys.exit(cmd_snapshot(conn, args) if args.command == "snapshot" else cmd_diff(conn, args))
    finally:
        conn.close()


if __name__ == "__main__":
    main()
