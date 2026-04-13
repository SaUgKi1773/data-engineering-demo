"""
Silver transformation runner — entry point for all silver layer loads.

Mirrors the bronze ingestion/run.py signature exactly.

Load modes:
  Daily incremental  — Group 2 refreshes current season; Group 3 refreshes
                       fixtures and detail tables within the lookback window.
  Seasonal load      — Groups 1-5 refreshed, season-scoped tables limited to
                       the specified season.
  Initial / full load — All tables replaced in full.

Usage:
  python transformations/run_silver.py                                 # daily incremental
  python transformations/run_silver.py --lookback 5                    # custom lookback window
  python transformations/run_silver.py --full-load                     # full replace all tables
  python transformations/run_silver.py --full-load --league 119        # one league (full)
  python transformations/run_silver.py --full-load --season 2025       # one season
  python transformations/run_silver.py --full-load --league 119 --season 2025
  python transformations/run_silver.py --db superligaen                # target prod database
"""

import argparse
import logging
import os
from datetime import date, timedelta
from pathlib import Path

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

SQL_DIR = Path(__file__).parent / "silver"

# ---------------------------------------------------------------------------
# Table groups — mirror bronze config.py groupings
# ---------------------------------------------------------------------------

# Always full replace (CREATE OR REPLACE TABLE in the SQL file)
FULL_REPLACE_TABLES = [
    "leagues",        # Group 1
    "venues",         # Group 4
]

# Season-scoped: filter = league_id = X AND season = Y
SEASON_TABLES = [
    "standings",
    "topscorers",
    "topassists",
    "topyellowcards",
    "topredcards",
    "injuries",
    "teams",
    "rounds",
    "players",
]

# Date-windowed (incremental) or season-scoped: filter varies by mode
FIXTURE_TABLES = [
    "fixtures",
    "fixture_events",
    "fixture_statistics",
    "fixture_lineups",
    "fixture_players",
    "fixture_predictions",
    "fixture_odds",
]


# ---------------------------------------------------------------------------
# Core execution helpers
# ---------------------------------------------------------------------------

def _connect(target_db: str | None) -> tuple[duckdb.DuckDBPyConnection, str]:
    db = target_db or os.getenv("TARGET_DB", "superligaen_dev")
    token = os.environ["MOTHERDUCK_TOKEN"]
    conn = duckdb.connect(f"md:{db}?motherduck_token={token}")
    log.info("Connected to MotherDuck: %s", db)
    return conn, db


def _run_sql(conn: duckdb.DuckDBPyConnection, db: str, table: str,
             delete_filter: str = "TRUE", insert_filter: str = "TRUE") -> None:
    """Read a SQL file, substitute placeholders, execute each statement."""
    sql = (SQL_DIR / f"{table}.sql").read_text().format(
        db=db,
        delete_filter=delete_filter,
        insert_filter=insert_filter,
    )
    # Strip single-line comments then split on statement boundaries
    stripped = "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")
    )
    for stmt in stripped.split(";"):
        stmt = stmt.strip()
        if stmt:
            conn.execute(stmt)
    log.info("  %-30s  filter: %s", f"{db}.silver.{table}", insert_filter)


# ---------------------------------------------------------------------------
# Helpers to derive league / season from bronze
# ---------------------------------------------------------------------------

def _default_league(conn: duckdb.DuckDBPyConnection, db: str) -> int:
    row = conn.execute(
        f"SELECT league_id FROM {db}.bronze.api_football__leagues LIMIT 1"
    ).fetchone()
    if not row:
        raise RuntimeError("No leagues in bronze — run ingestion first")
    return row[0]


def _current_season(conn: duckdb.DuckDBPyConnection, db: str, league_id: int) -> int:
    row = conn.execute(
        f"""
        SELECT (s->>'$.year')::INTEGER
        FROM {db}.bronze.api_football__leagues,
        UNNEST(raw_json::JSON[]) AS t1(elem),
        UNNEST((elem->'$.seasons')::JSON[]) AS t2(s)
        WHERE league_id = {league_id}
          AND (s->>'$.current')::BOOLEAN = true
        LIMIT 1
        """
    ).fetchone()
    if not row:
        raise RuntimeError(f"Cannot determine current season for league {league_id}")
    return row[0]


# ---------------------------------------------------------------------------
# Main run logic
# ---------------------------------------------------------------------------

def run(
    lookback_days: int = 2,
    full_load: bool = False,
    league_id: int | None = None,
    season: int | None = None,
    target_db: str | None = None,
) -> None:
    conn, db = _connect(target_db)

    if full_load and not season:
        # ------------------------------------------------------------------
        # Full load — pass TRUE so every SQL file does a complete replace
        # ------------------------------------------------------------------
        log.info("=== Full silver load — %s.silver ===", db)
        for table in FULL_REPLACE_TABLES + SEASON_TABLES + FIXTURE_TABLES:
            _run_sql(conn, db, table)

    elif full_load and season:
        # ------------------------------------------------------------------
        # Seasonal load — reference tables full replace; Groups 2 & 3 scoped
        # ------------------------------------------------------------------
        lid = league_id or _default_league(conn, db)
        scope = f"league_id = {lid} AND season = {season}"
        log.info("=== Seasonal silver load — %s.silver  league=%d  season=%d ===", db, lid, season)

        for table in FULL_REPLACE_TABLES:
            _run_sql(conn, db, table)
        for table in SEASON_TABLES + FIXTURE_TABLES:
            _run_sql(conn, db, table, delete_filter=scope, insert_filter=scope)

    else:
        # ------------------------------------------------------------------
        # Daily incremental — reference tables full replace; season tables
        # scoped to current season; fixture tables scoped to lookback window
        # ------------------------------------------------------------------
        lid        = league_id or _default_league(conn, db)
        cur_season = _current_season(conn, db, lid)
        from_date  = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date    = date.today().isoformat()
        season_scope  = f"league_id = {lid} AND season = {cur_season}"
        fixture_scope = f"kick_off >= '{from_date}' AND kick_off < '{to_date}'"
        log.info(
            "=== Incremental silver load — %s.silver  league=%d  season=%d  from=%s ===",
            db, lid, cur_season, from_date,
        )

        for table in FULL_REPLACE_TABLES:
            _run_sql(conn, db, table)
        for table in SEASON_TABLES:
            _run_sql(conn, db, table, delete_filter=season_scope, insert_filter=season_scope)
        for table in FIXTURE_TABLES:
            _run_sql(conn, db, table, delete_filter=fixture_scope, insert_filter=fixture_scope)

    conn.close()
    log.info("Silver transformation complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Transform bronze data into silver layer")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Days to look back for incremental fixture window (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Full replace — rebuild all silver tables from current bronze")
    parser.add_argument("--league", type=int, default=None,
                        help="League ID (default: first league in bronze)")
    parser.add_argument("--season", type=int, default=None,
                        help="Season year for seasonal load (e.g. 2025)")
    parser.add_argument("--db", dest="target_db", default=None,
                        help="Target MotherDuck database (default: $TARGET_DB or 'superligaen_dev')")
    args = parser.parse_args()
    run(
        lookback_days=args.lookback,
        full_load=args.full_load,
        league_id=args.league,
        season=args.season,
        target_db=args.target_db,
    )
