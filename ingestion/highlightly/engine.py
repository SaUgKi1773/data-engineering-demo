"""
Highlightly bronze ingestion — league-agnostic over config.LEAGUES.

Two passes per run:

  1. Season lists + standings — cheap (4-5 calls per season) and refreshed
     whole, because the list also carries scheduled fixtures, states and
     scores that the site needs current. Only the seasons a run actually
     touches are re-listed.
  2. Match details — the expensive pass, one call per finished match. Scoped
     to the date window when given, otherwise newest-first across the whole
     scope. Leagues are interleaved round-robin so they share the daily
     budget fairly: without it, a league added later would starve
     indefinitely behind an older league's backlog.

Nothing tracks progress except the data: the work outstanding is the finished
matches in `matches` with no row in `match_details`, so an interrupted run
resumes simply by being run again.
"""

import json
import logging
from itertools import zip_longest

import api
import db
from api import BudgetExhausted
from config import (
    DETAILS_TABLE,
    LEAGUES,
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


def refresh_match_list(conn, league_id: int, season: int) -> int:
    """Re-list a season and replace its rows. 4 calls for a full season."""
    matches = api.get_match_list(league_id, season)
    if not matches:
        log.info("%s season %s: no matches returned, leaving existing rows alone",
                 LEAGUES[league_id]["name"], season)
        return 0
    db.delete_season(conn, MATCHES_TABLE, league_id, season)
    db.insert_batch(conn, MATCHES_TABLE, [
        (m.get("id"), json.dumps(m), season, _match_date(m), league_id)
        for m in matches
    ])
    log.info("%s season %s: %d matches written",
             LEAGUES[league_id]["name"], season, len(matches))
    return len(matches)


def refresh_standings(conn, league_id: int, season: int) -> int:
    groups = api.get_standings(league_id, season)
    if not groups:
        return 0
    db.delete_season(conn, STANDINGS_TABLE, league_id, season)
    db.insert_batch(conn, STANDINGS_TABLE, [
        (None, json.dumps(g), season, None, league_id) for g in groups
    ])
    log.info("%s season %s: %d standings groups written",
             LEAGUES[league_id]["name"], season, len(groups))
    return len(groups)


def _interleaved_pending(conn, scopes: dict, from_date, to_date,
                         overwrite: bool) -> list:
    """
    Outstanding detail work across leagues as one queue: each league's pending
    matches newest-first, leagues alternating round-robin so the shared budget
    is split fairly instead of draining one league's backlog first.
    Returns [(league_id, match_id, season, fixture_date), ...].
    """
    per_league = [
        [(lid, *row) for row in db.pending_detail_matches(
            conn, lid, seasons, from_date=from_date, to_date=to_date,
            overwrite=overwrite)]
        for lid, seasons in scopes.items()
    ]
    return [item
            for bundle in zip_longest(*per_league)
            for item in bundle if item is not None]


def fetch_details(conn, scopes: dict, from_date=None, to_date=None,
                  limit: int = None, overwrite: bool = False) -> int:
    """
    Spend the remaining budget on missing match details — or, with overwrite,
    on every finished match in scope, replacing what is already stored.

    Writes in batches so an exhausted budget mid-run still persists everything
    already fetched — the next run picks up exactly where this one stopped.
    """
    pending = _interleaved_pending(conn, scopes, from_date, to_date, overwrite)
    if not pending:
        log.info("no match details outstanding for this scope")
        return 0

    budget = api.budget_left()
    take = min(len(pending), budget if limit is None else min(budget, limit))
    log.info("%d details outstanding, budget allows %d this run", len(pending), take)

    batch, written = [], 0
    try:
        for league_id, match_id, season, fixture_date in pending[:take]:
            detail = api.get_match_detail(match_id)
            if detail is None:
                continue
            batch.append((match_id, json.dumps(detail), season, fixture_date, league_id))
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


def run(conn, mode: str = "incremental", leagues: list = None, seasons: list = None,
        from_date=None, to_date=None, details_limit: int = None,
        overwrite: bool = False) -> None:
    """
    mode      full        re-list every season in scope
              incremental re-list only the seasons the run touches
    leagues   league ids to run (default: every configured league)
    seasons   explicit season scope; overrides what the window would imply
    from/to   date window for the detail pass (and, absent an explicit season
              scope, the seasons that get re-listed)
    overwrite refetch details that already exist (window/season-scoped only —
              run.py refuses it unscoped)
    """
    league_ids = leagues or list(LEAGUES)

    scopes = {}
    for lid in league_ids:
        if seasons:
            scopes[lid] = seasons
        elif from_date and to_date:
            scopes[lid] = seasons_covering(lid, from_date, to_date)
        else:
            scopes[lid] = seasons_in_scope(lid)

    if not any(scopes.values()):
        log.warning("no seasons in scope — nothing to do "
                    "(a window before first_season resolves to nothing)")
        return

    try:
        for lid in league_ids:
            # Historical seasons are finished and do not change, so re-listing
            # them on every run would waste 4 calls each. Incremental lists
            # only what the run touches; full re-lists the whole scope.
            if mode == "full" or seasons or (from_date and to_date):
                to_list = scopes[lid]
            else:
                to_list = [s for s in scopes[lid] if s == current_season()]
            log.info("%s: mode=%s scope=%s listing=%s window=%s..%s",
                     LEAGUES[lid]["name"], mode, scopes[lid], to_list,
                     from_date or "-", to_date or "-")
            for season in to_list:
                refresh_match_list(conn, lid, season)
                refresh_standings(conn, lid, season)
    except BudgetExhausted as exc:
        log.warning("budget spent during listing: %s", exc)
        return

    fetch_details(conn, scopes, from_date=from_date, to_date=to_date,
                  limit=details_limit, overwrite=overwrite)

    # Remaining budget is only known once the API has answered, so the verified
    # figure lands here rather than at the top of the run.
    log.info("calls used this run: %d (remaining %d)", api.calls_made(), api.remaining())
    for lid in league_ids:
        log.info("%s coverage:", LEAGUES[lid]["name"])
        for season, listed, finished, detailed in db.coverage(conn, lid):
            pct = (detailed / finished * 100) if finished else 0.0
            log.info("  season %s: %d listed, %d finished, %d detailed (%.0f%%)",
                     season, listed, finished, detailed, pct)
