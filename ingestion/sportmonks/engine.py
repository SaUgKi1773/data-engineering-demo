"""
Metadata-driven ingestion engine for Sportmonks v3 bronze layer.

Reads ENDPOINT_MANIFEST from config.py and dispatches each entry to the
appropriate strategy handler.  No hard-coded loader functions exist here —
adding an entry to the manifest is all that is needed to ingest a new endpoint.

Every table is loaded on every run (full and incremental).  The delete strategy
in the manifest — not the run mode — controls the refresh granularity:

  global      → full truncate + reload the entire table
  seasonal    → delete current season rows, reload; prior seasons untouched
  date_window → delete rolling window rows, reload; other dates untouched

The only behavioural difference between modes is scope for seasonal / date entries:
  full        → seasonal entries cover ALL in-scope seasons;
                date_based iterates 90-day chunks across every season's range
  incremental → seasonal entries cover CURRENT season only;
                date_based uses a rolling -7 / +60 day window around today

Strategy handlers
-----------------
static              → single paginated call
seasons_from_league → bootstrap: extracts seasons[] from league JSON;
                      populates ctx.all_seasons + ctx.current_seasons
season_based        → iterate each season_id (scope depends on mode)
stage_based         → iterate each stage_id per season
round_based         → iterate each round_id per season
team_based          → iterate ALL historical team IDs (current load + DB);
                      always covers every team regardless of run mode
pair_based          → every unique (team1_id, team2_id) combination (H2H)
date_based          → season-range chunks (full) or rolling window (incremental)
"""

import json
import logging
from datetime import date, timedelta

import duckdb
import requests

from api import get, get_paginated
from config import (
    API_BASE,
    DATE_CHUNK_DAYS,
    ENDPOINT_MANIFEST,
    FIRST_SEASON_YEAR,
    INCREMENTAL_DAYS_BACK,
    INCREMENTAL_DAYS_FORWARD,
    LEAGUE_IDS,
)
from db import delete_global, delete_by_season, delete_by_date, insert_batch

log = logging.getLogger(__name__)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _rows(records, season_id=None, date_fn=None, league_id=None):
    return [
        (r["id"], json.dumps(r), season_id, date_fn(r) if date_fn else None, league_id)
        for r in records
    ]


def _date_chunks(start: date, end: date, days: int = DATE_CHUNK_DAYS):
    cursor = start
    while cursor <= end:
        yield cursor.isoformat(), min(cursor + timedelta(days=days - 1), end).isoformat()
        cursor += timedelta(days=days)


def _merged_season_ranges(seasons: list) -> list:
    """
    Collapse the seasons' [starting_at, ending_at] ranges into a minimal set of
    non-overlapping intervals.  With multiple leagues running in parallel
    (Danish and Scottish seasons overlap almost entirely), this ensures each
    calendar window is fetched from the date-range endpoint exactly once.
    Gaps between intervals (summer breaks) are preserved, not spanned.
    """
    ranges = sorted(
        (date.fromisoformat(s["starting_at"]), date.fromisoformat(s["ending_at"]))
        for s in seasons
    )
    merged = []
    for start, end in ranges:
        if merged and start <= merged[-1][1] + timedelta(days=1):
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    return merged


def _all_team_ids(team_map: dict) -> set:
    return {t["id"] for teams in team_map.values() for t in teams}


def _resolve_all_team_ids(conn, team_map: dict) -> set:
    """
    Return the union of team IDs from team_map (just-loaded seasons) and every
    row already stored in bronze.sportmonks__teams (from previous runs).
    This ensures that in incremental mode — where team_map only contains the
    current season — team_based loaders still cover all historical teams and
    don't wipe prior-season data from coaches / transfers / rivals / h2h.
    """
    ids = _all_team_ids(team_map)
    try:
        rows = conn.execute(
            "SELECT DISTINCT id FROM bronze.sportmonks__teams"
        ).fetchall()
        ids |= {row[0] for row in rows}
    except duckdb.CatalogException:
        pass  # table not yet created on the very first run
    return ids





