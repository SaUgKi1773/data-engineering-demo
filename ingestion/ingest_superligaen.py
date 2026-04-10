"""
Bronze layer ingestion for Superligaen (Danish football).

Fetches raw JSON from api-football.com and lands it as-is into the bronze
schema in MotherDuck. No transformation — that is dbt's job.

Rate limiting is handled automatically via retry with exponential backoff.
No manual sleep needed — works on free and paid plans alike.

Run modes:
  --lookback N   Incremental daily run. Fetches fixtures from the last N days
                 (default: 2) plus a full refresh of current-season aggregates
                 (standings, top scorers, injuries, etc.).
  --full-load    Historical load. Fetches all data for every season from
                 FIRST_SEASON to CURRENT_SEASON. Requires an upgraded
                 api-football plan (far exceeds 100 req/day).
  --full-load --season YYYY
                 Load a single season. Use this to stay within GitHub Actions'
                 6-hour limit (~2.5h per season).

Daily incremental — what gets loaded:
  FULL REFRESH (current season only, delete-insert):
    standings, topscorers, topassists, topyellowcards, topredcards, injuries,
    leagues, venues, teams, rounds, players, coaches, squads, transfers,
    sidelined, trophies, team_statistics

  INCREMENTAL (fixtures in the lookback window, delete by fixture_id then insert):
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

API_BASE       = "https://v3.football.api-sports.io"
LEAGUE_ID      = 119
CURRENT_SEASON = 2025
FIRST_SEASON   = 2020  # earliest season to load on --full-load
MAX_RETRIES    = 10


# ---------------------------------------------------------------------------
# API helper — retries with exponential backoff on rate limit errors
# ---------------------------------------------------------------------------

def _headers() -> dict:
    return {"x-apisports-key": os.environ["API_FOOTBALL_KEY"]}


def api_get(endpoint: str, params: dict) -> dict:
    url = f"{API_BASE}/{endpoint}"
    for attempt in range(MAX_RETRIES):
        resp = requests.get(url, headers=_headers(), params=params, timeout=30)

        # HTTP 429 — rate limited
        if resp.status_code == 429:
            wait = 60 * (attempt + 1)
            log.warning("Rate limit (HTTP 429) — waiting %ds before retry %d/%d", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        resp.raise_for_status()
        data = resp.json()

        # API-level rate limit error
        if data.get("errors") and "rateLimit" in str(data["errors"]):
            wait = 60 * (attempt + 1)
            log.warning("Rate limit (API error) — waiting %ds before retry %d/%d", wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        if data.get("errors"):
            raise RuntimeError(f"API error on {endpoint}: {data['errors']}")

        remaining = resp.headers.get("x-ratelimit-requests-remaining")
        if remaining is not None:
            log.info("API requests remaining today: %s", remaining)

        return data

    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {endpoint} {params}")


# ---------------------------------------------------------------------------
# Season-level fetchers
# ---------------------------------------------------------------------------

def fetch_standings(season: int) -> list:
    return api_get("standings", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_topscorers(season: int) -> list:
    return api_get("players/topscorers", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_topassists(season: int) -> list:
    return api_get("players/topassists", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_topyellowcards(season: int) -> list:
    return api_get("players/topyellowcards", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_topredcards(season: int) -> list:
    return api_get("players/topredcards", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_injuries(season: int) -> list:
    return api_get("injuries", {"league": LEAGUE_ID, "season": season})["response"]


# ---------------------------------------------------------------------------
# Reference fetchers
# ---------------------------------------------------------------------------

def fetch_leagues() -> list:
    return api_get("leagues", {"id": LEAGUE_ID})["response"]

def fetch_teams(season: int) -> list:
    return api_get("teams", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_venues() -> list:
    return api_get("venues", {"league": LEAGUE_ID})["response"]

def fetch_rounds(season: int) -> list:
    return api_get("fixtures/rounds", {"league": LEAGUE_ID, "season": season})["response"]

def fetch_league_players(season: int) -> list[tuple[int, list]]:
    """Returns (page, response) tuples across all pages."""
    results = []
    page = 1
    while True:
        data = api_get("players", {"league": LEAGUE_ID, "season": season, "page": page})
        results.append((page, data["response"]))
        if page >= data["paging"]["total"]:
            break
        page += 1
    return results


# ---------------------------------------------------------------------------
# Per-team fetchers
# ---------------------------------------------------------------------------

def fetch_team_statistics(team_id: int, season: int) -> dict:
    return api_get("teams/statistics", {"league": LEAGUE_ID, "season": season, "team": team_id})["response"]

def fetch_coaches(team_id: int) -> list:
    return api_get("coachs", {"team": team_id})["response"]

def fetch_squads(team_id: int) -> list:
    return api_get("players/squads", {"team": team_id})["response"]

def fetch_transfers(team_id: int) -> list:
    return api_get("transfers", {"team": team_id})["response"]

def fetch_sidelined(team_id: int) -> list:
    return api_get("sidelined", {"team": team_id})["response"]

def fetch_trophies(team_id: int) -> list:
    return api_get("trophies", {"team": team_id})["response"]


# ---------------------------------------------------------------------------
# Per-fixture fetchers
# ---------------------------------------------------------------------------

def fetch_fixtures(season: int, from_date: str | None = None, to_date: str | None = None) -> list:
    params = {"league": LEAGUE_ID, "season": season}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params)
    log.info("Season %d: fetched %d fixtures", season, len(data["response"]))
    return data["response"]

def fetch_events(fixture_id: int) -> list:
    return api_get("fixtures/events", {"fixture": fixture_id})["response"]

def fetch_statistics(fixture_id: int) -> list:
    return api_get("fixtures/statistics", {"fixture": fixture_id})["response"]

def fetch_lineups(fixture_id: int) -> list:
    return api_get("fixtures/lineups", {"fixture": fixture_id})["response"]

def fetch_fixture_players(fixture_id: int) -> list:
    return api_get("fixtures/players", {"fixture": fixture_id})["response"]

def fetch_predictions(fixture_id: int) -> list:
    return api_get("predictions", {"fixture": fixture_id})["response"]

def fetch_odds(fixture_id: int) -> list:
    return api_get("odds", {"fixture": fixture_id})["response"]


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

    for table in ("api_football__leagues", "api_football__venues"):
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bronze.{table} (
                league_id   INTEGER PRIMARY KEY,
                raw_json    JSON NOT NULL,
                ingested_at TIMESTAMP DEFAULT current_timestamp
            )
        """)

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

    conn.execute("""
        CREATE TABLE IF NOT EXISTS bronze.api_football__teams (
            season      INTEGER PRIMARY KEY,
            raw_json    JSON NOT NULL,
            ingested_at TIMESTAMP DEFAULT current_timestamp
        )
    """)
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

