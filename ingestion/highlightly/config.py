import os
from datetime import date

API_BASE = "https://soccer.highlightly.net"

# Leagues ingested from Highlightly, keyed by the provider's league id. Denmark
# (271) and Scotland (501) stay on Sportmonks; nothing here touches them.
# Adding a league is a line here — the pipeline is otherwise league-agnostic.
LEAGUES = {
    223746: "Liga MX",
}

# Earliest season ingested, for every league. Chosen from the Liga MX probe
# (2026-07-24), where 2024 is the first season carrying Expected Goals:
#   2019       stub — 43 rows, all COVID-cancelled Clausura 2020 fixtures
#   2020-2023  15-16 statistics per team, NO Expected Goals
#   2024       23 statistics, xG present
#   2025+      40 statistics, xG present
# ~3 seasons also matches the depth ingested for Scotland.
FIRST_SEASON = 2024

# Nothing here assumes when a season starts. Which seasons a league has comes
# from /leagues/{id}; when each one ran comes from the fixture dates already in
# bronze. A split-year league (Liga MX: Jul->May) and a calendar-year league
# (Brazil, MLS) both work with no configuration.

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

LEAGUES_TABLE   = "highlightly__leagues"
MATCHES_TABLE   = "highlightly__matches"
DETAILS_TABLE   = "highlightly__match_details"
STANDINGS_TABLE = "highlightly__standings"
ALL_TABLES      = [LEAGUES_TABLE, MATCHES_TABLE, DETAILS_TABLE, STANDINGS_TABLE]

_PROJECT_ROOT   = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_DB_PATH = os.path.join(_PROJECT_ROOT, "superligaen_dev.duckdb")


def fallback_seasons(today: date = None) -> list[int]:
    """
    Last-resort season candidates: FIRST_SEASON up to the current calendar year.

    Only used when neither the API nor bronze can say which seasons a league
    has. A season is labelled by the year it opens, so it can never exceed the
    current year — that bound is arithmetic, not an assumption about football
    calendars. Listing a season that turns out not to exist is harmless: the
    API returns nothing and the run leaves existing rows alone.
    """
    today = today or date.today()
    return list(range(FIRST_SEASON, today.year + 1))
