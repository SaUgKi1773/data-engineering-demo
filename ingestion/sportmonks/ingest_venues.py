"""Fetch all venues used in Superliga, across all in-scope seasons."""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_venues(conn, seasons: list[dict]) -> None:
    seen = set()
    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/venues/seasons/{season_id}")
        new = 0
        for venue in records:
            if venue["id"] not in seen:
                upsert(conn, "sportmonks__venues", venue["id"], venue, "sportmonks/venues")
                seen.add(venue["id"])
                new += 1
        log.info("Venues season %s: %d fetched, %d new", season["name"], len(records), new)
    log.info("Venues total unique: %d", len(seen))