def _params(entry: dict) -> dict:
    p = {}
    if entry.get("includes"):
        p["include"] = entry["includes"]
    if entry.get("extra_params"):
        p.update(entry["extra_params"])
    return p


def _base(entry: dict) -> str:
    return entry.get("base", API_BASE)


# ── Context ────────────────────────────────────────────────────────────────────

class _Context:
    """Runtime state built up as the engine walks the manifest in order."""
    def __init__(self, leagues: list = None, seasons: list = None):
        self.league_scope: list = leagues or LEAGUE_IDS
        # True when the run covers only a subset of the configured leagues —
        # deletes on league-tagged tables must then be league-scoped so the
        # out-of-scope leagues' rows survive the run.
        self.league_subset: bool = set(self.league_scope) != set(LEAGUE_IDS)
        self.season_scope: set = set(seasons) if seasons else None  # season names
        self.all_seasons: list = []      # iterated seasons (>= FIRST_SEASON_YEAR, in scope)
        self.current_seasons: list = []  # one current season PER league (is_current or latest)
        self.season_league: dict = {}    # {season_id: league_id}
        self.stage_map: dict = {}        # {season_id: [stage, ...]}
        self.round_map: dict = {}        # {season_id: [round, ...]}
        self.team_map: dict = {}         # {season_id: [team, ...]}  (mode-scoped)
        self.all_team_ids: set = set()   # ALL historical team IDs (DB + current load)

    def league_delete_scope(self) -> list:
        """League ids to constrain deletes to — None means unscoped (all)."""
        return self.league_scope if self.league_subset else None


# ── Strategy handlers ──────────────────────────────────────────────────────────

def _handle_static(conn, entry: dict, ctx: _Context) -> int:
    """
    Single paginated call — or one call per league in scope when the path
    contains a {league_id} placeholder (rows are then tagged with their
    league, and a league-scoped run only deletes/reloads its own rows).
    Static tables without the placeholder are cross-league by nature and are
    always fully truncated + reloaded regardless of league scope.
    """
    total = 0
    if "{league_id}" in entry["path"]:
        delete_global(conn, entry["table"], ctx.league_delete_scope())
        for league_id in ctx.league_scope:
            records = get_paginated(
                entry["path"].format(league_id=league_id), _params(entry), _base(entry)
            )
            insert_batch(conn, entry["table"], _rows(records, league_id=league_id))
            total += len(records)
    else:
        delete_global(conn, entry["table"])
        records = get_paginated(entry["path"], _params(entry), _base(entry))
        insert_batch(conn, entry["table"], _rows(records))
        total = len(records)
    if not total:
        log.warning("%-46s 0 rows — check endpoint or filter config", entry["table"] + ":")
    log.info("%-46s %d rows", entry["table"] + ":", total)
    return total


def _handle_seasons_from_league(conn, entry: dict, ctx: _Context) -> list:
    """
    For each league in scope: fetch the league record with include=seasons,
    extract the seasons[] array, and filter by FIRST_SEASON_YEAR.  Persist the
    league's COMPLETE season list (bronze stays whole even on --seasons runs)
    and populate ctx.all_seasons / ctx.current_seasons (one current season per
    league) / ctx.season_league so season-based entries iterate correctly.
    A season scope (--seasons) narrows only the ITERATION lists, not storage.
    """
    delete_global(conn, entry["table"], ctx.league_delete_scope())
    all_seasons, current_seasons = [], []
    for league_id in ctx.league_scope:
        raw = get(
            entry["path"].format(league_id=league_id),
            {"include": "seasons"}, _base(entry),
        )["data"]["seasons"]
        seasons = sorted(
            [s for s in raw if int(s["name"][:4]) >= FIRST_SEASON_YEAR],
            key=lambda s: s["starting_at"],
        )
        insert_batch(conn, entry["table"], _rows(seasons, league_id=league_id))
        ctx.season_league.update({s["id"]: league_id for s in seasons})

        in_scope = seasons
        if ctx.season_scope:
            in_scope = [s for s in seasons if s["name"] in ctx.season_scope]
            if not in_scope:
                log.warning("league %d: no seasons match scope %s",
                            league_id, sorted(ctx.season_scope))
        current = [s for s in in_scope if s.get("is_current")]
        if not current and not ctx.season_scope:
            current = [max(seasons, key=lambda s: s["starting_at"])]
        all_seasons.extend(in_scope)
        current_seasons.extend(current)

        log.info("%-46s league %-6d %d rows (%s – %s), %d in scope",
                 entry["table"] + ":", league_id, len(seasons),
                 seasons[0]["name"], seasons[-1]["name"], len(in_scope))

    ctx.all_seasons = sorted(all_seasons, key=lambda s: s["starting_at"])
    ctx.current_seasons = current_seasons
    if ctx.season_scope and not current_seasons:
        log.warning("season scope contains no current season — "
                    "incremental-mode seasonal entries will load 0 seasons")
    log.info("current season(s): %s",
             [f"{s['name']} (league {ctx.season_league[s['id']]})"
              for s in ctx.current_seasons])
    return ctx.all_seasons


