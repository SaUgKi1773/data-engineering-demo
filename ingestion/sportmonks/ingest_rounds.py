"""Fetch all rounds for each in-scope season."""

import logging

from api import get_paginated
from db import upsert

log = logging.getLogger(__name__)


def load_rounds(conn, seasons: list[dict]) -> None:
    for season in seasons:
        season_id = season["id"]
        records = get_paginated(f"/rounds/seasons/{season_id}")
        for round_ in records:
            upsert(conn, "sportmonks__rounds", round_["id"], round_, "sportmonks/rounds")
        log.info("Rounds season %s: %d upserted", season["name"], len(records))
