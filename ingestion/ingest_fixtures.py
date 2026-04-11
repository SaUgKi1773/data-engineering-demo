"""
Fixture ingestion.

Full load  — all fixtures for a season, all finished fixtures get
             detail endpoints loaded.
Incremental — fixtures within the lookback date window only.

Detail endpoints (events, statistics, lineups, players, predictions, odds)
are driven by FIXTURE_DETAIL_ENDPOINTS in config.py.
"""

import json
import logging

from api import api_get
from config import FIXTURE_DETAIL_ENDPOINTS
from db import FIXTURE_DETAIL_TABLES, _insert

log = logging.getLogger(__name__)


def fetch_fixtures(league_id: int, season: int,
                   from_date: str | None = None, to_date: str | None = None) -> list:
    params = {"league": league_id, "season": season}
    if from_date:
        params["from"] = from_date
    if to_date:
        params["to"] = to_date
    data = api_get("fixtures", params)
    log.info("League %d season %d: fetched %d fixtures", league_id, season, len(data["response"]))
    return data["response"]


def load_fixtures_bulk(conn, fixtures: list) -> None:
    rows = [(f["fixture"]["id"], json.dumps(f)) for f in fixtures]
    conn.executemany(
        "INSERT INTO bronze.api_football__fixtures (fixture_id, raw_json) VALUES (?, ?)",
        rows,
    )
    log.info("Loaded %d rows into bronze.api_football__fixtures", len(rows))


def load_fixture_details(conn, fixtures: list) -> None:
    """Fetch all detail endpoints for every finished fixture."""
    finished = [f for f in fixtures if f["fixture"]["status"]["short"] in ("FT", "AET", "PEN")]
    log.info("%d finished fixtures — fetching fixture-level endpoints", len(finished))

    for f in finished:
        fixture_id = f["fixture"]["id"]
        home = f["teams"]["home"]["name"]
        away = f["teams"]["away"]["name"]
        try:
            for table, endpoint in FIXTURE_DETAIL_ENDPOINTS:
                _insert(conn, table, ["fixture_id"], [fixture_id],
                        api_get(endpoint, {"fixture": fixture_id})["response"])
            log.info("Loaded fixture %d: %s vs %s", fixture_id, home, away)
        except Exception as exc:
            log.warning("Failed fixture %d (%s vs %s): %s", fixture_id, home, away, exc)


def delete_fixture_window(conn, league_id: int, from_date: str, to_date: str) -> None:
    """Delete fixtures and all their detail rows within the date window for a league."""
    fixture_ids = [
        row[0] for row in conn.execute(
            "SELECT fixture_id FROM bronze.api_football__fixtures "
            "WHERE json_extract_string(raw_json, '$.league.id')::integer = ? "
            "AND json_extract_string(raw_json, '$.fixture.date')::date BETWEEN ?::date AND ?::date",
            [league_id, from_date, to_date],
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
        log.info("Cleared %d fixtures from the date window for league %d", len(fixture_ids), league_id)
