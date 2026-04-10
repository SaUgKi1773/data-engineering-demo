"""
Ingestion script for Superligaen (Danish football) data.

Fetches from api-football.com and loads raw tables into MotherDuck (superligaen_dev).

Tables created/updated:
  raw_fixtures          — one row per fixture (result, teams, venue, status)
  raw_fixture_events    — one row per in-match event (goal, card, sub)
  raw_fixture_statistics — one row per team per fixture (corners, fouls, shots, etc.)

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
LEAGUE_ID = 119  # Superligaen
CURRENT_SEASON = 2024


# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

def _headers() -> dict:
    return {"x-apisports-key": os.environ["API_FOOTBALL_KEY"]}


def api_get(endpoint: str, params: dict) -> dict:
    """Single GET request with basic rate-limit handling."""
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
    """Fetch fixtures for Superligaen, optionally filtered by date range."""
    params = {"league": LEAGUE_ID, "season": CURRENT_SEASON}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params)
    log.info("Fetched %d fixtures", len(data["response"]))
    return data["response"]


def fetch_events(fixture_id: int) -> list[dict]:
    data = api_get("fixtures/events", {"fixture": fixture_id})
    return data["response"]


def fetch_statistics(fixture_id: int) -> list[dict]:
    data = api_get("fixtures/statistics", {"fixture": fixture_id})
    return data["response"]


# ---------------------------------------------------------------------------
# MotherDuck helpers
# ---------------------------------------------------------------------------

def connect() -> duckdb.DuckDBPyConnection:
    token = os.environ["MOTHERDUCK_TOKEN"]
    target_db = os.environ.get("TARGET_DB", "superligaen_dev")
    conn = duckdb.connect(f"md:{target_db}?motherduck_token={token}")
    log.info("Connected to MotherDuck database: %s", target_db)
    return conn


def ensure_tables(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS raw_fixtures (
            fixture_id        INTEGER PRIMARY KEY,
            referee           VARCHAR,
            match_date        TIMESTAMP,
            venue_name        VARCHAR,
            venue_city        VARCHAR,
            status_long       VARCHAR,
            status_short      VARCHAR,
            elapsed           INTEGER,
            league_id         INTEGER,
            league_season     INTEGER,
            league_round      VARCHAR,
            home_team_id      INTEGER,
            home_team_name    VARCHAR,
            away_team_id      INTEGER,
            away_team_name    VARCHAR,
            goals_home        INTEGER,
            goals_away        INTEGER,
            score_halftime_home  INTEGER,
            score_halftime_away  INTEGER,
            score_fulltime_home  INTEGER,
            score_fulltime_away  INTEGER,
            score_extratime_home INTEGER,
            score_extratime_away INTEGER,
            score_penalty_home   INTEGER,
            score_penalty_away   INTEGER,
            ingested_at       TIMESTAMP DEFAULT current_timestamp
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS raw_fixture_events (
            fixture_id    INTEGER,
            elapsed       INTEGER,
            elapsed_extra INTEGER,
            team_id       INTEGER,
            team_name     VARCHAR,
            player_id     INTEGER,
            player_name   VARCHAR,
            assist_id     INTEGER,
            assist_name   VARCHAR,
            event_type    VARCHAR,
            event_detail  VARCHAR,
            comments      VARCHAR,
            ingested_at   TIMESTAMP DEFAULT current_timestamp
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS raw_fixture_statistics (
            fixture_id    INTEGER,
            team_id       INTEGER,
            team_name     VARCHAR,
            stat_type     VARCHAR,
            stat_value    VARCHAR,
            ingested_at   TIMESTAMP DEFAULT current_timestamp
        )
    """)
    log.info("Tables verified/created")


# ---------------------------------------------------------------------------
# Upsert logic
# ---------------------------------------------------------------------------

