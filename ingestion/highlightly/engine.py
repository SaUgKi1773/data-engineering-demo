"""
Highlightly bronze ingestion.

Runs manually for now, against an explicit date window, while the historical
backfill is seeded by hand a window at a time. It is not in the nightly chain
yet — once coverage is complete it joins as a parallel bronze job on a rolling
last-N-days window, the same shape as the Sportmonks ingest.

Two passes per run:

  1. Season lists — cheap (4 calls per season) and refreshed whole, because the
     list also carries scheduled fixtures, states and scores that the site needs
     current. Only the seasons a run actually touches are re-listed.
  2. Match details — the expensive pass, one call per finished match. Scoped to
     the date window when given, otherwise newest-first across the whole scope.

Nothing tracks progress except the data: the work outstanding is the finished
matches in `matches` with no row in `match_details`, so an interrupted run
resumes simply by being run again.
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
    seasons_covering,
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


def fetch_details(conn, seasons: list, from_date=None, to_date=None,
                  limit: int = None) -> int:
    """
    Spend the remaining budget on missing match details.

    Writes in batches so an exhausted budget mid-run still persists everything
    already fetched — the next run picks up exactly where this one stopped.
    """
    pending = db.pending_detail_matches(conn, LEAGUE_ID, seasons,
                                        from_date=from_date, to_date=to_date)
    if not pending:
        log.info("no match details outstanding for this scope")
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
        from_date=None, to_date=None, details_limit: int = None) -> None:
    """
    mode      full        re-list every season in scope
              incremental re-list only the seasons the run touches
    seasons   explicit season scope; overrides what the window would imply
    from/to   date window for the detail pass (and, absent an explicit season
              scope, the seasons that get re-listed)
    """
    if seasons:
        scope = seasons
    elif from_date and to_date:
        scope = seasons_covering(from_date, to_date)
    else:
        scope = seasons_in_scope()

    if not scope:
        log.warning("no seasons in scope — nothing to do "
                    "(a window before FIRST_SEASON resolves to nothing)")
        return

    # Historical seasons are finished and do not change, so re-listing them on
    # every run would waste 4 calls each. Incremental lists only what the run
    # touches; full re-lists the whole scope.
    if mode == "full" or seasons or (from_date and to_date):
        to_list = scope
    else:
        to_list = [s for s in scope if s == current_season()]

    log.info("mode=%s scope=%s listing=%s window=%s..%s",
             mode, scope, to_list, from_date or "-", to_date or "-")

    try:
        for season in to_list:
            refresh_match_list(conn, season)
            refresh_standings(conn, season)
    except BudgetExhausted as exc:
        log.warning("budget spent during listing: %s", exc)
        return

    fetch_details(conn, scope, from_date=from_date, to_date=to_date,
                  limit=details_limit)

    # Remaining budget is only known once the API has answered, so the verified
    # figure lands here rather than at the top of the run.
    log.info("calls used this run: %d (remaining %d)", api.calls_made(), api.remaining())
    for season, listed, finished, detailed in db.coverage(conn, LEAGUE_ID):
        pct = (detailed / finished * 100) if finished else 0.0
        log.info("  season %s: %d listed, %d finished, %d detailed (%.0f%%)",
                 season, listed, finished, detailed, pct)
