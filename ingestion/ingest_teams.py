"""
Group 4: Team endpoints.
Filter: team_id (derived from the teams loaded in Group 2)

Coaches are fetched first per team — their IDs are then passed to the
coach-level endpoints (sidelined, trophies). Results are aggregated
and stored per team_id. Team statistics also need league_id + season.

Load strategy (all modes): DELETE by team_id + INSERT per team.
"""

import logging

from api import api_get
from config import COACH_ENDPOINTS, TEAM_ENDPOINTS, TEAM_STATISTICS_ENDPOINT
from db import TEAM_STATS_TABLE, _delete_insert

log = logging.getLogger(__name__)


def _get_team_ids(conn, league_id: int, season: int) -> list[int]:
    rows = conn.execute(
        "SELECT DISTINCT json_extract_string(team_row, '$.team.id')::integer "
        "FROM (SELECT unnest(json_extract(raw_json, '$[*]')) AS team_row "
        "      FROM bronze.api_football__teams WHERE season = ? AND league_id = ?) t",
        [season, league_id],
    ).fetchall()
    return [r[0] for r in rows if r[0]]


def load_teams(conn, league_id: int, season: int) -> None:
    team_ids = _get_team_ids(conn, league_id, season)
    log.info("League %d season %d: loading per-team data for %d teams", league_id, season, len(team_ids))

    for team_id in team_ids:

        # Coaches fetched first — IDs needed for sidelined and trophies
        coaches_data = []
        coach_table, coach_endpoint = TEAM_ENDPOINTS[0]
        try:
            coaches_data = api_get(coach_endpoint, {"team": team_id})["response"]
            _delete_insert(conn, coach_table, ["team_id"], [team_id], coaches_data)
        except Exception as exc:
            log.warning("Failed %s team %d league %d season %d: %s",
                        coach_table, team_id, league_id, season, exc)

        # Remaining team endpoints
        for table, endpoint in TEAM_ENDPOINTS[1:]:
            try:
                data = api_get(endpoint, {"team": team_id})["response"]
                _delete_insert(conn, table, ["team_id"], [team_id], data)
            except Exception as exc:
                log.warning("Failed %s team %d league %d season %d: %s",
                            table, team_id, league_id, season, exc)

        # Coach endpoints — fetch per coach_id, aggregate and store per team_id
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

        # Team statistics — needs league_id + season + team_id
        _, stats_endpoint = TEAM_STATISTICS_ENDPOINT
        try:
            data = api_get(stats_endpoint,
                           {"league": league_id, "season": season, "team": team_id})["response"]
            _delete_insert(conn, TEAM_STATS_TABLE,
                           ["season", "league_id", "team_id"], [season, league_id, team_id], data)
        except Exception as exc:
            log.warning("Failed %s team %d league %d season %d: %s",
                        TEAM_STATS_TABLE, team_id, league_id, season, exc)
