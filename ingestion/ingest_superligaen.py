"""
Bronze layer ingestion for Superligaen (Danish football).

Fetches raw JSON from api-football.com and lands it as-is into the bronze
schema in MotherDuck. No transformation — that is dbt's job.

Tables written (bronze schema):
  api_football__fixtures            one row per fixture, full API response JSON
  api_football__fixture_events      one row per fixture, full API response JSON
  api_football__fixture_statistics  one row per fixture, full API response JSON

Usage:
  python ingestion/ingest_superligaen.py              # last 2 days (daily run)
  python ingestion/ingest_superligaen.py --lookback 7 # last 7 days
  python ingestion/ingest_superligaen.py --full-load  # entire current season
"""

import argparse
import json
import logging
import os
import time
from datetime import date, timedelta

import duckdb
import requests
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

API_BASE = "https://v3.football.api-sports.io"
LEAGUE_ID = 119       # Superligaen
CURRENT_SEASON = 2024


# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

def _headers() -> dict:
    return {"x-apisports-key": os.environ["API_FOOTBALL_KEY"]}


def api_get(endpoint: str, params: dict) -> dict:
    url = f"{API_BASE}/{endpoint}"
    resp = requests.get(url, headers=_headers(), params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    if data.get("errors"):
        raise RuntimeError(f"API error on {endpoint}: {data['errors']}")
    remaining = resp.headers.get("x-ratelimit-requests-remaining")
    if remaining is not None:
        log.info("API requests remaining today: %s", remaining)
    return data


def fetch_fixtures(from_date: str | None = None, to_date: str | None = None) -> list[dict]:
    params = {"league": LEAGUE_ID, "season": CURRENT_SEASON}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params)
    log.info("Fetched %d fixtures", len(data["response"]))
    return data["response"]


def fetch_events(fixture_id: int) -> list[dict]:
    return api_get("fixtures/events", {"fixture": fixture_id})["response"]


def fetch_statistics(fixture_id: int) -> list[dict]:
    return api_get("fixtures/statistics", {"fixture": fixture_id})["response"]


# ---------------------------------------------------------------------------
# MotherDuck helpers
# ---------------------------------------------------------------------------

def connect() -> duckdb.DuckDBPyConnection:
    token = os.environ["MOTHERDUCK_TOKEN"]
    target_db = os.environ.get("TARGET_DB", "superligaen_dev")
    conn = duckdb.connect(f"md:{target_db}?motherduck_token={token}")
    log.info("Connected to MotherDuck: %s", target_db)
    return conn


def ensure_schema_and_tables(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")

    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__fixtures (
            fixture_id   INTEGER PRIMARY KEY,
            raw_json     JSON    NOT NULL,
            ingested_at  TIMESTAMP DEFAULT current_timestamp
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__fixture_events (
            fixture_id   INTEGER PRIMARY KEY,
            raw_json     JSON    NOT NULL,
            ingested_at  TIMESTAMP DEFAULT current_timestamp
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__fixture_statistics (
            fixture_id   INTEGER PRIMARY KEY,
            raw_json     JSON    NOT NULL,
            ingested_at  TIMESTAMP DEFAULT current_timestamp
        )
    """)

    log.info("Bronze schema and tables verified")


# ---------------------------------------------------------------------------
# Load helpers — raw JSON, no transformation
# ---------------------------------------------------------------------------

def load_fixtures(conn: duckdb.DuckDBPyConnection, fixtures: list[dict]) -> None:
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany("""
        INSERT OR REPLACE INTO bronze.api_football__fixtures (fixture_id, raw_json)
        VALUES (?, ?)
    """, rows)
    log.info("Loaded %d rows into bronze.api_football__fixtures", len(rows))


def load_events(conn: duckdb.DuckDBPyConnection, fixture_id: int, events: list[dict]) -> None:
    conn.execute("""
        INSERT OR REPLACE INTO bronze.api_football__fixture_events (fixture_id, raw_json)
        VALUES (?, ?)
    """, [fixture_id, json.dumps(events)])


def load_statistics(conn: duckdb.DuckDBPyConnection, fixture_id: int, statistics: list[dict]) -> None:
    conn.execute("""
        INSERT OR REPLACE INTO bronze.api_football__fixture_statistics (fixture_id, raw_json)
        VALUES (?, ?)
    """, [fixture_id, json.dumps(statistics)])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(lookback_days: int = 2, full_load: bool = False) -> None:
    conn = connect()
    ensure_schema_and_tables(conn)

    if full_load:
        log.info("Full load — fetching entire season %d", CURRENT_SEASON)
        fixtures = fetch_fixtures()
    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date = date.today().isoformat()
        log.info("Incremental load — %s to %s", from_date, to_date)
        fixtures = fetch_fixtures(from_date=from_date, to_date=to_date)

    load_fixtures(conn, fixtures)

    finished = [
        f for f in fixtures
        if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")
    ]
    log.info("%d finished fixtures — fetching events and statistics", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            load_events(conn, fixture_id, fetch_events(fixture_id))
            load_statistics(conn, fixture_id, fetch_statistics(fixture_id))
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)

        time.sleep(0.2)  # stay within rate limits

    conn.close()
    log.info("Bronze ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest Superligaen bronze data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Days to look back for finished fixtures (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Load entire current season (ignores --lookback)")
    args = parser.parse_args()
    run(lookback_days=args.lookback, full_load=args.full_load)
