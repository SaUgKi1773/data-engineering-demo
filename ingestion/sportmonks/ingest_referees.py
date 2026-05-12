"""Fetch all referees who have officiated in Superliga, across all in-scope seasons."""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_referees(conn, seasons: list[dict]) -> None:
    seen = set()
    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/referees/seasons/{season_id}")
        new = 0
        for referee in records:
            if referee["id"] not in seen:
                upsert(conn, "sportmonks__referees", referee["id"], referee, "sportmonks/referees")
                seen.add(referee["id"])
                new += 1
        log.info("Referees season %s: %d fetched, %d new", season["name"], len(records), new)
    log.info("Referees total unique: %d", len(seen))
