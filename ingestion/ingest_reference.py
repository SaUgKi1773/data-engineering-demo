"""
Group 5: Reference endpoints.
Filter: varies per endpoint (defined in config.REFERENCE_ENDPOINTS)

Catch-all group for endpoints that don't fit the season or team loop.
Currently covers venues (fetched by country, stored per league_id).

Each entry in REFERENCE_ENDPOINTS is (table, endpoint, param_key) where
param_key is a field from the league dict in config.LEAGUES (e.g. "country").

Load strategy (all modes): DELETE by league_id + INSERT — always fully refreshed.
"""

import logging

from api import api_get
from config import REFERENCE_ENDPOINTS
from db import _delete_insert

log = logging.getLogger(__name__)


def load_reference(conn, league: dict) -> None:
    league_id = league["id"]
    log.info("League %d: loading reference data", league_id)
    for table, endpoint, param_key in REFERENCE_ENDPOINTS:
        try:
            data = api_get(endpoint, {param_key: league[param_key]})["response"]
            _delete_insert(conn, table, ["league_id"], [league_id], data)
        except Exception as exc:
            log.warning("Failed %s league %d: %s", table, league_id, exc)
