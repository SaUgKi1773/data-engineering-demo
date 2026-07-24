"""
DuckDB schema and write helpers for the Highlightly bronze tables.

Same column shape as the Sportmonks bronze tables (id / raw_json / _season_id /
_fixture_date / _league_id / _ingested_at) so silver can treat both providers
identically.

Three tables:
  highlightly__matches        one row per match, from the season list endpoint.
                              Cheap and always complete — the schedule/results
                              backbone, refreshed per season.
  highlightly__match_details  one row per FINISHED match, from /matches/{id}.
                              Carries events + statistics + venue + referee.
                              Appended as the daily budget allows.
  highlightly__standings      one row per standings group, per season.

Splitting list from detail is what makes the backfill resumable without a state
table: the work left to do is exactly the finished matches present in `matches`
and absent from `match_details`.
"""

import logging
import os
from datetime import datetime, timezone

import duckdb
from dotenv import load_dotenv

from config import (
    ALL_TABLES,
    DEFAULT_DB_PATH,
    DETAILS_TABLE,
    FINISHED_STATES,
    MATCHES_TABLE,
)

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
log = logging.getLogger(__name__)


def connect(db_path: str = None) -> duckdb.DuckDBPyConnection:
    path = db_path or os.environ.get("DUCKDB_PATH", DEFAULT_DB_PATH)
    conn = duckdb.connect(path)
    conn.execute("SELECT 1")  # fail fast on a bad MotherDuck token
    log.info("Connected: %s", path)
    return conn


def ensure_schema(conn: duckdb.DuckDBPyConnection) -> None:
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
    log.info("Schema verified (%d tables)", len(ALL_TABLES))


def delete_season(conn: duckdb.DuckDBPyConnection, table: str,
                  league_id: int, season: int) -> int:
    n = conn.execute(
        f"SELECT COUNT(*) FROM bronze.{table} WHERE _league_id = ? AND _season_id = ?",
        [league_id, season],
    ).fetchone()[0]
    conn.execute(
        f"DELETE FROM bronze.{table} WHERE _league_id = ? AND _season_id = ?",
        [league_id, season],
    )
    return n


def delete_details(conn: duckdb.DuckDBPyConnection, match_ids: list) -> None:
    """Clear detail rows before reinserting, so a refetch replaces rather than duplicates."""
    if not match_ids:
        return
    for i in range(0, len(match_ids), 2000):
        chunk = match_ids[i:i + 2000]
        conn.execute(
            f"DELETE FROM bronze.{DETAILS_TABLE} "
            f"WHERE id IN ({','.join('?' * len(chunk))})",
            chunk,
        )


_INSERT_CHUNK = 2000


def insert_batch(conn: duckdb.DuckDBPyConnection, table: str, rows: list) -> None:
    """rows: list of (id, raw_json_str, season_id, fixture_date, league_id)"""
    if not rows:
        return
    now = datetime.now(timezone.utc)
    stamped = [(*r, now) for r in rows]
    for i in range(0, len(stamped), _INSERT_CHUNK):
        chunk = stamped[i:i + _INSERT_CHUNK]
        placeholders = ",".join(["(?,?,?,?,?,?)"] * len(chunk))
        conn.execute(
            f"INSERT INTO bronze.{table} "
            f"(id, raw_json, _season_id, _fixture_date, _league_id, _ingested_at) "
            f"VALUES {placeholders}",
            [v for row in chunk for v in row],
        )


def pending_detail_matches(conn: duckdb.DuckDBPyConnection, league_id: int,
                           seasons: list, from_date=None, to_date=None) -> list:
    """
    Finished matches that have no detail row yet, newest first.

    Newest first is deliberate: without a date window the run should catch up
    on the most recent football before chipping into history, so an interrupted
    backfill always leaves the most-viewed data current.

    from_date/to_date narrow the selection to a window — the manual backfill
    seeds history a window at a time, and the eventual nightly run will pass a
    rolling last-N-days window the same way the Sportmonks ingest does.
    """
    if not seasons:
        return []
    placeholders = ",".join("?" * len(seasons))
    state_ph = ",".join("?" * len(FINISHED_STATES))
    params = [league_id, *seasons, *FINISHED_STATES]

    window = ""
    if from_date is not None:
        window += " AND m._fixture_date >= ?"
        params.append(from_date)
    if to_date is not None:
        window += " AND m._fixture_date <= ?"
        params.append(to_date)

    rows = conn.execute(
        f"""
        SELECT m.id, m._season_id, m._fixture_date
        FROM bronze.{MATCHES_TABLE} m
        LEFT JOIN bronze.{DETAILS_TABLE} d ON d.id = m.id
        WHERE m._league_id = ?
          AND m._season_id IN ({placeholders})
          AND d.id IS NULL
          -- json_extract_string, not the chained ->/->> form: under prepared
          -- statement binding DuckDB resolves -> to the array-index overload
          -- and fails casting the object to a number.
          AND json_extract_string(m.raw_json, '$.state.description') IN ({state_ph})
          {window}
        ORDER BY m._fixture_date DESC NULLS LAST
        """,
        params,
    ).fetchall()
    return [(r[0], r[1], r[2]) for r in rows]


def coverage(conn: duckdb.DuckDBPyConnection, league_id: int) -> list:
    """Per-season listed vs finished vs detailed counts — the run's closing report."""
    state_ph = ",".join("?" * len(FINISHED_STATES))
    return conn.execute(
        f"""
        SELECT
            m._season_id                                                    AS season,
            COUNT(*)                                                        AS listed,
            COUNT(*) FILTER (
                WHERE json_extract_string(m.raw_json, '$.state.description') IN ({state_ph})
            )                                                               AS finished,
            COUNT(d.id)                                                     AS detailed
        FROM bronze.{MATCHES_TABLE} m
        LEFT JOIN bronze.{DETAILS_TABLE} d ON d.id = m.id
        WHERE m._league_id = ?
        GROUP BY 1
        ORDER BY 1
        """,
        [*FINISHED_STATES, league_id],
    ).fetchall()
