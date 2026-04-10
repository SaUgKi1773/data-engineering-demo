"""
Bronze layer ingestion for Superligaen (Danish football).

Fetches raw JSON from api-football.com and lands it as-is into the bronze
schema in MotherDuck. No transformation — that is dbt's job.

Run modes:
  --lookback N   Fetch fixtures from the last N days (default: 2). Always
                 refreshes season aggregates (standings, top scorers, etc.)
  --full-load    Fetch the entire season plus all reference and per-team data.
                 Requires an upgraded api-football plan (>100 req/day).

Tables populated on EVERY run (season aggregates — change each matchday):
  api_football__standings
  api_football__topscorers
  api_football__topassists
  api_football__topyellowcards
  api_football__topredcards
  api_football__injuries

Tables populated on FULL LOAD only (reference / relatively static):
  api_football__leagues
  api_football__teams
  api_football__venues
  api_football__rounds
  api_football__players             (paginated — all player profiles)
  api_football__team_statistics     (keyed by season + team_id)
  api_football__coaches             (keyed by team_id)
  api_football__squads              (keyed by team_id)
  api_football__transfers           (keyed by team_id)
  api_football__sidelined           (keyed by team_id)
  api_football__trophies            (keyed by team_id)

Tables populated for every finished fixture (both runs):
  api_football__fixtures
  api_football__fixture_events
  api_football__fixture_statistics
  api_football__fixture_lineups
  api_football__fixture_players
  api_football__fixture_predictions
  api_football__fixture_odds        (free tier: 7-day history only)
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
LEAGUE_ID = 119
CURRENT_SEASON = 2024


# ---------------------------------------------------------------------------
# API helper
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


# ---------------------------------------------------------------------------
# Season-level fetchers (always run)
# ---------------------------------------------------------------------------

def fetch_standings(sleep: float = 0.0) -> list:
    return api_get("standings", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_topscorers(sleep: float = 0.0) -> list:
    return api_get("players/topscorers", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_topassists(sleep: float = 0.0) -> list:
    return api_get("players/topassists", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_topyellowcards(sleep: float = 0.0) -> list:
    return api_get("players/topyellowcards", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_topredcards(sleep: float = 0.0) -> list:
    return api_get("players/topredcards", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_injuries(sleep: float = 0.0) -> list:
    return api_get("injuries", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]


# ---------------------------------------------------------------------------
# Reference fetchers (full load only)
# ---------------------------------------------------------------------------

def fetch_leagues(sleep: float = 0.0) -> list:
    return api_get("leagues", {"id": LEAGUE_ID}, sleep)["response"]

def fetch_teams(sleep: float = 0.0) -> list:
    return api_get("teams", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_venues(sleep: float = 0.0) -> list:
    return api_get("venues", {"league": LEAGUE_ID}, sleep)["response"]

def fetch_rounds(sleep: float = 0.0) -> list:
    return api_get("fixtures/rounds", {"league": LEAGUE_ID, "season": CURRENT_SEASON}, sleep)["response"]

def fetch_league_players(sleep: float = 0.0) -> list[tuple[int, list]]:
    """Returns (page, response) tuples across all pages."""
    results = []
    page = 1
    while True:
        data = api_get(
            "players",
            {"league": LEAGUE_ID, "season": CURRENT_SEASON, "page": page},
            sleep,
        )
        results.append((page, data["response"]))
        if page >= data["paging"]["total"]:
            break
        page += 1
    return results


# ---------------------------------------------------------------------------
# Per-team fetchers (full load only)
# ---------------------------------------------------------------------------

def fetch_team_statistics(team_id: int, sleep: float = 0.0) -> dict:
    return api_get(
        "teams/statistics",
        {"league": LEAGUE_ID, "season": CURRENT_SEASON, "team": team_id},
        sleep,
    )["response"]

def fetch_coaches(team_id: int, sleep: float = 0.0) -> list:
    return api_get("coachs", {"team": team_id}, sleep)["response"]

def fetch_squads(team_id: int, sleep: float = 0.0) -> list:
    return api_get("players/squads", {"team": team_id}, sleep)["response"]

def fetch_transfers(team_id: int, sleep: float = 0.0) -> list:
    return api_get("transfers", {"team": team_id}, sleep)["response"]

def fetch_sidelined(team_id: int, sleep: float = 0.0) -> list:
    return api_get("sidelined", {"team": team_id}, sleep)["response"]

def fetch_trophies(team_id: int, sleep: float = 0.0) -> list:
    return api_get("trophies", {"team": team_id}, sleep)["response"]


# ---------------------------------------------------------------------------
# Per-fixture fetchers (both runs)
# ---------------------------------------------------------------------------

def fetch_fixtures(from_date: str | None = None, to_date: str | None = None, sleep: float = 0.0) -> list:
    params = {"league": LEAGUE_ID, "season": CURRENT_SEASON}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params, sleep)
    log.info("Fetched %d fixtures", len(data["response"]))
    return data["response"]

def fetch_events(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("fixtures/events", {"fixture": fixture_id}, sleep)["response"]

def fetch_statistics(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("fixtures/statistics", {"fixture": fixture_id}, sleep)["response"]

def fetch_lineups(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("fixtures/lineups", {"fixture": fixture_id}, sleep)["response"]

def fetch_fixture_players(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("fixtures/players", {"fixture": fixture_id}, sleep)["response"]

def fetch_predictions(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("predictions", {"fixture": fixture_id}, sleep)["response"]

def fetch_odds(fixture_id: int, sleep: float = 0.0) -> list:
    return api_get("odds", {"fixture": fixture_id}, sleep)["response"]


# ---------------------------------------------------------------------------
# MotherDuck
# ---------------------------------------------------------------------------

def connect() -> duckdb.DuckDBPyConnection:
    token = os.environ["MOTHERDUCK_TOKEN"]
    target_db = os.environ.get("TARGET_DB", "superligaen_dev")
    conn = duckdb.connect(f"md:{target_db}?motherduck_token={token}")
    log.info("Connected to MotherDuck: %s", target_db)
    return conn


def ensure_schema_and_tables(conn: duckdb.DuckDBPyConnection) -> None:
    conn.execute("CREATE SCHEMA IF NOT EXISTS bronze")

    # fixture_id PK
    for table in (
        "api_football__fixtures",
        "api_football__fixture_events",
        "api_football__fixture_statistics",
        "api_football__fixture_lineups",
        "api_football__fixture_players",
        "api_football__fixture_predictions",
        "api_football__fixture_odds",
    ):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                fixture_id  INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # season PK
    for table in (
        "api_football__standings",
        "api_football__topscorers",
        "api_football__topassists",
        "api_football__topyellowcards",
        "api_football__topredcards",
        "api_football__injuries",
        "api_football__teams",
        "api_football__rounds",
    ):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                season      INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # league_id PK
    for table in ("api_football__leagues", "api_football__venues"):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                league_id   INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # team_id PK
    for table in (
        "api_football__coaches",
        "api_football__squads",
        "api_football__transfers",
        "api_football__sidelined",
        "api_football__trophies",
    ):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                team_id     INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

    # composite PKs
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__team_statistics (
            season      INTEGER,
            team_id     INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season, team_id)
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__players (
            season      INTEGER,
            page        INTEGER,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp,
            PRIMARY KEY (season, page)
        )
    """)

    log.info("Bronze schema and all 21 tables verified")