def _handle_season_based(conn, entry: dict, seasons: list, ctx: _Context) -> dict:
    """
    Iterate each season and call the paginated endpoint.
    Returns {season_id: [record, ...]} so the caller can update context maps.
    Deduplicates within each season call (same ID can occasionally appear twice
    when the API paginates an edge-case boundary).
    """
    result_map = {}
    for season in seasons:
        sid = season["id"]
        lid = ctx.season_league.get(sid)
        delete_by_season(conn, entry["table"], sid)
        records = get_paginated(
            entry["path"].format(season_id=sid),
            _params(entry),
            _base(entry),
        )
        seen, rows = set(), []
        for r in records:
            if r["id"] not in seen:
                seen.add(r["id"])
                rows.append((r["id"], json.dumps(r), sid, None, lid))
        insert_batch(conn, entry["table"], rows)
        result_map[sid] = records
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
    return result_map



def _handle_stage_based(conn, entry: dict, seasons: list, ctx: _Context) -> int:
    """Iterate each stage within each season; deduplicates across stages."""
    total = 0
    for season in seasons:
        sid = season["id"]
        lid = ctx.season_league.get(sid)
        stages = ctx.stage_map.get(sid) or get_paginated(
            f"/stages/seasons/{sid}", base=API_BASE
        )
        delete_by_season(conn, entry["table"], sid)
        rows, seen = [], set()
        for stage in stages:
            for r in get_paginated(
                entry["path"].format(stage_id=stage["id"]),
                _params(entry),
                _base(entry),
            ):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None, lid))
        insert_batch(conn, entry["table"], rows)
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
        total += len(rows)
    return total


def _handle_round_based(conn, entry: dict, seasons: list, ctx: _Context) -> int:
    """Iterate each round within each season; deduplicates across rounds."""
    total = 0
    for season in seasons:
        sid = season["id"]
        lid = ctx.season_league.get(sid)
        rounds = ctx.round_map.get(sid) or get_paginated(
            f"/rounds/seasons/{sid}", base=API_BASE
        )
        delete_by_season(conn, entry["table"], sid)
        rows, seen = [], set()
        for rnd in rounds:
            for r in get_paginated(
                entry["path"].format(round_id=rnd["id"]),
                _params(entry),
                _base(entry),
            ):
                if r["id"] not in seen:
                    seen.add(r["id"])
                    rows.append((r["id"], json.dumps(r), sid, None, lid))
        insert_batch(conn, entry["table"], rows)
        log.info("%-46s %-12s %d rows", entry["table"] + ":", season["name"], len(rows))
        total += len(rows)
    return total


def _handle_team_based(conn, entry: dict, ctx: _Context) -> int:
    """Iterate all unique team IDs across every season; deduplicates entities."""
    team_ids = ctx.all_team_ids
    delete_global(conn, entry["table"])
    rows, seen = [], set()
    for team_id in sorted(team_ids):
        for r in get_paginated(
            entry["path"].format(team_id=team_id),
            _params(entry),
            _base(entry),
        ):
            if r["id"] not in seen:
                seen.add(r["id"])
                # league left NULL — a team (and its transfers/rivals) is not
                # bound to a single league
                rows.append((r["id"], json.dumps(r), None, None, None))
    insert_batch(conn, entry["table"], rows)
    log.info("%-46s %d rows (%d teams)", entry["table"] + ":", len(rows), len(team_ids))
    return len(rows)



