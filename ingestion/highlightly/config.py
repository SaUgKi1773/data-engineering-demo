import os
from datetime import date

API_BASE = "https://soccer.highlightly.net"

# Liga MX (Mexico) — the first league on a second provider. Denmark (271) and
# Scotland (501) stay on Sportmonks; nothing here touches them.
LEAGUE_ID = 223746

# Highlightly seasons are SPLIT-YEAR, labelled by the Apertura year:
#   season=2025  ->  2025-07-12 .. 2026-05-25  (Apertura 2025 + Clausura 2026)
# Same July->May shape as the Danish and Scottish seasons, so this conforms to
# dim_date's existing per-league season handling rather than needing a new one.
#
# Scope starts at 2024 (probe, 2026-07-24):
#   2019       stub — 43 rows, all COVID-cancelled Clausura 2020 fixtures
#   2020-2023  15-16 statistics per team, NO Expected Goals
#   2024       23 statistics, xG present
#   2025+      40 statistics, xG present
# 2024 is therefore the earliest season carrying xG, and ~3 seasons matches the
# depth we ingest for Scotland.
FIRST_SEASON = 2024

# The API rejects limit > 100 ("limit must not be greater than 100"), so a
# ~340-match season list costs 4 calls.
PAGE_LIMIT = 100

# Free "Basic" plan: 100 requests/day. The true remaining count comes back on
# every response (x-ratelimit-requests-remaining) and is what the run actually
# steers by; this is the fallback when no header is present.
DAILY_CALL_BUDGET = int(os.environ.get("HIGHLIGHTLY_DAILY_BUDGET", 100))

# Stop this far short of zero so a failed run never leaves the next one unable
# to make even its bootstrap calls.
BUDGET_RESERVE = 5

MAX_RETRIES     = 5
REQUEST_TIMEOUT = 60
API_CALL_DELAY  = 0.2  # polite spacing; the constraint is the daily cap, not rate

# Match states that carry events and statistics worth a detail call. Everything
# else (Not started, Cancelled, Postponed) has nothing extra to fetch, so
# spending budget on it would be waste.
FINISHED_STATES = (
    "Finished",
    "Finished after extra time",
    "Finished after penalties",
)

MATCHES_TABLE   = "highlightly__matches"
DETAILS_TABLE   = "highlightly__match_details"
STANDINGS_TABLE = "highlightly__standings"
ALL_TABLES      = [MATCHES_TABLE, DETAILS_TABLE, STANDINGS_TABLE]

_PROJECT_ROOT   = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DB_PATH = os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")


def current_season(today: date = None) -> int:
    """
    The season label covering `today`. Apertura kicks off in July, so a date in
    the first half of a calendar year belongs to the previous season's Clausura
    (March 2026 is Clausura 2026, which lives under season=2025).
    """
    today = today or date.today()
    return today.year if today.month >= 6 else today.year - 1


def seasons_in_scope(today: date = None) -> list[int]:
    return list(range(FIRST_SEASON, current_season(today) + 1))
