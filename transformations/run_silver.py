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

# Full replace on every run
FULL_REPLACE_TABLES = [
    "leagues",       # Group 1
    "coaches",       # Group 4
    "squads",
    "transfers",
    "sidelined",
    "trophies",
    "team_statistics",
    "venues",        # Group 5
]

# Season-scoped: DELETE WHERE league_id + season, then INSERT for that window
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

# Date-windowed: DELETE WHERE kick_off BETWEEN dates, then INSERT for that window
FIXTURE_TABLES = [
    "fixtures",
    "fixture_events",
    "fixture_statistics",
    "fixture_lineups",
    "fixture_players",
    "fixture_predictions",
    "fixture_odds",
]

ALL_TABLES = FULL_REPLACE_TABLES + SEASON_TABLES + FIXTURE_TABLES


def _connect(target_db: str | None) -> duckdb.DuckDBPyConnection:
    db = target_db or os.getenv("TARGET_DB", "superligaen_dev")
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        raise RuntimeError("MOTHERDUCK_TOKEN environment variable is not set")
    conn = duckdb.connect(f"md:{db}?motherduck_token={token}")
    conn.execute(f"CREATE SCHEMA IF NOT EXISTS {db}.silver")
    return conn, db


def _read_sql(table: str, db: str) -> str:
    path = SQL_DIR / f"{table}.sql"
    return path.read_text().format(db=db)


def _full_replace(conn: duckdb.DuckDBPyConnection, db: str, table: str) -> None:
    sql = _read_sql(table, db)
    log.info("  [full replace] %s.silver.%s", db, table)
    conn.execute(f"CREATE OR REPLACE TABLE {db}.silver.{table} AS ({sql})")


def _season_replace(
    conn: duckdb.DuckDBPyConnection,
    db: str,
    table: str,
    league_id: int,
    season: int,
) -> None:
    sql = _read_sql(table, db)
    log.info("  [season replace] %s.silver.%s  league=%d season=%d", db, table, league_id, season)
    conn.execute(
        f"CREATE TABLE IF NOT EXISTS {db}.silver.{table} AS "
        f"SELECT * FROM ({sql}) _t WHERE 1=0"
    )
    conn.execute(
        f"DELETE FROM {db}.silver.{table} "
        f"WHERE league_id = {league_id} AND season = {season}"
    )
    conn.execute(
        f"INSERT INTO {db}.silver.{table} "
        f"SELECT * FROM ({sql}) _t "
        f"WHERE league_id = {league_id} AND season = {season}"
    )


def _fixture_replace(
    conn: duckdb.DuckDBPyConnection,
    db: str,
    table: str,
    from_date: str,
    to_date: str,
) -> None:
    sql = _read_sql(table, db)
    log.info("  [fixture window] %s.silver.%s  %s → %s", db, table, from_date, to_date)
    conn.execute(
        f"CREATE TABLE IF NOT EXISTS {db}.silver.{table} AS "
        f"SELECT * FROM ({sql}) _t WHERE 1=0"
    )
    conn.execute(
        f"DELETE FROM {db}.silver.{table} "
        f"WHERE kick_off >= '{from_date}' AND kick_off < '{to_date}'"
    )
    conn.execute(
        f"INSERT INTO {db}.silver.{table} "
        f"SELECT * FROM ({sql}) _t "
        f"WHERE kick_off >= '{from_date}' AND kick_off < '{to_date}'"
    )


def _fixture_season_replace(
    conn: duckdb.DuckDBPyConnection,
    db: str,
    table: str,
    league_id: int,
    season: int,
) -> None:
    sql = _read_sql(table, db)
    log.info("  [fixture season replace] %s.silver.%s  league=%d season=%d", db, table, league_id, season)
    conn.execute(
        f"CREATE TABLE IF NOT EXISTS {db}.silver.{table} AS "
        f"SELECT * FROM ({sql}) _t WHERE 1=0"
    )
    conn.execute(
        f"DELETE FROM {db}.silver.{table} "
        f"WHERE league_id = {league_id} AND season = {season}"
    )
    conn.execute(
        f"INSERT INTO {db}.silver.{table} "
        f"SELECT * FROM ({sql}) _t "
        f"WHERE league_id = {league_id} AND season = {season}"
    )


def run(
    lookback_days: int = 2,
    full_load: bool = False,
    league_id: int | None = None,
    season: int | None = None,
    target_db: str | None = None,
) -> None:
    conn, db = _connect(target_db)

    if full_load and not league_id and not season:
        # ---------------------------------------------------------------
        # Full replace — wipe and rebuild every silver table from scratch
        # ---------------------------------------------------------------
        log.info("=== Full silver load — replacing all tables in %s.silver ===", db)
        for table in ALL_TABLES:
            _full_replace(conn, db, table)

    elif full_load and season:
        # ---------------------------------------------------------------
        # Seasonal load — full replace for reference tables,
        #                 season-scoped replace for Groups 2 & 3
        # ---------------------------------------------------------------
        lid = league_id or _get_default_league(conn, db)
        log.info("=== Seasonal silver load — %s.silver  league=%s  season=%d ===", db, lid, season)

        for table in FULL_REPLACE_TABLES:
            _full_replace(conn, db, table)

        for table in SEASON_TABLES:
            _season_replace(conn, db, table, lid, season)

        for table in FIXTURE_TABLES:
            _fixture_season_replace(conn, db, table, lid, season)

    else:
        # ---------------------------------------------------------------
        # Daily incremental — full replace for reference tables,
        #                     current-season replace for Group 2,
        #                     lookback window for Group 3
        # ---------------------------------------------------------------
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date   = date.today().isoformat()
        lid       = league_id or _get_default_league(conn, db)
        cur_season = _get_current_season(conn, db, lid)
        log.info(
            "=== Incremental silver load — %s.silver  league=%d  season=%d  from=%s ===",
            db, lid, cur_season, from_date,
        )

        for table in FULL_REPLACE_TABLES:
            _full_replace(conn, db, table)

        for table in SEASON_TABLES:
            _season_replace(conn, db, table, lid, cur_season)

        for table in FIXTURE_TABLES:
            _fixture_replace(conn, db, table, from_date, to_date)

    conn.close()
    log.info("Silver transformation complete")


def _get_default_league(conn: duckdb.DuckDBPyConnection, db: str) -> int:
    """Return the first league_id found in the bronze leagues table."""
    row = conn.execute(f"SELECT league_id FROM {db}.bronze.api_football__leagues LIMIT 1").fetchone()
    if not row:
        raise RuntimeError("No leagues found in bronze — run ingestion first")
    return row[0]


def _get_current_season(conn: duckdb.DuckDBPyConnection, db: str, league_id: int) -> int:
    """Return the current season for the given league from bronze."""
    row = conn.execute(
        f"""
        SELECT (unnested->>'$.year')::INTEGER AS year
        FROM {db}.bronze.api_football__leagues,
        UNNEST(raw_json::JSON[]) AS t1(elem),
        UNNEST((elem->'$.seasons')::JSON[]) AS t2(unnested)
        WHERE league_id = {league_id}
          AND (unnested->>'$.current')::BOOLEAN = true
        LIMIT 1
        """
    ).fetchone()
    if not row:
        raise RuntimeError(f"Could not determine current season for league {league_id}")
    return row[0]


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