# ---------------------------------------------------------------------------
# Load helpers
# ---------------------------------------------------------------------------

def _upsert(conn, table: str, key_cols: list, key_vals: list, payload) -> None:
    cols = ", ".join(key_cols) + ", raw_json"
    placeholders = ", ".join(["?"] * len(key_vals)) + ", ?"
    conn.execute(
        f"INSERT OR REPLACE INTO bronze.{table} ({cols}) VALUES ({placeholders})",
        key_vals + [json.dumps(payload)],
    )


def load_fixtures(conn, fixtures: list) -> None:
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

    sleep = 6.5 if full_load else 0.0

    # --- Season aggregates (every run) ---
    log.info("Fetching season aggregates")
    for table, fetcher in (
        ("api_football__standings",      lambda: fetch_standings(sleep)),
        ("api_football__topscorers",     lambda: fetch_topscorers(sleep)),
        ("api_football__topassists",     lambda: fetch_topassists(sleep)),
        ("api_football__topyellowcards", lambda: fetch_topyellowcards(sleep)),
        ("api_football__topredcards",    lambda: fetch_topredcards(sleep)),
        ("api_football__injuries",       lambda: fetch_injuries(sleep)),
    ):
        try:
            _upsert(conn, table, ["season"], [CURRENT_SEASON], fetcher())
            log.info("Loaded %s", table)
        except Exception as exc:
            log.warning("Failed %s: %s", table, exc)

    # --- Fixtures ---
    if full_load:
        log.info("Full load — fetching entire season %d", CURRENT_SEASON)
        fixtures = fetch_fixtures(sleep=sleep)
    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date = date.today().isoformat()
        log.info("Incremental load — %s to %s", from_date, to_date)
        fixtures = fetch_fixtures(from_date=from_date, to_date=to_date, sleep=sleep)

    load_fixtures(conn, fixtures)

    # --- Reference data (full load only) ---
    if full_load:
        log.info("Fetching reference data")

        for table, fetcher, key_col, key_val in (
            ("api_football__leagues", lambda: fetch_leagues(sleep), "league_id", LEAGUE_ID),
            ("api_football__teams",   lambda: fetch_teams(sleep),   "season",    CURRENT_SEASON),
            ("api_football__venues",  lambda: fetch_venues(sleep),  "league_id", LEAGUE_ID),
            ("api_football__rounds",  lambda: fetch_rounds(sleep),  "season",    CURRENT_SEASON),
        ):
            try:
                _upsert(conn, table, [key_col], [key_val], fetcher())
                log.info("Loaded %s", table)
            except Exception as exc:
                log.warning("Failed %s: %s", table, exc)

        # Players (paginated)
        try:
            for page, response in fetch_league_players(sleep):
                _upsert(conn, "api_football__players", ["season", "page"], [CURRENT_SEASON, page], response)
            log.info("Loaded api_football__players")
        except Exception as exc:
            log.warning("Failed api_football__players: %s", exc)

        # Per-team data — derive team list from what we just loaded
        teams = conn.execute(
            "SELECT DISTINCT json_extract_string(raw_json, '$.team.id')::integer AS team_id "
            "FROM bronze.api_football__teams WHERE season = ?",
            [CURRENT_SEASON],
        ).fetchall()
        team_ids = [row[0] for row in teams if row[0]]
        log.info("Fetching per-team data for %d teams", len(team_ids))

        for team_id in team_ids:
            for table, fetcher in (
                ("api_football__coaches",   lambda tid=team_id: fetch_coaches(tid, sleep)),
                ("api_football__squads",    lambda tid=team_id: fetch_squads(tid, sleep)),
                ("api_football__transfers", lambda tid=team_id: fetch_transfers(tid, sleep)),
                ("api_football__sidelined", lambda tid=team_id: fetch_sidelined(tid, sleep)),
                ("api_football__trophies",  lambda tid=team_id: fetch_trophies(tid, sleep)),
            ):
                try:
                    _upsert(conn, table, ["team_id"], [team_id], fetcher())
                except Exception as exc:
                    log.warning("Failed %s team %d: %s", table, team_id, exc)

            try:
                _upsert(
                    conn, "api_football__team_statistics",
                    ["season", "team_id"], [CURRENT_SEASON, team_id],
                    fetch_team_statistics(team_id, sleep),
                )
            except Exception as exc:
                log.warning("Failed api_football__team_statistics team %d: %s", team_id, exc)

            log.info("Loaded all data for team %d", team_id)

    # --- Per-fixture details (finished matches) ---
    finished = [
        f for f in fixtures
        if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")
    ]
    log.info("%d finished fixtures — fetching all fixture-level endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            _upsert(conn, "api_football__fixture_events",      ["fixture_id"], [fixture_id], fetch_events(fixture_id, sleep))
            _upsert(conn, "api_football__fixture_statistics",  ["fixture_id"], [fixture_id], fetch_statistics(fixture_id, sleep))
            _upsert(conn, "api_football__fixture_lineups",     ["fixture_id"], [fixture_id], fetch_lineups(fixture_id, sleep))
            _upsert(conn, "api_football__fixture_players",     ["fixture_id"], [fixture_id], fetch_fixture_players(fixture_id, sleep))
            _upsert(conn, "api_football__fixture_predictions", ["fixture_id"], [fixture_id], fetch_predictions(fixture_id, sleep))
            _upsert(conn, "api_football__fixture_odds",        ["fixture_id"], [fixture_id], fetch_odds(fixture_id, sleep))
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
                        help="Fetch entire season + all reference and per-team data")
    args = parser.parse_args()
    run(lookback_days=args.lookback, full_load=args.full_load)