FIXTURE_DETAIL_TABLES = [
    "api_football__fixture_events",
    "api_football__fixture_statistics",
    "api_football__fixture_lineups",
    "api_football__fixture_players",
    "api_football__fixture_predictions",
    "api_football__fixture_odds",
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


def load_fixtures_bulk(conn, fixtures: list) -> None:
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany(
        "INSERT INTO bronze.api_football__fixtures (fixture_id, raw_json) VALUES (?, ?)",
        rows,
    )
    log.info("Loaded %d rows into bronze.api_football__fixtures", len(rows))


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

def load_season_aggregates(conn, season: int, incremental: bool = False) -> None:
    """
    Season-level aggregates.
    - Full load: plain INSERT (tables already truncated).
    - Incremental: DELETE by season then INSERT.
    """
    log.info("Season %d: loading aggregates", season)
    write = _delete_insert if incremental else _insert
    for table, fetcher in (
        ("api_football__standings",      lambda: fetch_standings(season)),
        ("api_football__topscorers",     lambda: fetch_topscorers(season)),
        ("api_football__topassists",     lambda: fetch_topassists(season)),
        ("api_football__topyellowcards", lambda: fetch_topyellowcards(season)),
        ("api_football__topredcards",    lambda: fetch_topredcards(season)),
        ("api_football__injuries",       lambda: fetch_injuries(season)),
    ):
        try:
            write(conn, table, ["season"], [season], fetcher())
        except Exception as exc:
            log.warning("Failed %s season %d: %s", table, season, exc)


def load_fixture_details(conn, fixtures: list) -> None:
    """Fetch and insert all fixture-level endpoints for finished matches."""
    finished = [f for f in fixtures if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")]
    log.info("%d finished fixtures — fetching fixture-level endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            _insert(conn, "api_football__fixture_events",      ["fixture_id"], [fixture_id], fetch_events(fixture_id))
            _insert(conn, "api_football__fixture_statistics",  ["fixture_id"], [fixture_id], fetch_statistics(fixture_id))
            _insert(conn, "api_football__fixture_lineups",     ["fixture_id"], [fixture_id], fetch_lineups(fixture_id))
            _insert(conn, "api_football__fixture_players",     ["fixture_id"], [fixture_id], fetch_fixture_players(fixture_id))
            _insert(conn, "api_football__fixture_predictions", ["fixture_id"], [fixture_id], fetch_predictions(fixture_id))
            _insert(conn, "api_football__fixture_odds",        ["fixture_id"], [fixture_id], fetch_odds(fixture_id))
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)


def delete_season(conn, season: int) -> None:
    """Delete all data for a season across every bronze table."""
    log.info("Season %d: deleting existing data", season)

    # Fixture-keyed tables — delete by fixture_id belonging to this season
    fixture_ids = [
        row[0] for row in conn.execute(
            "SELECT fixture_id FROM bronze.api_football__fixtures "
            "WHERE json_extract_string(raw_json, '$.league.season')::integer = ?",
            [season],
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

    # Season-keyed tables
    for table in (
        "api_football__standings",
        "api_football__topscorers",
        "api_football__topassists",
        "api_football__topyellowcards",
        "api_football__topredcards",
        "api_football__injuries",
        "api_football__rounds",
        "api_football__teams",
        "api_football__players",
    ):
        conn.execute(f"DELETE FROM bronze.{table} WHERE season = ?", [season])

    # League/venue — keyed by league_id, shared across seasons; skip to avoid deleting other seasons' data
    # team_statistics — keyed by (season, team_id)
    conn.execute("DELETE FROM bronze.api_football__team_statistics WHERE season = ?", [season])

    # Team-keyed tables (coaches, squads, etc.) — keyed only by team_id, not season.
    # We can't safely delete by season here without risk of removing cross-season data.
    # These are reloaded per-team below via _delete_insert.

    log.info("Season %d: existing data cleared", season)


def load_reference_and_team_data(conn, season: int) -> None:
    """Reference and per-team data. Always delete-insert — safe for both full and single-season loads."""
    log.info("Season %d: loading reference data", season)

    for table, fetcher, key_col, key_val in (
        ("api_football__leagues", fetch_leagues,               "league_id", LEAGUE_ID),
        ("api_football__teams",   lambda: fetch_teams(season), "season",    season),
        ("api_football__venues",  fetch_venues,                "league_id", LEAGUE_ID),
        ("api_football__rounds",  lambda: fetch_rounds(season),"season",    season),
    ):
        try:
            _delete_insert(conn, table, [key_col], [key_val], fetcher())
        except Exception as exc:
            log.warning("Failed %s season %d: %s", table, season, exc)

    try:
        # Delete all pages for this season first, then re-insert
        conn.execute("DELETE FROM bronze.api_football__players WHERE season = ?", [season])
        for page, response in fetch_league_players(season):
            _insert(conn, "api_football__players", ["season", "page"], [season, page], response)
    except Exception as exc:
        log.warning("Failed api_football__players season %d: %s", season, exc)

    rows = conn.execute(
        "SELECT DISTINCT json_extract_string(raw_json, '$.team.id')::integer "
        "FROM bronze.api_football__teams WHERE season = ?",
        [season],
    ).fetchall()
    team_ids = [r[0] for r in rows if r[0]]
    log.info("Season %d: loading per-team data for %d teams", season, len(team_ids))

    for team_id in team_ids:
        for table, fetcher in (
            ("api_football__coaches",   lambda tid=team_id: fetch_coaches(tid)),
            ("api_football__squads",    lambda tid=team_id: fetch_squads(tid)),
            ("api_football__transfers", lambda tid=team_id: fetch_transfers(tid)),
            ("api_football__sidelined", lambda tid=team_id: fetch_sidelined(tid)),
            ("api_football__trophies",  lambda tid=team_id: fetch_trophies(tid)),
        ):
            try:
                _delete_insert(conn, table, ["team_id"], [team_id], fetcher())
            except Exception as exc:
                log.warning("Failed %s team %d season %d: %s", table, team_id, season, exc)

        try:
            _delete_insert(
                conn, "api_football__team_statistics",
                ["season", "team_id"], [season, team_id],
                fetch_team_statistics(team_id, season),
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
        seasons = [season] if season else list(range(FIRST_SEASON, CURRENT_SEASON + 1))
        log.info("Full load — seasons: %s", seasons)

        if not season:
            # All seasons: wipe everything and reload from scratch
            truncate_all(conn)
        # else: single season — delete_season() handles cleanup per season below

        for s in seasons:
            log.info("=== Season %d ===", s)
            if season:
                # Single-season run: delete what we expect to load first
                delete_season(conn, s)
            load_season_aggregates(conn, s)
            fixtures = fetch_fixtures(s)
            load_fixtures_bulk(conn, fixtures)
            load_fixture_details(conn, fixtures)
            load_reference_and_team_data(conn, s)

    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date   = date.today().isoformat()
        log.info("Incremental load — window: %s to %s", from_date, to_date)

        # 1. Full refresh of current season aggregates
        load_season_aggregates(conn, CURRENT_SEASON, incremental=True)

        # 2. Delete the date window upfront from fixtures and all detail tables
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
            for table in FIXTURE_DETAIL_TABLES:
                conn.execute(
                    f"DELETE FROM bronze.{table} WHERE fixture_id IN ({placeholders})",
                    fixture_ids_in_window,
                )
            log.info("Cleared %d fixtures from the date window", len(fixture_ids_in_window))

        # 3. Fetch and insert fixtures
        fixtures = fetch_fixtures(CURRENT_SEASON, from_date=from_date, to_date=to_date)
        load_fixtures_bulk(conn, fixtures)
        load_fixture_details(conn, fixtures)

        # 4. Full refresh of current season reference and team data
        load_reference_and_team_data(conn, CURRENT_SEASON)

    conn.close()
    log.info("Bronze ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest Superligaen bronze data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Days to look back for finished fixtures (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Historical load — requires upgraded API plan (~2.5h per season)")
    parser.add_argument("--season", type=int, default=None,
                        help="Season year for --full-load (e.g. 2023). "
                             "Omit to load all seasons %d-%d." % (FIRST_SEASON, CURRENT_SEASON))
    args = parser.parse_args()
    run(lookback_days=args.lookback, full_load=args.full_load, season=args.season)
