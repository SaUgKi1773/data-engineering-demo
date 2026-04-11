"""
Ingestion configuration — single source of truth for leagues and endpoint metadata.

To add a new league:    add an entry to LEAGUES.
To add a new endpoint:  add a tuple to the relevant endpoint list below.
No other files need to change.
"""

from datetime import date as _date

API_BASE    = "https://v3.football.api-sports.io"
MAX_RETRIES = 10
FIRST_SEASON = 2020

def _current_season() -> int:
    """Football seasons start in July. The season year is the year it began."""
    today = _date.today()
    return today.year if today.month >= 7 else today.year - 1

CURRENT_SEASON = _current_season()

# ---------------------------------------------------------------------------
# Leagues to ingest
# ---------------------------------------------------------------------------

LEAGUES = [
    {"id": 119, "country": "Denmark"},
]

# ---------------------------------------------------------------------------
# Endpoint metadata
# ---------------------------------------------------------------------------

# Called with league_id + season — one row per (season, league_id)
SEASON_AGGREGATE_ENDPOINTS = [
    ("api_football__standings",      "standings"),
    ("api_football__topscorers",     "players/topscorers"),
    ("api_football__topassists",     "players/topassists"),
    ("api_football__topyellowcards", "players/topyellowcards"),
    ("api_football__topredcards",    "players/topredcards"),
    ("api_football__injuries",       "injuries"),
]

# Called with team_id — one row per team_id
# Note: coaches is handled separately in ingest_teams.py (must be fetched first
# so its coach IDs can be passed to sidelined and trophies)
TEAM_ENDPOINTS = [
    ("api_football__squads",    "players/squads"),
    ("api_football__transfers", "transfers"),
]

# Called with coach_id — fetched per coach, aggregated and stored per team_id
COACH_ENDPOINTS = [
    ("api_football__sidelined", "sidelined"),
    ("api_football__trophies",  "trophies"),
]

# Called with fixture_id — one row per fixture_id
FIXTURE_DETAIL_ENDPOINTS = [
    ("api_football__fixture_events",      "fixtures/events"),
    ("api_football__fixture_statistics",  "fixtures/statistics"),
    ("api_football__fixture_lineups",     "fixtures/lineups"),
    ("api_football__fixture_players",     "fixtures/players"),
    ("api_football__fixture_predictions", "predictions"),
    ("api_football__fixture_odds",        "odds"),
]
