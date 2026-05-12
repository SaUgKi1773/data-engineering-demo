"""Fetch all teams that have appeared in Superliga, across all in-scope seasons."""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_teams(conn, seasons: list[dict]) -> None:
    seen = set()
    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/teams/seasons/{season_id}")
        new = 0
        for team in records:
            if team["id"] not in seen:
                upsert(conn, "sportmonks__teams", team["id"], team, "sportmonks/teams")
                seen.add(team["id"])
                new += 1
        log.info("Teams season %s: %d fetched, %d new", season["name"], len(records), new)
    log.info("Teams total unique: %d", len(seen))
