"""
Highlightly bronze ingestion.

The daily job and the historical backfill are the SAME run. Each night it
refreshes the current season's match list and standings, then spends whatever
budget is left fetching match details that are still missing — newest first.
After roughly a week the backlog is gone and the same run simply keeps the
current season up to date. Nothing tracks backfill progress except the data:
the work outstanding is the finished matches in `matches` with no row in
`match_details`.
"""

import json
import logging

import api
import db
from api import BudgetExhausted
from config import (
    DETAILS_TABLE,
    LEAGUE_ID,
    MATCHES_TABLE,
    STANDINGS_TABLE,
    current_season,
    seasons_in_scope,
)

log = logging.getLogger(__name__)


def _match_date(record: dict):
    raw = record.get("date")
    return str(raw)[:10] if raw else None


def refresh_match_list(conn, season: int) -> int:
    """Re-list a season and replace its rows. 4 calls for a full season."""
    matches = api.get_match_list(LEAGUE_ID, season)
    if not matches:
        log.info("season %s: no matches returned, leaving existing rows alone", season)
        return 0
    db.delete_season(conn, MATCHES_TABLE, LEAGUE_ID, season)
    db.insert_batch(conn, MATCHES_TABLE, [
        (m.get("id"), json.dumps(m), season, _match_date(m), LEAGUE_ID)
        for m in matches
    ])
    log.info("season %s: %d matches written", season, len(matches))
    return len(matches)


def refresh_standings(conn, season: int) -> int:
    groups = api.get_standings(LEAGUE_ID, season)
    if not groups:
        return 0
    db.delete_season(conn, STANDINGS_TABLE, LEAGUE_ID, season)
    db.insert_batch(conn, STANDINGS_TABLE, [
        (None, json.dumps(g), season, None, LEAGUE_ID) for g in groups
    ])
    log.info("season %s: %d standings groups written", season, len(groups))
    return len(groups)


def fetch_details(conn, seasons: list, limit: int = None) -> int:
    """
    Spend the remaining budget on missing match details, newest first.

    Writes in batches so an exhausted budget mid-run still persists everything
    already fetched — the next run picks up exactly where this one stopped.
    """
    pending = db.pending_detail_matches(conn, LEAGUE_ID, seasons)
    if not pending:
        log.info("no match details outstanding")
        return 0

    budget = api.budget_left()
    take = min(len(pending), budget if limit is None else min(budget, limit))
    log.info("%d details outstanding, budget allows %d this run", len(pending), take)

    batch, written = [], 0
    try:
        for match_id, season, fixture_date in pending[:take]:
            detail = api.get_match_detail(match_id)
            if detail is None:
                continue
            batch.append((match_id, json.dumps(detail), season, fixture_date, LEAGUE_ID))
            if len(batch) >= 50:
                written += _flush(conn, batch)
                batch = []
    except BudgetExhausted as exc:
        log.info("stopping detail fetch: %s", exc)
    finally:
        written += _flush(conn, batch)

    log.info("%d match details written", written)
    return written


def _flush(conn, batch: list) -> int:
    if not batch:
        return 0
    db.delete_details(conn, [r[0] for r in batch])
    db.insert_batch(conn, DETAILS_TABLE, batch)
    return len(batch)


def run(conn, mode: str = "incremental", seasons: list = None,
        details_limit: int = None) -> None:
    scope = seasons or seasons_in_scope()
    current = current_season()

    # Which season lists to refresh. Historical seasons are finished and do not
    # change, so re-listing them nightly would waste 4 calls each; incremental
    # lists only the current season and lets the detail backlog do the rest.
    to_list = scope if mode == "full" else [s for s in scope if s == current]
    if seasons:
        to_list = scope

    # Remaining budget is not reported here: it is only known once the API has
    # answered once. The closing summary has the verified figure.
    log.info("mode=%s scope=%s listing=%s", mode, scope, to_list)

    try:
        for season in to_list:
            refresh_match_list(conn, season)
            refresh_standings(conn, season)
    except BudgetExhausted as exc:
        log.warning("budget spent during listing: %s", exc)
        return

    fetch_details(conn, scope, limit=details_limit)

    log.info("calls used this run: %d (remaining %d)", api.calls_made(), api.remaining())
    for season, listed, finished, detailed in db.coverage(conn, LEAGUE_ID):
        pct = (detailed / finished * 100) if finished else 0.0
        log.info("  season %s: %d listed, %d finished, %d detailed (%.0f%%)",
                 season, listed, finished, detailed, pct)
