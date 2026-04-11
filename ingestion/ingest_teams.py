"""
Per-team and per-coach ingestion.

For each team in the given league + season:
  coaches          — fetched first by team_id (needed to get coach IDs below)
  squads, transfers — fetched by team_id
  sidelined, trophies — fetched per coach_id, results aggregated and stored per team_id
  team_statistics  — fetched by league_id + season + team_id

Adding a new team-level endpoint: add it to TEAM_ENDPOINTS in config.py.
Adding a new coach-level endpoint: add it to COACH_ENDPOINTS in config.py.
"""

import logging

from api import api_get
from config import COACH_ENDPOINTS, TEAM_ENDPOINTS
from db import _delete_insert

log = logging.getLogger(__name__)


def _get_team_ids(conn, league_id: int, season: int) -> list[int]:
    rows = conn.execute(
        "SELECT DISTINCT json_extract_string(team_row, '$.team.id')::integer "
        "FROM (SELECT unnest(json_extract(raw_json, '$[*]')) AS team_row "
        "      FROM bronze.api_football__teams WHERE season = ? AND league_id = ?) t",
        [season, league_id],
    ).fetchall()
    return [r[0] for r in rows if r[0]]


def load_team_data(conn, league_id: int, season: int) -> None:
    team_ids = _get_team_ids(conn, league_id, season)
    log.info("League %d season %d: loading per-team data for %d teams", league_id, season, len(team_ids))

    for team_id in team_ids:

        # Coaches must be fetched first — coach IDs are needed for sidelined and trophies
        coaches_data = []
        try:
            coaches_data = api_get("coachs", {"team": team_id})["response"]
            _delete_insert(conn, "api_football__coaches", ["team_id"], [team_id], coaches_data)
        except Exception as exc:
            log.warning("Failed api_football__coaches team %d league %d season %d: %s",
                        team_id, league_id, season, exc)

        # Simple team-keyed endpoints
        for table, endpoint in TEAM_ENDPOINTS:
            try:
                data = api_get(endpoint, {"team": team_id})["response"]
                _delete_insert(conn, table, ["team_id"], [team_id], data)
            except Exception as exc:
                log.warning("Failed %s team %d league %d season %d: %s",
                            table, team_id, league_id, season, exc)

        # Coach-keyed endpoints — fetch per coach, aggregate per team
        coach_ids = [c["id"] for c in coaches_data if isinstance(c, dict) and c.get("id")]
        for table, endpoint in COACH_ENDPOINTS:
            combined = []
            for coach_id in coach_ids:
                try:
                    combined.extend(api_get(endpoint, {"coach": coach_id})["response"])
                except Exception as exc:
                    log.warning("Failed %s coach %d team %d league %d season %d: %s",
                                table, coach_id, team_id, league_id, season, exc)
            try:
                _delete_insert(conn, table, ["team_id"], [team_id], combined)
            except Exception as exc:
                log.warning("Failed %s team %d league %d season %d: %s",
                            table, team_id, league_id, season, exc)

        # Team statistics — needs league + season + team
        try:
            data = api_get("teams/statistics",
                           {"league": league_id, "season": season, "team": team_id})["response"]
            _delete_insert(conn, "api_football__team_statistics",
                           ["season", "league_id", "team_id"], [season, league_id, team_id], data)
        except Exception as exc:
            log.warning("Failed team_statistics team %d league %d season %d: %s",
                        team_id, league_id, season, exc)