def upsert_fixtures(conn: duckdb.DuckDBPyConnection, fixtures: list[dict]) -> None:
    rows = []
    for f in fixtures:
        fix = f["fixture"]
        league = f["league"]
        teams = f["teams"]
        goals = f["goals"]
        score = f["score"]
        rows.append((
            fix["id"],
            fix.get("referee"),
            fix.get("date"),
            fix["venue"].get("name"),
            fix["venue"].get("city"),
            fix["status"]["long"],
            fix["status"]["short"],
            fix["status"].get("elapsed"),
            league["id"],
            league["season"],
            league.get("round"),
            teams["home"]["id"],
            teams["home"]["name"],
            teams["away"]["id"],
            teams["away"]["name"],
            goals.get("home"),
            goals.get("away"),
            score["halftime"].get("home"),
            score["halftime"].get("away"),
            score["fulltime"].get("home"),
            score["fulltime"].get("away"),
            score["extratime"].get("home"),
            score["extratime"].get("away"),
            score["penalty"].get("home"),
            score["penalty"].get("away"),
        ))

    conn.executemany("""
        INSERT OR REPLACE INTO raw_fixtures (
            fixture_id, referee, match_date, venue_name, venue_city,
            status_long, status_short, elapsed,
            league_id, league_season, league_round,
            home_team_id, home_team_name, away_team_id, away_team_name,
            goals_home, goals_away,
            score_halftime_home, score_halftime_away,
            score_fulltime_home, score_fulltime_away,
            score_extratime_home, score_extratime_away,
            score_penalty_home, score_penalty_away
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """, rows)
    log.info("Upserted %d fixture rows", len(rows))


def replace_events(conn: duckdb.DuckDBPyConnection, fixture_id: int, events: list[dict]) -> None:
    conn.execute("DELETE FROM raw_fixture_events WHERE fixture_id = ?", [fixture_id])
    rows = [
        (
            fixture_id,
            e["time"].get("elapsed"),
            e["time"].get("extra"),
            e["team"]["id"],
            e["team"]["name"],
            e["player"]["id"] if e.get("player") else None,
            e["player"]["name"] if e.get("player") else None,
            e["assist"]["id"] if e.get("assist") else None,
            e["assist"]["name"] if e.get("assist") else None,
            e.get("type"),
            e.get("detail"),
            e.get("comments"),
        )
        for e in events
    ]
    conn.executemany("""
        INSERT INTO raw_fixture_events (
            fixture_id, elapsed, elapsed_extra,
            team_id, team_name,
            player_id, player_name,
            assist_id, assist_name,
            event_type, event_detail, comments
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
    """, rows)


def replace_statistics(conn: duckdb.DuckDBPyConnection, fixture_id: int, statistics: list[dict]) -> None:
    conn.execute("DELETE FROM raw_fixture_statistics WHERE fixture_id = ?", [fixture_id])
    rows = []
    for team_stats in statistics:
        team_id = team_stats["team"]["id"]
        team_name = team_stats["team"]["name"]
        for stat in team_stats["statistics"]:
            rows.append((
                fixture_id,
                team_id,
                team_name,
                stat["type"],
                str(stat["value"]) if stat["value"] is not None else None,
            ))
    conn.executemany("""
        INSERT INTO raw_fixture_statistics (
            fixture_id, team_id, team_name, stat_type, stat_value
        ) VALUES (?,?,?,?,?)
    """, rows)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(lookback_days: int = 2, full_load: bool = False) -> None:
    conn = connect()
    ensure_tables(conn)

    if full_load:
        log.info("Full load — fetching entire season %d", CURRENT_SEASON)
        fixtures = fetch_fixtures()
    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date = date.today().isoformat()
        log.info("Incremental load — fetching fixtures from %s to %s", from_date, to_date)
        fixtures = fetch_fixtures(from_date=from_date, to_date=to_date)

    upsert_fixtures(conn, fixtures)

    # Fetch detailed stats only for finished matches
    finished = [
        f for f in fixtures
        if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")
    ]
    log.info("%d finished fixtures — fetching events and statistics", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        try:
            events = fetch_events(fixture_id)
            replace_events(conn, fixture_id, events)

            stats = fetch_statistics(fixture_id)
            replace_statistics(conn, fixture_id, stats)

            log.info("Loaded fixture %d (%s vs %s)",
                     fixture_id,
                     f["teams"]["home"]["name"],
                     f["teams"]["away"]["name"])
        except Exception as exc:
            log.warning("Failed to load details for fixture %d: %s", fixture_id, exc)

        time.sleep(0.2)  # stay well within rate limits

    conn.close()
    log.info("Ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest Superligaen data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Number of days to look back for finished fixtures (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Load entire current season (ignores --lookback)")
    args = parser.parse_args()
    run(lookback_days=args.lookback, full_load=args.full_load)
