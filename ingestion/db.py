"""
MotherDuck connection, schema setup, and shared write helpers.

_insert()        — plain insert, used when the table is already empty (full load)
_delete_insert() — delete by key then insert, used for idempotent overwrites
"""

import json
import logging
import os

import duckdb
from dotenv import load_dotenv

from config import (
    COACH_ENDPOINTS,
    FIXTURE_DETAIL_ENDPOINTS,
    SEASON_AGGREGATE_ENDPOINTS,
    TEAM_ENDPOINTS,
)

load_dotenv()
log = logging.getLogger(__name__)

# Derived table lists used for schema setup and bulk operations
FIXTURE_DETAIL_TABLES  = [t for t, _ in FIXTURE_DETAIL_ENDPOINTS]
SEASON_AGGREGATE_TABLES = [t for t, _ in SEASON_AGGREGATE_ENDPOINTS]
TEAM_TABLES            = ["api_football__coaches"] + [t for t, _ in TEAM_ENDPOINTS + COACH_ENDPOINTS]

ALL_BRONZE_TABLES = (
    ["api_football__fixtures"]
    + FIXTURE_DETAIL_TABLES
    + SEASON_AGGREGATE_TABLES
    + ["api_football__leagues", "api_football__venues", "api_football__teams",
       "api_football__rounds", "api_football__players", "api_football__team_statistics"]
    + TEAM_TABLES
)


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def connect(target_db: str | None = None) -> duckdb.DuckDBPyConnection:
    token = os.environ["MOTHERDUCK_TOKEN"]
    if target_db is None:
        target_db = os.environ.get("TARGET_DB", "superligaen_dev")
    conn = duckdb.connect(f"md:{target_db}?motherduck_token={token}")
    log.info("Connected to MotherDuck: %s", target_db)
    return conn


# ---------------------------------------------------------------------------
# Schema setup
# ---------------------------------------------------------------------------

def _migrate_if_needed(conn: duckdb.DuckDBPyConnection) -> None:
    """Drop tables whose primary key changed from season-only to (season, league_id).
    They are recreated empty by ensure_schema_and_tables on the same run."""
    tables = SEASON_AGGREGATE_TABLES + [
        "api_football__teams",
        "api_football__rounds",
        "api_football__players",
        "api_football__team_statistics",
    ]
    for table in tables:
        has_league_id = conn.execute("""
            SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = 'bronze' AND table_name = ? AND column_name = 'league_id'
        """, [table]).fetchone()[0]
        if not has_league_id:
            conn.execute(f"DROP TABLE IF EXISTS bronze.{table}")
            log.info("Migrated bronze.%s — dropped for schema update (adding league_id)", table)


def ensure_schema_and_tables(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
    _migrate_if_needed(conn)

    # fixture_id-keyed
    for table in ["api_football__fixtures"] + FIXTURE_DETAIL_TABLES:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                fixture_id  INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # (season, league_id)-keyed
    for table in SEASON_AGGREGATE_TABLES + ["api_football__teams", "api_football__rounds"]:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                season      INTEGER,
                league_id   INTEGER,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp,
                PRIMARY KEY (season, league_id)
            )
        """)

    # league_id-keyed
    for table in ("api_football__leagues", "api_football__venues"):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                league_id   INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # team_id-keyed
    for table in TEAM_TABLES:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                team_id     INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # (season, league_id, page)-keyed
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__players (
            season      INTEGER,
            league_id   INTEGER,
            page        INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season, league_id, page)
        )
    """)

    # (season, league_id, team_id)-keyed
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__team_statistics (
            season      INTEGER,
            league_id   INTEGER,
            team_id     INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season, league_id, team_id)
        )
    """)

    log.info("Bronze schema and all %d tables verified", len(ALL_BRONZE_TABLES))


# ---------------------------------------------------------------------------
# Write helpers
# ---------------------------------------------------------------------------

def _insert(conn, table: str, key_cols: list, key_vals: list, payload) -> None:
    cols = ", ".join(key_cols) + ", raw_json"
    placeholders = ", ".join(["?"] * len(key_vals)) + ", ?"
    conn.execute(
        f"INSERT INTO bronze.{table} ({cols}) VALUES ({placeholders})",
        key_vals + [json.dumps(payload)],
    )


def _delete_insert(conn, table: str, key_cols: list, key_vals: list, payload) -> None:
    where = " AND ".join(f"{col} = ?" for col in key_cols)
    conn.execute(f"DELETE FROM bronze.{table} WHERE {where}", key_vals)
    _insert(conn, table, key_cols, key_vals, payload)


# ---------------------------------------------------------------------------
# Bulk operations
# ---------------------------------------------------------------------------

def truncate_all(conn) -> None:
    for table in ALL_BRONZE_TABLES:
        conn.execute(f"DELETE FROM bronze.{table}")
    log.info("Truncated all bronze tables")


def delete_season(conn, league_id: int, season: int) -> None:
    """Delete all data for a given league + season across every bronze table."""
    log.info("League %d season %d: deleting existing data", league_id, season)

    fixture_ids = [
        row[0] for row in conn.execute(
            "SELECT fixture_id FROM bronze.api_football__fixtures "
            "WHERE json_extract_string(raw_json, '$.league.id')::integer = ? "
            "AND json_extract_string(raw_json, '$.league.season')::integer = ?",
            [league_id, season],
        ).fetchall()
    ]
    if fixture_ids:
        placeholders = ", ".join("?" * len(fixture_ids))
        conn.execute(
            f"DELETE FROM bronze.api_football__fixtures WHERE fixture_id IN ({placeholders})",
            fixture_ids,
        )
        for table in FIXTURE_DETAIL_TABLES:
            conn.execute(
                f"DELETE FROM bronze.{table} WHERE fixture_id IN ({placeholders})",
                fixture_ids,
            )

    for table in SEASON_AGGREGATE_TABLES + ["api_football__teams", "api_football__rounds"]:
        conn.execute(
            f"DELETE FROM bronze.{table} WHERE season = ? AND league_id = ?",
            [season, league_id],
        )

    conn.execute(
        "DELETE FROM bronze.api_football__players WHERE season = ? AND league_id = ?",
        [season, league_id],
    )
    conn.execute(
        "DELETE FROM bronze.api_football__team_statistics WHERE season = ? AND league_id = ?",
        [season, league_id],
    )

    log.info("League %d season %d: existing data cleared", league_id, season)
