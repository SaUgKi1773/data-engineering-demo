"""
League-level ingestion.

Covers three groups of endpoints, all scoped to a league:

  Season aggregates  — standings, topscorers, topassists, topyellowcards,
                       topredcards, injuries. Called with league_id + season.

  Reference data     — leagues, venues. Not season-scoped; loaded once per league.

  Season reference   — teams, rounds, players. Called with league_id + season,
                       but stored as reference (not aggregate) data.
"""

import logging

from api import api_get
from config import SEASON_AGGREGATE_ENDPOINTS
from db import _delete_insert, _insert

log = logging.getLogger(__name__)


def load_season_aggregates(conn, league_id: int, season: int, incremental: bool = False) -> None:
    log.info("League %d season %d: loading season aggregates", league_id, season)
    write = _delete_insert if incremental else _insert
    for table, endpoint in SEASON_AGGREGATE_ENDPOINTS:
        try:
            data = api_get(endpoint, {"league": league_id, "season": season})["response"]
            write(conn, table, ["season", "league_id"], [season, league_id], data)
        except Exception as exc:
            log.warning("Failed %s league %d season %d: %s", table, league_id, season, exc)


def load_reference_data(conn, league_id: int, country: str) -> None:
    """Leagues and venues — not season-scoped, refreshed once per run per league."""
    log.info("League %d: loading reference data", league_id)

    try:
        data = api_get("leagues", {"id": league_id})["response"]
        _delete_insert(conn, "api_football__leagues", ["league_id"], [league_id], data)
    except Exception as exc:
        log.warning("Failed api_football__leagues league %d: %s", league_id, exc)

    try:
        data = api_get("venues", {"country": country})["response"]
        _delete_insert(conn, "api_football__venues", ["league_id"], [league_id], data)
    except Exception as exc:
        log.warning("Failed api_football__venues league %d: %s", league_id, exc)


def load_season_reference(conn, league_id: int, season: int) -> None:
    """Teams, rounds, players — season-scoped reference data."""
    log.info("League %d season %d: loading season reference data", league_id, season)

    for table, endpoint in (
        ("api_football__teams",  "teams"),
        ("api_football__rounds", "fixtures/rounds"),
    ):
        try:
            data = api_get(endpoint, {"league": league_id, "season": season})["response"]
            _delete_insert(conn, table, ["season", "league_id"], [season, league_id], data)
        except Exception as exc:
            log.warning("Failed %s league %d season %d: %s", table, league_id, season, exc)

    # Players — paginated, delete all pages for this season+league first
    try:
        conn.execute(
            "DELETE FROM bronze.api_football__players WHERE season = ? AND league_id = ?",
            [season, league_id],
        )
        page = 1
        while True:
            data = api_get("players", {"league": league_id, "season": season, "page": page})
            _insert(conn, "api_football__players",
                    ["season", "league_id", "page"], [season, league_id, page],
                    data["response"])
            if page >= data["paging"]["total"]:
                break
            page += 1
    except Exception as exc:
        log.warning("Failed api_football__players league %d season %d: %s", league_id, season, exc)
