"""
Refresh the public share database from prod gold.

MotherDuck shares are database-wide — there is no way to share a single schema
out of a database. So the public share is its own database holding a physical
copy of gold, and this script rebuilds that copy after the nightly gold run.

Gold views are materialised as tables. A view carries a fully qualified
reference to the database it was built in, which a share recipient cannot
resolve, so copying them as views would hand out broken objects.

Objects are discovered from the catalog rather than listed here, so a new gold
model joins the share automatically — and therefore becomes public — the next
night after it ships.

Usage:
  python scripts/refresh_share.py                      # superligaen.gold → superligaen_share.gold
  python scripts/refresh_share.py --dry-run            # print the plan, change nothing
  python scripts/refresh_share.py --target my_sandbox
"""

import argparse
import logging
import os

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="superligaen", help="Source MotherDuck database (default: superligaen)")
    parser.add_argument("--target", default="superligaen_share", help="Share MotherDuck database (default: superligaen_share)")
    parser.add_argument("--schema", default="gold", help="Schema to publish (default: gold)")
    parser.add_argument("--dry-run", action="store_true", help="Log what would change without writing")
    args = parser.parse_args()

    if args.source == args.target:
        raise SystemExit("--source and --target must differ")

    token = os.environ["MOTHERDUCK_TOKEN"]

    log.info("Connecting to MotherDuck: %s", args.source)
    conn = duckdb.connect(f"md:{args.source}?motherduck_token={token}")

    # Tables and views together — both land in the share as tables
    objects = conn.execute(
        """
        SELECT table_name AS name FROM duckdb_tables()
        WHERE database_name = ? AND schema_name = ?
        UNION ALL
        SELECT view_name AS name FROM duckdb_views()
        WHERE database_name = ? AND schema_name = ?
        ORDER BY name
        """,
        [args.source, args.schema, args.source, args.schema],
    ).fetchall()
    names = [row[0] for row in objects]

    if not names:
        raise SystemExit(f"No objects found in {args.source}.{args.schema} — refusing to publish an empty share")

    log.info("Found %d objects in %s.%s", len(names), args.source, args.schema)

    if args.dry_run:
        for name in names:
            log.info("  would copy %s.%s.%s", args.source, args.schema, name)
        conn.close()
        return

    conn.execute(f"CREATE DATABASE IF NOT EXISTS {args.target}")
    conn.execute(f"CREATE SCHEMA IF NOT EXISTS {args.target}.{args.schema}")

    # Copy. CREATE OR REPLACE keeps the script re-runnable; consumers reading
    # mid-run see a mix of last night's and tonight's tables, which is fine for
    # a daily-refreshed share but is why this runs after DQ tests, not before.
    mismatches = []
    for name in names:
        conn.execute(
            f'CREATE OR REPLACE TABLE {args.target}.{args.schema}."{name}" AS '
            f'SELECT * FROM {args.source}.{args.schema}."{name}"'
        )
        source_rows = conn.execute(f'SELECT COUNT(*) FROM {args.source}.{args.schema}."{name}"').fetchone()[0]
        target_rows = conn.execute(f'SELECT COUNT(*) FROM {args.target}.{args.schema}."{name}"').fetchone()[0]
        log.info("  %s → %d rows", name, target_rows)
        if source_rows != target_rows:
            mismatches.append(f"{name}: source {source_rows} vs share {target_rows}")

    # Drop anything the share still carries that gold no longer has
    stale = conn.execute(
        """
        SELECT table_name AS name, 'TABLE' AS kind FROM duckdb_tables()
        WHERE database_name = ? AND schema_name = ?
        UNION ALL
        SELECT view_name AS name, 'VIEW' AS kind FROM duckdb_views()
        WHERE database_name = ? AND schema_name = ?
        """,
        [args.target, args.schema, args.target, args.schema],
    ).fetchall()
    for name, kind in stale:
        if name not in names:
            log.info("  dropping stale %s %s", kind.lower(), name)
            conn.execute(f'DROP {kind} IF EXISTS {args.target}.{args.schema}."{name}"')

    conn.close()

    if mismatches:
        raise SystemExit("Row count mismatch after copy:\n  " + "\n  ".join(mismatches))

    log.info("Done — published %d objects to %s.%s", len(names), args.target, args.schema)


if __name__ == "__main__":
    main()
