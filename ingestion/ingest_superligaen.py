"""
Bronze layer ingestion for Superligaen (Danish football).

Fetches raw JSON from api-football.com and lands it as-is into the bronze
schema in MotherDuck. No transformation — that is dbt's job.

Tables written (bronze schema):
  api_football__fixtures            one row per fixture, full API response JSON
  api_football__fixture_events      one row per fixture, full events array JSON
  api_football__fixture_statistics  one row per fixture, full statistics array JSON
  api_football__fixture_lineups     one row per fixture, full lineups array JSON
  api_football__fixture_players     one row per fixture, full player stats array JSON

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


def api_get(endpoint: str, params: dict, sleep: float = 0.0) -> dict:
    if sleep:
        time.sleep(sleep)
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


def fetch_fixtures(from_date: str | None = None, to_date: str | None = None, sleep: float = 0.0) -> list[dict]:
    params = {"league": LEAGUE_ID, "season": CURRENT_SEASON}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params, sleep=sleep)
    log.info("Fetched %d fixtures", len(data["response"]))
    return data["response"]


def fetch_events(fixture_id: int, sleep: float = 0.0) -> list[dict]:
    return api_get("fixtures/events", {"fixture": fixture_id}, sleep=sleep)["response"]


def fetch_statistics(fixture_id: int, sleep: float = 0.0) -> list[dict]:
    return api_get("fixtures/statistics", {"fixture": fixture_id}, sleep=sleep)["response"]


def fetch_lineups(fixture_id: int, sleep: float = 0.0) -> list[dict]:
    return api_get("fixtures/lineups", {"fixture": fixture_id}, sleep=sleep)["response"]


def fetch_players(fixture_id: int, sleep: float = 0.0) -> list[dict]:
    return api_get("fixtures/players", {"fixture": fixture_id}, sleep=sleep)["response"]


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

    for table in (
        "api_football__fixtures",
        "api_football__fixture_events",
        "api_football__fixture_statistics",
        "api_football__fixture_lineups",
        "api_football__fixture_players",
    ):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                fixture_id   INTEGER PRIMARY KEY,
                raw_json     JSON    NOT NULL,
                ingested_at  TIMESTAMP DEFAULT current_timestamp
            )
        """)

    log.info("Bronze schema and tables verified")


# ---------------------------------------------------------------------------
# Load helpers — raw JSON, no transformation
# ---------------------------------------------------------------------------

def _upsert(conn: duckdb.DuckDBPyConnection, table: str, fixture_id: int, payload) -> None:
    conn.execute(
        f"INSERT OR REPLACE INTO bronze.{table} (fixture_id, raw_json) VALUES (?, ?)",
        [fixture_id, json.dumps(payload)],
    )


def load_fixtures(conn: duckdb.DuckDBPyConnection, fixtures: list[dict]) -> None:
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany(
        "INSERT OR REPLACE INTO bronze.api_football__fixtures (fixture_id, raw_json) VALUES (?, ?)",
        rows,
    )
    log.info("Loaded %d rows into bronze.api_football__fixtures", len(rows))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(lookback_days: int = 2, full_load: bool = False) -> None:
    conn = connect()
    ensure_schema_and_tables(conn)

    # Full loads respect the 10 req/min free tier limit — daily runs are fast
    sleep = 6.5 if full_load else 0.0

    if full_load:
        log.info("Full load — fetching entire season %d (rate-limited)", CURRENT_SEASON)
        fixtures = fetch_fixtures(sleep=sleep)
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
    log.info("%d finished fixtures — fetching all detail endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            _upsert(conn, "api_football__fixture_events",     fixture_id, fetch_events(fixture_id, sleep=sleep))
            _upsert(conn, "api_football__fixture_statistics", fixture_id, fetch_statistics(fixture_id, sleep=sleep))
            _upsert(conn, "api_football__fixture_lineups",    fixture_id, fetch_lineups(fixture_id, sleep=sleep))
            _upsert(conn, "api_football__fixture_players",    fixture_id, fetch_players(fixture_id, sleep=sleep))
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)

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
