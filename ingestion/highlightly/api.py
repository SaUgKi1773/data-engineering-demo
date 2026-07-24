"""
Highlightly API client.

Everything the pipeline fetches goes through get(). The client owns the daily
call budget: the API reports what is left on every response, so the budget is
read from the source of truth rather than counted locally and hoped for.
"""

import logging
import os
import time

import requests

from config import (
    API_BASE,
    API_CALL_DELAY,
    BUDGET_RESERVE,
    DAILY_CALL_BUDGET,
    MAX_RETRIES,
    PAGE_LIMIT,
    REQUEST_TIMEOUT,
)

log = logging.getLogger(__name__)

_API_KEY: str | None = None

# Best known remaining quota. Seeded optimistically and corrected by the first
# response; every later call trusts the header over the local estimate.
_remaining: int = DAILY_CALL_BUDGET
_calls_made: int = 0


class BudgetExhausted(RuntimeError):
    """Raised when the daily quota is spent. Not an error — the signal to stop."""


def _headers() -> dict:
    global _API_KEY
    if _API_KEY is None:
        _API_KEY = os.environ["HIGHLIGHTLY_API_KEY"]
    return {"x-rapidapi-key": _API_KEY, "User-Agent": "data-engineering-demo"}


def remaining() -> int:
    return _remaining


def calls_made() -> int:
    return _calls_made


def budget_left() -> int:
    """Callable calls remaining before the reserve floor."""
    return max(0, _remaining - BUDGET_RESERVE)


def _record_quota(response) -> None:
    global _remaining
    raw = response.headers.get("x-ratelimit-requests-remaining")
    if raw is None:
        _remaining -= 1
        return
    try:
        _remaining = int(raw)
    except (TypeError, ValueError):
        _remaining -= 1


def get(path: str, params: dict = None) -> dict | list:
    """
    One GET against the API, with retries. Raises BudgetExhausted rather than
    burning the last of the daily quota, so a caller can stop cleanly and
    resume tomorrow.
    """
    global _calls_made
    if budget_left() <= 0:
        raise BudgetExhausted(f"daily quota spent (remaining={_remaining})")

    url = f"{API_BASE}{path}"
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, headers=_headers(), params=params or {},
                             timeout=REQUEST_TIMEOUT)
        except requests.RequestException as exc:
            log.warning("Request error (attempt %d/%d): %s", attempt + 1, MAX_RETRIES, exc)
            time.sleep(min(5 * 2 ** attempt, 60))
            continue

        _calls_made += 1
        _record_quota(r)

        if r.status_code == 429:
            # The daily cap surfaces as a 429 there is no waiting out — treat it
            # as exhaustion rather than sleeping through the night.
            log.warning("429 from %s — treating as daily quota exhaustion", path)
            raise BudgetExhausted(f"429 on {path}")
        if r.status_code >= 500:
            wait = min(5 * 2 ** attempt, 60)
            log.warning("Server error %d — sleeping %ds (attempt %d/%d)",
                        r.status_code, wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue

        r.raise_for_status()
        time.sleep(API_CALL_DELAY)
        return r.json()

    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {url}")


def _rows(payload) -> list:
    """
    List endpoints answer {data, plan, pagination}; /matches/{id} answers a bare
    list. Normalise both to a list of records.
    """
    if isinstance(payload, dict):
        data = payload.get("data")
        if data is None:
            return [payload]
        return data if isinstance(data, list) else [data]
    return payload or []


def get_match_list(league_id: int, season: int) -> list:
    """
    Every match in a season, paginated. ~340 matches -> 4 calls.

    Stops early on BudgetExhausted so a partially fetched season is still
    written; the next run refetches the season from the start.
    """
    out, offset = [], 0
    while True:
        payload = get("/matches", {
            "leagueId": league_id,
            "season": season,
            "limit": PAGE_LIMIT,
            "offset": offset,
        })
        batch = _rows(payload)
        out.extend(batch)
        total = (payload.get("pagination") or {}).get("totalCount") if isinstance(payload, dict) else None
        offset += PAGE_LIMIT
        if not batch or (total is not None and offset >= total) or len(batch) < PAGE_LIMIT:
            break
    log.info("season %s: %d matches listed", season, len(out))
    return out


def get_match_detail(match_id: int) -> dict | None:
    """
    The bundled payload for one match — events, statistics, venue and referee in
    a single call. This is why detail is one call per match rather than four.
    """
    rows = _rows(get(f"/matches/{match_id}"))
    return rows[0] if rows else None


def get_standings(league_id: int, season: int) -> list:
    return _rows(get("/standings", {"leagueId": league_id, "season": season}))
