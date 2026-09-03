"""
Sportmonks API client.
All modules call get() or get_paginated() — nothing else touches requests directly.
"""

import logging
import math
import os
import time

import requests

from config import (  # noqa: F401
    API_BASE,
    API_CALL_DELAY,
    MAX_RATE_LIMIT_WAITS,
    MAX_RETRIES,
    PER_PAGE,
    RATE_LIMIT_FLOOR,
    RATE_WINDOW_SECONDS,
    REQUEST_TIMEOUT,
)

log = logging.getLogger(__name__)

_API_KEY: str | None = None


def _headers() -> dict:
    global _API_KEY
    if _API_KEY is None:
        _API_KEY = os.environ["SPORTMONKS_API_KEY"]
    return {"Authorization": _API_KEY}


def _seconds_to_window_end() -> float:
    """Seconds until the entity budgets reset at the top of the hour.

    The window is aligned to the wall clock, so the boundary is derivable
    without asking the API.  A small buffer keeps us clear of the edge.
    """
    now = time.time()
    return math.ceil(now / RATE_WINDOW_SECONDS) * RATE_WINDOW_SECONDS - now + 5


def _respect_budget(body: dict) -> None:
    """Pause for the hourly reset before the per-entity budget runs out.

    Every response carries rate_limit.remaining for the entity it served.
    Spending it locks that entity out for the rest of the hour, so we stop
    just short and wait for the reset instead.  /players needs ~236 requests
    against a budget of 180 and so always pauses once, mid-fetch.
    """
    limits = body.get("rate_limit")
    if not isinstance(limits, dict):
        return
    remaining = limits.get("remaining")
    if not isinstance(remaining, int) or remaining > RATE_LIMIT_FLOOR:
        return
    wait = _seconds_to_window_end()
    log.info(
        "Budget nearly spent for entity=%s (%d left) — waiting %.0fs for the hourly reset",
        limits.get("requested_entity", "unknown"), remaining, wait,
    )
    time.sleep(wait)


def get(path: str, params: dict = None, base: str = API_BASE) -> dict:
    url = f"{base}{path}"
    params = params or {}
    rate_limit_waits = 0
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, headers=_headers(), params=params, timeout=REQUEST_TIMEOUT)
        except requests.RequestException as exc:
            log.warning("Request error (attempt %d/%d): %s", attempt + 1, MAX_RETRIES, exc)
            time.sleep(min(5 * 2 ** attempt, 120))
            continue
        if r.status_code >= 500:
            wait = min(10 * 2 ** attempt, 300)
            log.warning("Server error %d — sleeping %ds (attempt %d/%d)", r.status_code, wait, attempt + 1, MAX_RETRIES)
            time.sleep(wait)
            continue
        if r.status_code == 429:
            # Budget already spent — the entity is locked out until the hour
            # rolls over, so short backoffs are wasted.  _respect_budget should
            # normally keep us out of here; a 429 means something else spent
            # the budget (an overlapping run, or a manual dispatch).
            rate_limit_waits += 1
            if rate_limit_waits > MAX_RATE_LIMIT_WAITS:
                raise RuntimeError(
                    f"Rate limited on {url} after {MAX_RATE_LIMIT_WAITS} hourly waits"
                )
            try:
                limits = r.json().get("rate_limit") or {}
                entity = limits.get("requested_entity", "unknown")
            except (ValueError, AttributeError):
                entity = "unknown"
            wait = _seconds_to_window_end()
            log.warning(
                "Rate limited (entity=%s) — waiting %.0fs for the hourly reset (%d/%d)",
                entity, wait, rate_limit_waits, MAX_RATE_LIMIT_WAITS,
            )
            time.sleep(wait)
            continue
        r.raise_for_status()
        body = r.json()
        time.sleep(API_CALL_DELAY)  # throttle: keep well below rate-limit ceiling
        _respect_budget(body)
        return body
    raise RuntimeError(f"Max retries ({MAX_RETRIES}) exceeded for {url}")


def get_paginated(path: str, params: dict = None, base: str = API_BASE) -> list:
    """Fetch all pages and return a flat list of records."""
    params = {**(params or {}), "per_page": PER_PAGE, "page": 1}
    results = []
    while True:
        try:
            data = get(path, params, base)
        except requests.HTTPError as exc:
            # Sportmonks returns 400 when paging past the last page, and
            # 404 for endpoints that have no data for a given ID.
            if exc.response is not None and exc.response.status_code in (400, 404):
                break
            raise
        batch = data.get("data", [])
        if isinstance(batch, dict):
            batch = [batch]
        results.extend(batch)
        if not data.get("pagination", {}).get("has_more"):
            break
        params["page"] += 1
    log.debug("%s → %d records", path, len(results))
    return results
