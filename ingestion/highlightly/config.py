import os
from datetime import date

API_BASE = "https://soccer.highlightly.net"

# Leagues on the Highlightly provider. Denmark (271) and Scotland (501) stay on
# Sportmonks; nothing here touches them. Adding a league is one entry here —
# every other module is league-agnostic and reads this mapping.
#
# first_season 2020 = all usable history (a one-time paid key backfills it in
# one go; the season count is not a free-tier budget concern). season=2019 is
# a stub where checked (partial/COVID-cancelled fixtures) and stays out.
#
# Know the depth cliff when modelling downstream: 2020-2023 carry only 14-16
# team measures with NO Expected Goals (and La Liga <= 2023 has NULL
# venue/referee). xG starts at season 2024 — full 40-measure set from 2024 on
# Süper Lig (La Liga 19, Liga MX 23 that season), 39-40 everywhere from 2025.
# Probes: 2026-07-24 Liga MX, 2026-07-25 La Liga + Süper Lig.
LEAGUES = {
    119924: {"name": "La Liga",   "country": "Spain",  "first_season": 2020},
    223746: {"name": "Liga MX",   "country": "Mexico", "first_season": 2020},
    173537: {"name": "Süper Lig", "country": "Turkey", "first_season": 2020},
}

# Highlightly seasons are SPLIT-YEAR, labelled by the opening year:
#   La Liga  season=2025  ->  2025-08 .. 2026-05
#   Liga MX  season=2025  ->  2025-07 .. 2026-05  (Apertura 2025 + Clausura 2026)
# Same July->May shape as the Danish and Scottish seasons, so this conforms to
# dim_date's existing per-league season handling rather than needing a new one.
# A date from June onwards belongs to the new season's label.
SEASON_BOUNDARY_MONTH = 6

# The API rejects limit > 100 ("limit must not be greater than 100"), so a
# ~340-380 match season list costs 4 calls.
PAGE_LIMIT = 100

# Free "Basic" plan: 100 requests/day shared across every league on the key.
# The true remaining count comes back on every response
# (x-ratelimit-requests-remaining) and is what the run actually steers by;
# this is the fallback when no header is present. A paid key reports its own
# larger limit through the same header, so a big backfill run needs no config
# change here.
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


def season_of(day: date) -> int:
    """
    The season label covering `day`. Both leagues open their season in July or
    August, so a date in the first half of a calendar year belongs to the
    previous label (March 2026 is season=2025 in both leagues).
    """
    return day.year if day.month >= SEASON_BOUNDARY_MONTH else day.year - 1


def current_season(today: date = None) -> int:
    return season_of(today or date.today())


def seasons_in_scope(league_id: int, today: date = None) -> list[int]:
    return list(range(LEAGUES[league_id]["first_season"], current_season(today) + 1))


def seasons_covering(league_id: int, from_date: date, to_date: date) -> list[int]:
    """
    Seasons a date window touches, clamped to the league's configured scope.
    A window spanning the June boundary covers two seasons.
    """
    lo, hi = season_of(from_date), season_of(to_date)
    first = LEAGUES[league_id]["first_season"]
    return [s for s in range(lo, hi + 1) if s >= first]
