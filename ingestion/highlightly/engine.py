"""
Highlightly bronze ingestion.

League-agnostic: every league listed in config.LEAGUES rides the same code
path, and adding one is a line of config. `--leagues` scopes a run to a subset.

Runs manually for now, against an explicit date window, while the historical
backfill is seeded by hand a window at a time. It is not in the nightly chain
yet — once coverage is complete it joins as a parallel bronze job on a rolling
last-N-days window, the same shape as the Sportmonks ingest.

Two passes per run:

  1. Season lists — cheap (4 calls per season) and refreshed whole, because the
     list also carries scheduled fixtures, states and scores that the site needs
     current. Only the seasons a run actually touches are re-listed.
  2. Match details — the expensive pass, one call per finished match. Scoped to
     the date window when given, otherwise newest-first.

The daily quota is shared across ALL leagues on the key, so the detail pass
interleaves them round-robin rather than draining one league before starting
the next. Without that, a league added later would starve behind an older
league's backlog indefinitely.

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
    LEAGUES,
    MATCHES_TABLE,
    STANDINGS_TABLE,
    current_season,
    seasons_covering,
    seasons_in_scope,
)

log = logging.getLogger(__name__)


def _label(league_id: int) -> str:
    return f"{LEAGUES.get(league_id, 'league')} ({league_id})"


def _match_date(record: dict):
    raw = record.get("date")
    return str(raw)[:10] if raw else None


def refresh_match_list(conn, league_id: int, season: int) -> int:
    """Re-list a season and replace its rows. 4 calls for a full season."""
    matches = api.get_match_list(league_id, season)
    if not matches:
        log.info("%s season %s: no matches returned, leaving existing rows alone",
                 _label(league_id), season)
        return 0
    db.delete_season(conn, MATCHES_TABLE, league_id, season)
    db.insert_batch(conn, MATCHES_TABLE, [
        (m.get("id"), json.dumps(m), season, _match_date(m), league_id)
        for m in matches
    ])
    log.info("%s season %s: %d matches written", _label(league_id), season, len(matches))
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
             _label(league_id), season, len(groups))
    return len(groups)


def _interleave(per_league: dict) -> list:
    """
    Round-robin the leagues' pending lists into one queue, so a shared quota is
    split fairly instead of being drained by whichever league is listed first.
    Each league keeps its own newest-first ordering within the queue.
    """
    queue, index = [], 0
    while any(len(v) > index for v in per_league.values()):
        for league_id, pending in per_league.items():
            if len(pending) > index:
                queue.append((league_id, *pending[index]))
        index += 1
    return queue


def fetch_details(conn, league_seasons: dict, from_date=None, to_date=None,
                  limit: int = None) -> int:
    """
    Spend the remaining budget on missing match details.

    Writes in batches so an exhausted budget mid-run still persists everything
    already fetched — the next run picks up exactly where this one stopped.
    """
    per_league = {}
    for league_id, seasons in league_seasons.items():
        pending = db.pending_detail_matches(conn, league_id, seasons,
                                            from_date=from_date, to_date=to_date)
        if pending:
            per_league[league_id] = pending
            log.info("%s: %d details outstanding", _label(league_id), len(pending))

    if not per_league:
        log.info("no match details outstanding for this scope")
        return 0

    queue = _interleave(per_league)
    budget = api.budget_left()
    take = min(len(queue), budget if limit is None else min(budget, limit))
    log.info("%d details outstanding in total, budget allows %d this run",
             len(queue), take)

    batch, written = [], 0
    try:
        for league_id, match_id, season, fixture_date in queue[:take]:
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
        from_date=None, to_date=None, details_limit: int = None) -> None:
    """
    mode      full        re-list every season in scope
              incremental re-list only the seasons the run touches
    leagues   league ids to run (default: every league in config.LEAGUES)
    seasons   explicit season scope; overrides what the window would imply
    from/to   date window for the detail pass (and, absent an explicit season
              scope, the seasons that get re-listed)
    """
    league_ids = leagues or list(LEAGUES)
    unknown = [lid for lid in league_ids if lid not in LEAGUES]
    if unknown:
        # Not fatal — an id absent from LEAGUES still fetches fine, it just has
        # no display name. Worth saying out loud in case it is a typo.
        log.warning("league ids not in config.LEAGUES: %s", unknown)

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

    log.info("mode=%s leagues=%s scope=%s listing=%s window=%s..%s",
             mode, league_ids, scope, to_list, from_date or "-", to_date or "-")

    try:
        for league_id in league_ids:
            for season in to_list:
                refresh_match_list(conn, league_id, season)
                refresh_standings(conn, league_id, season)
    except BudgetExhausted as exc:
        log.warning("budget spent during listing: %s", exc)
        return

    fetch_details(conn, {lid: scope for lid in league_ids},
                  from_date=from_date, to_date=to_date, limit=details_limit)

    # Remaining budget is only known once the API has answered, so the verified
    # figure lands here rather than at the top of the run.
    log.info("calls used this run: %d (remaining %d)", api.calls_made(), api.remaining())
    for league_id in league_ids:
        for season, listed, finished, detailed in db.coverage(conn, league_id):
            pct = (detailed / finished * 100) if finished else 0.0
            log.info("  %s season %s: %d listed, %d finished, %d detailed (%.0f%%)",
                     _label(league_id), season, listed, finished, detailed, pct)
