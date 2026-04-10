"""
Bronze layer ingestion for Superligaen (Danish football).

Fetches raw JSON from api-football.com and lands it as-is into the bronze
schema in MotherDuck. No transformation — that is dbt's job.

Run modes:
  --lookback N   Incremental daily run. Fetches fixtures from the last N days
                 (default: 2) plus a full refresh of current-season aggregates
                 (standings, top scorers, injuries, etc.).
  --full-load    Historical load. Fetches all data for every season from
                 FIRST_SEASON to CURRENT_SEASON. Requires an upgraded
                 api-football plan (far exceeds 100 req/day).

Daily incremental — what gets loaded:
  FULL REFRESH (current season only, always up to date):
    standings, topscorers, topassists, topyellowcards, topredcards, injuries

  INCREMENTAL (fixtures in the lookback window):
    fixtures, fixture_events, fixture_statistics, fixture_lineups,
    fixture_players, fixture_predictions, fixture_odds

Full load — what gets loaded (for each season from FIRST_SEASON onwards):
  All of the above, plus reference and per-team data:
    leagues, teams, venues, rounds, players (paginated),
    team_statistics, coaches, squads, transfers, sidelined, trophies
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

API_BASE     = "https://v3.football.api-sports.io"
LEAGUE_ID    = 119
CURRENT_SEASON = 2025
FIRST_SEASON   = 2020  # earliest season to load on --full-load


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
# Season-level fetchers
# ---------------------------------------------------------------------------

def fetch_standings(season: int, sleep: float = 0.0) -> list:
    return api_get("standings", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_topscorers(season: int, sleep: float = 0.0) -> list:
    return api_get("players/topscorers", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_topassists(season: int, sleep: float = 0.0) -> list:
    return api_get("players/topassists", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_topyellowcards(season: int, sleep: float = 0.0) -> list:
    return api_get("players/topyellowcards", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_topredcards(season: int, sleep: float = 0.0) -> list:
    return api_get("players/topredcards", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_injuries(season: int, sleep: float = 0.0) -> list:
    return api_get("injuries", {"league": LEAGUE_ID, "season": season}, sleep)["response"]


# ---------------------------------------------------------------------------
# Reference fetchers
# ---------------------------------------------------------------------------

def fetch_leagues(sleep: float = 0.0) -> list:
    return api_get("leagues", {"id": LEAGUE_ID}, sleep)["response"]

def fetch_teams(season: int, sleep: float = 0.0) -> list:
    return api_get("teams", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_venues(sleep: float = 0.0) -> list:
    return api_get("venues", {"league": LEAGUE_ID}, sleep)["response"]

def fetch_rounds(season: int, sleep: float = 0.0) -> list:
    return api_get("fixtures/rounds", {"league": LEAGUE_ID, "season": season}, sleep)["response"]

def fetch_league_players(season: int, sleep: float = 0.0) -> list[tuple[int, list]]:
    """Returns (page, response) tuples across all pages."""
    results = []
    page = 1
    while True:
        data = api_get("players", {"league": LEAGUE_ID, "season": season, "page": page}, sleep)
        results.append((page, data["response"]))
        if page >= data["paging"]["total"]:
            break
        page += 1
    return results


# ---------------------------------------------------------------------------
# Per-team fetchers
# ---------------------------------------------------------------------------

def fetch_team_statistics(team_id: int, season: int, sleep: float = 0.0) -> dict:
    return api_get(
        "teams/statistics",
        {"league": LEAGUE_ID, "season": season, "team": team_id},
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
# Per-fixture fetchers
# ---------------------------------------------------------------------------

def fetch_fixtures(season: int, from_date: str | None = None, to_date: str | None = None, sleep: float = 0.0) -> list:
    params = {"league": LEAGUE_ID, "season": season}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params, sleep)
    log.info("Season %d: fetched %d fixtures", season, len(data["response"]))
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

    # season PK — teams vary by season
    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__teams (
            season      INTEGER PRIMARY KEY,
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

ALL_BRONZE_TABLES = [
    "api_football__fixtures",
    "api_football__fixture_events",
    "api_football__fixture_statistics",
    "api_football__fixture_lineups",
    "api_football__fixture_players",
    "api_football__fixture_predictions",
    "api_football__fixture_odds",
    "api_football__standings",
    "api_football__topscorers",
    "api_football__topassists",
    "api_football__topyellowcards",
    "api_football__topredcards",
    "api_football__injuries",
    "api_football__rounds",
    "api_football__leagues",
    "api_football__venues",
    "api_football__coaches",
    "api_football__squads",
    "api_football__transfers",
    "api_football__sidelined",
    "api_football__trophies",
    "api_football__teams",
    "api_football__team_statistics",
    "api_football__players",
]


def truncate_all(conn) -> None:
    for table in ALL_BRONZE_TABLES:
        conn.execute(f"DELETE FROM bronze.{table}")
    log.info("Truncated all bronze tables")


def _insert(conn, table: str, key_cols: list, key_vals: list, payload) -> None:
    cols         = ", ".join(key_cols) + ", raw_json"
    placeholders = ", ".join(["?"] * len(key_vals)) + ", ?"
    conn.execute(
        f"INSERT INTO bronze.{table} ({cols}) VALUES ({placeholders})",
        key_vals + [json.dumps(payload)],
    )


def _delete_insert(conn, table: str, key_cols: list, key_vals: list, payload) -> None:
    where = " AND ".join(f"{col} = ?" for col in key_cols)
    conn.execute(f"DELETE FROM bronze.{table} WHERE {where}", key_vals)
    _insert(conn, table, key_cols, key_vals, payload)


def load_fixtures_bulk(conn, fixtures: list, truncate: bool = False) -> None:
    if truncate:
        conn.execute("DELETE FROM bronze.api_football__fixtures")
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany(
        "INSERT INTO bronze.api_football__fixtures (fixture_id, raw_json) VALUES (?, ?)",
        rows,
    )
    log.info("Loaded %d rows into bronze.api_football__fixtures", len(rows))


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def load_season_aggregates(conn, season: int, sleep: float = 0.0, full_load: bool = False) -> None:
    """
    Season-level aggregates.
    - Full load: plain INSERT (tables already truncated).
    - Incremental: DELETE by season then INSERT.
    """
    log.info("Season %d: loading aggregates", season)
    write = _insert if full_load else _delete_insert
    for table, fetcher in (
        ("api_football__standings",      lambda: fetch_standings(season, sleep)),
        ("api_football__topscorers",     lambda: fetch_topscorers(season, sleep)),
        ("api_football__topassists",     lambda: fetch_topassists(season, sleep)),
        ("api_football__topyellowcards", lambda: fetch_topyellowcards(season, sleep)),
        ("api_football__topredcards",    lambda: fetch_topredcards(season, sleep)),
        ("api_football__injuries",       lambda: fetch_injuries(season, sleep)),
    ):
        try:
            write(conn, table, ["season"], [season], fetcher())
        except Exception as exc:
            log.warning("Failed %s season %d: %s", table, season, exc)


FIXTURE_DETAIL_TABLES = [
    "api_football__fixture_events",
    "api_football__fixture_statistics",
    "api_football__fixture_lineups",
    "api_football__fixture_players",
    "api_football__fixture_predictions",
    "api_football__fixture_odds",
]


def delete_fixture_details_by_ids(conn, fixture_ids: list[int]) -> None:
    """Delete all fixture-detail rows for a given list of fixture IDs in one pass."""
    if not fixture_ids:
        return
    placeholders = ", ".join("?" * len(fixture_ids))
    for table in FIXTURE_DETAIL_TABLES:
        conn.execute(
            f"DELETE FROM bronze.{table} WHERE fixture_id IN ({placeholders})",
            fixture_ids,
        )
    log.info("Deleted fixture detail rows for %d fixtures", len(fixture_ids))


def load_fixture_details(conn, fixtures: list, sleep: float = 0.0, full_load: bool = False) -> None:
    """
    Fixture-level endpoints for finished matches.
    - Full load: plain INSERT (tables already truncated).
    - Incremental: caller must have already deleted the relevant rows by date window.
    """
    finished = [f for f in fixtures if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")]
    log.info("%d finished fixtures — fetching fixture-level endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            _insert(conn, "api_football__fixture_events",      ["fixture_id"], [fixture_id], fetch_events(fixture_id, sleep))
            _insert(conn, "api_football__fixture_statistics",  ["fixture_id"], [fixture_id], fetch_statistics(fixture_id, sleep))
            _insert(conn, "api_football__fixture_lineups",     ["fixture_id"], [fixture_id], fetch_lineups(fixture_id, sleep))
            _insert(conn, "api_football__fixture_players",     ["fixture_id"], [fixture_id], fetch_fixture_players(fixture_id, sleep))
            _insert(conn, "api_football__fixture_predictions", ["fixture_id"], [fixture_id], fetch_predictions(fixture_id, sleep))
            _insert(conn, "api_football__fixture_odds",        ["fixture_id"], [fixture_id], fetch_odds(fixture_id, sleep))
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)


def load_reference_and_team_data(conn, season: int, sleep: float = 0.0) -> None:
    """Reference and per-team data. Full load only — plain INSERT (tables already truncated)."""
    log.info("Season %d: loading reference data", season)

    for table, fetcher, key_col, key_val in (
        ("api_football__leagues", lambda: fetch_leagues(sleep),        "league_id", LEAGUE_ID),
        ("api_football__teams",   lambda: fetch_teams(season, sleep),  "season",    season),
        ("api_football__venues",  lambda: fetch_venues(sleep),         "league_id", LEAGUE_ID),
        ("api_football__rounds",  lambda: fetch_rounds(season, sleep), "season",    season),
    ):
        try:
            _insert(conn, table, [key_col], [key_val], fetcher())
        except Exception as exc:
            log.warning("Failed %s season %d: %s", table, season, exc)

    try:
        for page, response in fetch_league_players(season, sleep):
            _insert(conn, "api_football__players", ["season", "page"], [season, page], response)
    except Exception as exc:
        log.warning("Failed api_football__players season %d: %s", season, exc)

    # Derive team IDs from what we just loaded
    rows = conn.execute(
        "SELECT DISTINCT json_extract_string(raw_json, '$.team.id')::integer "
        "FROM bronze.api_football__teams WHERE season = ?",
        [season],
    ).fetchall()
    team_ids = [r[0] for r in rows if r[0]]
    log.info("Season %d: loading per-team data for %d teams", season, len(team_ids))

    for team_id in team_ids:
        for table, fetcher in (
            ("api_football__coaches",   lambda tid=team_id: fetch_coaches(tid, sleep)),
            ("api_football__squads",    lambda tid=team_id: fetch_squads(tid, sleep)),
            ("api_football__transfers", lambda tid=team_id: fetch_transfers(tid, sleep)),
            ("api_football__sidelined", lambda tid=team_id: fetch_sidelined(tid, sleep)),
            ("api_football__trophies",  lambda tid=team_id: fetch_trophies(tid, sleep)),
        ):
            try:
                _insert(conn, table, ["team_id"], [team_id], fetcher())
            except Exception as exc:
                log.warning("Failed %s team %d season %d: %s", table, team_id, season, exc)

        try:
            _insert(
                conn, "api_football__team_statistics",
                ["season", "team_id"], [season, team_id],
                fetch_team_statistics(team_id, season, sleep),
            )
        except Exception as exc:
            log.warning("Failed team_statistics team %d season %d: %s", team_id, season, exc)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(lookback_days: int = 2, full_load: bool = False, season: int | None = None) -> None:
    conn = connect()
    ensure_schema_and_tables(conn)

    if full_load:
        sleep   = 6.5
        seasons = [season] if season else list(range(FIRST_SEASON, CURRENT_SEASON + 1))
        log.info("Full load — seasons: %s", seasons)

        # Truncate only when loading all seasons — single-season runs append to existing data
        if not season:
            truncate_all(conn)

        for s in seasons:
            log.info("=== Season %d ===", s)
            load_season_aggregates(conn, s, sleep, full_load=True)
            fixtures = fetch_fixtures(s, sleep=sleep)
            load_fixtures_bulk(conn, fixtures, truncate=False)  # already truncated above
            load_fixture_details(conn, fixtures, sleep, full_load=True)
            load_reference_and_team_data(conn, s, sleep)

    else:
        # Daily incremental
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date   = date.today().isoformat()
        log.info("Incremental load — window: %s to %s", from_date, to_date)

        # 1. Full refresh of current season aggregates (delete by season, then insert)
        load_season_aggregates(conn, CURRENT_SEASON, sleep=0.0, full_load=False)

        # 2. Delete the date window from fixtures and all fixture-detail tables upfront
        fixture_ids_in_window = [
            row[0] for row in conn.execute(
                "SELECT fixture_id FROM bronze.api_football__fixtures "
                "WHERE json_extract_string(raw_json, '$.fixture.date')::date "
                "BETWEEN ?::date AND ?::date",
                [from_date, to_date],
            ).fetchall()
        ]
        if fixture_ids_in_window:
            placeholders = ", ".join("?" * len(fixture_ids_in_window))
            conn.execute(
                f"DELETE FROM bronze.api_football__fixtures WHERE fixture_id IN ({placeholders})",
                fixture_ids_in_window,
            )
            delete_fixture_details_by_ids(conn, fixture_ids_in_window)
            log.info("Cleared %d fixtures from the date window", len(fixture_ids_in_window))

        # 3. Fetch and bulk insert
        fixtures = fetch_fixtures(CURRENT_SEASON, from_date=from_date, to_date=to_date)
        load_fixtures_bulk(conn, fixtures)
        load_fixture_details(conn, fixtures, sleep=0.0, full_load=True)  # tables already cleared

    conn.close()
    log.info("Bronze ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest Superligaen bronze data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Days to look back for finished fixtures (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Historical load — requires upgraded API plan (~2.3h per season)")
    parser.add_argument("--season", type=int, default=None,
                        help="Season year to load (e.g. 2023). Used with --full-load to load "
                             "one season at a time. Omit to load all seasons %d-%d." % (FIRST_SEASON, CURRENT_SEASON))
    args = parser.parse_args()
    run(lookback_days=args.lookback, full_load=args.full_load, season=args.season)
