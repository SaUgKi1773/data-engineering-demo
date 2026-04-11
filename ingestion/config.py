"""
Ingestion configuration — single source of truth for leagues and endpoint metadata.

To add a new league:              add an entry to LEAGUES.
To add a new season endpoint:     add a tuple to SEASON_ENDPOINTS.
To add a new fixture-detail:      add a tuple to FIXTURE_DETAIL_ENDPOINTS.
To add a new team endpoint:       add a tuple to TEAM_ENDPOINTS.
To add a new coach endpoint:      add a tuple to COACH_ENDPOINTS.
To add a new reference endpoint:  add a tuple to REFERENCE_ENDPOINTS.
No other files need to change.
"""

API_BASE     = "https://v3.football.api-sports.io"
MAX_RETRIES  = 10
FIRST_SEASON = 2020

# ---------------------------------------------------------------------------
# Leagues — add an entry here to start ingesting a new league
# ---------------------------------------------------------------------------

LEAGUES = [
    {"id": 119, "country": "Denmark"},
]

# ---------------------------------------------------------------------------
# Group 1 — Leagues
# Filter: league_id
# Always fetched first. Current season is derived from this data.
# ---------------------------------------------------------------------------

LEAGUE_ENDPOINT = ("api_football__leagues", "leagues")

# ---------------------------------------------------------------------------
# Group 2 — Season endpoints
# Filter: league_id + season
# One row per (season, league_id).
# Players is listed separately because it requires pagination.
# ---------------------------------------------------------------------------

SEASON_ENDPOINTS = [
    ("api_football__standings",      "standings"),
    ("api_football__topscorers",     "players/topscorers"),
    ("api_football__topassists",     "players/topassists"),
    ("api_football__topyellowcards", "players/topyellowcards"),
    ("api_football__topredcards",    "players/topredcards"),
    ("api_football__injuries",       "injuries"),
    ("api_football__teams",          "teams"),
    ("api_football__rounds",         "fixtures/rounds"),
]

SEASON_PLAYERS_ENDPOINT = ("api_football__players", "players")  # paginated

# ---------------------------------------------------------------------------
# Group 3 — Fixtures
# Filter: league_id + season (+ optional date range for daily loads)
# Fixtures are bulk-inserted by fixture_id.
# Detail endpoints are then called per finished fixture_id.
# ---------------------------------------------------------------------------

FIXTURE_ENDPOINT = ("api_football__fixtures", "fixtures")

FIXTURE_DETAIL_ENDPOINTS = [
    ("api_football__fixture_events",      "fixtures/events"),
    ("api_football__fixture_statistics",  "fixtures/statistics"),
    ("api_football__fixture_lineups",     "fixtures/lineups"),
    ("api_football__fixture_players",     "fixtures/players"),
    ("api_football__fixture_predictions", "predictions"),
    ("api_football__fixture_odds",        "odds"),
]

# ---------------------------------------------------------------------------
# Group 4 — Teams
# Coaches are fetched first (team_id filter) so their IDs can be passed
# to coach-level endpoints. All results stored per team_id.
# ---------------------------------------------------------------------------

TEAM_ENDPOINTS = [
    ("api_football__coaches",   "coachs"),
    ("api_football__squads",    "players/squads"),
    ("api_football__transfers", "transfers"),
]

# Fetched per coach_id, aggregated and stored per team_id
COACH_ENDPOINTS = [
    ("api_football__sidelined", "sidelined"),
    ("api_football__trophies",  "trophies"),
]

# Needs league_id + season + team_id — handled separately in ingest_teams.py
TEAM_STATISTICS_ENDPOINT = ("api_football__team_statistics", "teams/statistics")

# ---------------------------------------------------------------------------
# Group 5 — Reference
# Catch-all for endpoints that don't fit the season or team loop.
# Each tuple: (table, endpoint, param_key)
# param_key maps to a field in the league dict (e.g. "country" → league["country"])
# ---------------------------------------------------------------------------

REFERENCE_ENDPOINTS = [
    ("api_football__venues", "venues", "country"),
]