def _fetch_date_window(conn, entry: dict, ctx: _Context,
                       from_date: str, to_date: str) -> int:
    """
    Fetch one date window and upsert.  Behaviour is controlled by optional
    manifest keys:
      league_filter (bool, default True)  — keep only records whose league_id
                                            is in the run's league scope
      date_field    (str, default "starting_at") — field to store as _fixture_date
    Returns 400 from the API if the window is empty — treated as zero rows.
    """
    try:
        records = get_paginated(
            entry["path"].format(from_date=from_date, to_date=to_date),
            _params(entry),
            _base(entry),
        )
    except requests.HTTPError as exc:
        if exc.response is not None and exc.response.status_code in (400, 422):
            # 400: paged past last page (normal stop signal)
            # 422: API rejects the date range (e.g. transfers endpoint has limited history)
            if exc.response.status_code == 422:
                log.warning("%-46s %s → %s  skipped (422 — date range not supported by API)",
                            entry["table"] + ":", from_date, to_date)
            return 0
        raise

    league_filter = entry.get("league_filter", True)
    date_field    = entry.get("date_field", "starting_at")

    if league_filter:
        kept = [f for f in records if f.get("league_id") in ctx.league_scope]
    else:
        kept = records

    rows = [
        (f["id"], json.dumps(f), f.get("season_id"),
         (f.get(date_field) or "")[:10] or None,
         f.get("league_id"))
        for f in kept
    ]
    insert_batch(conn, entry["table"], rows)
    filtered = len(records) - len(kept)
    if league_filter:
        log.info("%-46s %s → %s  %d rows (%d other-league filtered)",
                 entry["table"] + ":", from_date, to_date, len(rows), filtered)
    else:
        log.info("%-46s %s → %s  %d rows",
                 entry["table"] + ":", from_date, to_date, len(rows))
    return len(rows)


def _handle_date_based_full(conn, entry: dict, ctx: _Context) -> int:
    """
    Full load: iterate 90-day chunks across the merged season date ranges.
    Ranges are merged across all leagues (see _merged_season_ranges) — each
    window returns every league's records in one call and is filtered
    client-side, so per-league iteration would only duplicate API traffic.
    """
    total = 0
    for start, end in _merged_season_ranges(ctx.all_seasons):
        for from_date, to_date in _date_chunks(start, end):
            delete_by_date(conn, entry["table"], from_date, to_date,
                           ctx.league_delete_scope())
            total += _fetch_date_window(conn, entry, ctx, from_date, to_date)
    log.info("%-46s full load complete: %d rows", entry["table"] + ":", total)
    return total


def _handle_date_based_incremental(conn, entry: dict, ctx: _Context) -> int:
    """Incremental load: delete-and-reload a rolling past+future window."""
    days_back    = entry.get("days_back",    INCREMENTAL_DAYS_BACK)
    days_forward = entry.get("days_forward", INCREMENTAL_DAYS_FORWARD)
    from_date = (date.today() - timedelta(days=days_back)).isoformat()
    to_date   = (date.today() + timedelta(days=days_forward)).isoformat()
    delete_by_date(conn, entry["table"], from_date, to_date,
                   ctx.league_delete_scope())
    n = _fetch_date_window(conn, entry, ctx, from_date, to_date)
    log.info("%-46s incremental: %d rows (%s → %s)",
             entry["table"] + ":", n, from_date, to_date)
    return n


# ── Dispatch ───────────────────────────────────────────────────────────────────

