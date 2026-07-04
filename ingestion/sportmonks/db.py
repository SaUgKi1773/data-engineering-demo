"""
DuckDB connection, schema management, and write helpers.

Table lists are derived from ENDPOINT_MANIFEST in config.py — the delete
strategy on each entry determines which category a table falls into:
  global     → DELETE FROM table (truncate)
  seasonal   → DELETE WHERE _season_id = ?
  date_window → DELETE WHERE _fixture_date BETWEEN ? AND ?
"""

import json
import logging
import os
from datetime import datetime, timezone

import duckdb
from dotenv import load_dotenv

from config import DEFAULT_DB_PATH, ENDPOINT_MANIFEST

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
log = logging.getLogger(__name__)

GLOBAL_TABLES   = [e["table"] for e in ENDPOINT_MANIFEST if e["delete"] == "global"]
SEASONAL_TABLES = [e["table"] for e in ENDPOINT_MANIFEST if e["delete"] == "seasonal"]
DATE_TABLES     = [e["table"] for e in ENDPOINT_MANIFEST if e["delete"] == "date_window"]
ALL_TABLES      = GLOBAL_TABLES + SEASONAL_TABLES + DATE_TABLES


def connect(db_path: str = None) -> duckdb.DuckDBPyConnection:
    path = db_path or os.environ.get("DUCKDB_PATH", DEFAULT_DB_PATH)
    conn = duckdb.connect(path)
    conn.execute("SELECT 1")  # validate connectivity (catches bad MotherDuck tokens early)
    log.info("Connected: %s", path)
    return conn


def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
    """Create bronze/meta schemas and all tables; migrate old schemas gracefully."""
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")
    conn.execute("CREATE SCHEMA IF NOT EXISTS meta")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS meta.ingestion_run_log (
            pipeline      VARCHAR,
            mode          VARCHAR,
            status        VARCHAR,
            started_at    TIMESTAMP,
            completed_at  TIMESTAMP,
            error_message VARCHAR
        )
    """)
    for table in ALL_TABLES:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                id            BIGINT,
                raw_json      JSON      NOT NULL,
                _season_id    INTEGER,
                _fixture_date DATE,
                _league_id    INTEGER,
                _ingested_at  TIMESTAMP DEFAULT current_timestamp
            )
        """)
        # Migrate: add columns that may be missing from an older schema
        existing = {row[0] for row in conn.execute(f"DESCRIBE bronze.{table}").fetchall()}
        for col, dtype in [("_season_id", "INTEGER"), ("_fixture_date", "DATE"),
                           ("_league_id", "INTEGER")]:
            if col not in existing:
                conn.execute(f"ALTER TABLE bronze.{table} ADD COLUMN {col} {dtype}")

    # Backfill _league_id on rows ingested before multi-league support.
    # League-scoped deletes (see delete_global / delete_by_date) rely on the
    # tag being complete.  Sources, in order of directness:
    #   date/seasons tables → league_id in their own payload
    #   league table        → its own id
    #   seasonal tables     → _season_id joined to the seasons table
    # Cross-league tables (players, transfers, rivals, reference data) stay
    # NULL by design — their rows do not belong to a single league.
    # Idempotent: the WHERE clauses make re-runs no-ops.
    for table in DATE_TABLES:
        conn.execute(f"""
            UPDATE bronze.{table}
            SET _league_id = CAST(raw_json->>'league_id' AS INTEGER)
            WHERE _league_id IS NULL
        """)
    conn.execute("""
        UPDATE bronze.sportmonks__seasons
        SET _league_id = CAST(raw_json->>'league_id' AS INTEGER)
        WHERE _league_id IS NULL
    """)
    conn.execute("""
        UPDATE bronze.sportmonks__league
        SET _league_id = id
        WHERE _league_id IS NULL
    """)
    for table in SEASONAL_TABLES:
        if table == "sportmonks__seasons":
            continue
        conn.execute(f"""
            UPDATE bronze.{table} t
            SET _league_id = s._league_id
            FROM bronze.sportmonks__seasons s
            WHERE t._league_id IS NULL
              AND t._season_id = s.id
              AND s._league_id IS NOT NULL
        """)
    log.info("Schema verified (%d tables)", len(ALL_TABLES))


# ── Delete helpers ────────────────────────────────────────────────────────────

def delete_global(conn: duckdb.DuckDBPyConnection, table: str,
                  league_ids: list = None) -> int:
    """
    Truncate the table — or, when league_ids is given, delete only that
    subset's rows (used by league-scoped runs on league-tagged tables so the
    other leagues' data survives).
    """
    where = ""
    params = []
    if league_ids:
        where = f" WHERE _league_id IN ({','.join('?' * len(league_ids))})"
        params = list(league_ids)
    n = conn.execute(f"SELECT COUNT(*) FROM bronze.{table}{where}", params).fetchone()[0]
    conn.execute(f"DELETE FROM bronze.{table}{where}", params)
    return n


def delete_by_season(conn: duckdb.DuckDBPyConnection, table: str, season_id: int) -> int:
    n = conn.execute(
        f"SELECT COUNT(*) FROM bronze.{table} WHERE _season_id = ?", [season_id]
    ).fetchone()[0]
    conn.execute(f"DELETE FROM bronze.{table} WHERE _season_id = ?", [season_id])
    return n


def delete_by_date(conn: duckdb.DuckDBPyConnection, table: str,
                   from_date: str, to_date: str,
                   league_ids: list = None) -> int:
    """
    Delete a date window — league-scoped when league_ids is given, so a
    scoped run never wipes another league's rows it won't re-fetch.
    """
    where = "WHERE _fixture_date BETWEEN ? AND ?"
    params = [from_date, to_date]
    if league_ids:
        where += f" AND _league_id IN ({','.join('?' * len(league_ids))})"
        params += list(league_ids)
    n = conn.execute(
        f"SELECT COUNT(*) FROM bronze.{table} {where}", params
    ).fetchone()[0]
    conn.execute(f"DELETE FROM bronze.{table} {where}", params)
    return n


# ── Insert helpers ────────────────────────────────────────────────────────────

_INSERT_CHUNK = 2000  # rows per INSERT statement; keeps parameter count well under DuckDB's 65535 limit (2000×6=12000)


def insert_batch(
    conn: duckdb.DuckDBPyConnection,
    table: str,
    rows: list,  # list of (id, raw_json_str, season_id, fixture_date, league_id)
) -> None:
    if not rows:
        return
    now = datetime.now(timezone.utc)
    rows_with_ts = [(*r, now) for r in rows]
    # Single multi-row INSERT per chunk instead of executemany (one round trip per row).
    # Reduces MotherDuck latency from O(n) network round trips to O(n/chunk).
    for i in range(0, len(rows_with_ts), _INSERT_CHUNK):
        chunk = rows_with_ts[i : i + _INSERT_CHUNK]
        placeholders = ",".join(["(?,?,?,?,?,?)"] * len(chunk))
        flat = [v for row in chunk for v in row]
        conn.execute(
            f"INSERT INTO bronze.{table} "
            f"(id, raw_json, _season_id, _fixture_date, _league_id, _ingested_at) "
            f"VALUES {placeholders}",
            flat,
        )