def _dispatch(conn, entry: dict, ctx: _Context, mode: str) -> None:
    strategy = entry["strategy"]
    # Seasonal entries use all seasons in full mode, current season(s) in incremental
    seasons = ctx.all_seasons if mode == "full" else ctx.current_seasons

    if strategy == "static":
        _handle_static(conn, entry, ctx)

    elif strategy == "seasons_from_league":
        _handle_seasons_from_league(conn, entry, ctx)

    elif strategy == "season_based":
        result = _handle_season_based(conn, entry, seasons, ctx)
        # Update context maps for entries that drive downstream iteration
        key = entry.get("context_key")
        if key == "stage_map":
            ctx.stage_map.update(result)
        elif key == "round_map":
            ctx.round_map.update(result)
        elif key == "team_map":
            ctx.team_map.update(result)
            # Supplement with every team ID ever stored in the DB so that
            # team_based entries (coaches, transfers, rivals, h2h) cover all
            # historical teams even when running in incremental mode.
            ctx.all_team_ids = _resolve_all_team_ids(conn, ctx.team_map)

    elif strategy == "stage_based":
        _handle_stage_based(conn, entry, seasons, ctx)

    elif strategy == "round_based":
        _handle_round_based(conn, entry, seasons, ctx)

    elif strategy == "team_based":
        _handle_team_based(conn, entry, ctx)

    elif strategy == "date_based":
        if mode == "full":
            _handle_date_based_full(conn, entry, ctx)
        else:
            _handle_date_based_incremental(conn, entry, ctx)

    else:
        log.warning("Unknown strategy %r for %s — skipped", strategy, entry["table"])


# ── Public entry points ────────────────────────────────────────────────────────

_VALID_STRATEGIES = {
    "static", "seasons_from_league", "season_based", "stage_based",
    "round_based", "team_based", "pair_based", "date_based",
}
_REQUIRED_KEYS = {"table", "path", "strategy", "delete", "includes"}

def _validate_manifest() -> None:
    errors = []
    for i, entry in enumerate(ENDPOINT_MANIFEST):
        missing = _REQUIRED_KEYS - entry.keys()
        if missing:
            errors.append(f"entry[{i}] ({entry.get('table', '?')}): missing keys {missing}")
        if entry.get("strategy") not in _VALID_STRATEGIES:
            errors.append(f"entry[{i}] ({entry.get('table', '?')}): unknown strategy {entry.get('strategy')!r}")
    if errors:
        raise ValueError("ENDPOINT_MANIFEST validation failed:\n" + "\n".join(errors))


def run(conn, mode: str = "incremental", tables: set = None,
        leagues: list = None, seasons: list = None) -> None:
    """
    Execute the ingestion pipeline driven by ENDPOINT_MANIFEST.

    mode "full"        — all seasons iterated for seasonal tables;
                         full season-range chunks for fixtures
    mode "incremental" — current season only for seasonal tables;
                         rolling -7 / +60 day window for fixtures
    tables             — optional set of table names to restrict the run to;
                         if None, all manifest entries for the given mode are run
    leagues            — optional list of league ids to scope the run to (must
                         be a subset of LEAGUE_IDS).  Deletes on league-tagged
                         tables are then league-scoped; cross-league tables
                         (players, transfers, rivals, reference data) are still
                         refreshed in full.
    seasons            — optional list of season names (e.g. "2015/2016") to
                         restrict seasonal / fixture iteration to.  Intended
                         for --mode full backfills; bronze season storage stays
                         complete regardless.
    """
    if mode not in ("full", "incremental"):
        raise ValueError(f"mode must be 'full' or 'incremental', got {mode!r}")
    if leagues:
        unknown = set(leagues) - set(LEAGUE_IDS)
        if unknown:
            raise ValueError(f"unknown league ids {sorted(unknown)} — "
                             f"configured leagues: {LEAGUE_IDS}")

    _validate_manifest()
    log.info("=== %s LOAD START ===", mode.upper())
    if leagues:
        log.info("league scope: %s", leagues)
    if seasons:
        log.info("season scope: %s", seasons)

    ctx = _Context(leagues=leagues, seasons=seasons)
    active = [e for e in ENDPOINT_MANIFEST if mode in e.get("modes", ["full"])]
    if tables:
        active = [e for e in active if e["table"] in tables]

    for entry in active:
        try:
            _dispatch(conn, entry, ctx, mode)
        except Exception as exc:
            log.error("FAILED  %s  (%s): %s", entry["table"], entry["strategy"], exc)
            raise

    log.info("=== %s LOAD COMPLETE ===", mode.upper())
