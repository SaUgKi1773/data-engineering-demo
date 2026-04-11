"""
Master orchestrator — entry point for all ingestion runs.

Usage:
  # Daily incremental (default: 2-day lookback)
  python ingestion/run.py

  # Daily incremental, custom lookback
  python ingestion/run.py --lookback 5

  # Full load — all leagues, all seasons
  python ingestion/run.py --full-load

  # Full load — one league, all seasons
  python ingestion/run.py --full-load --league 119

  # Full load — one league, one season
  python ingestion/run.py --full-load --league 119 --season 2025

  # Full load — all leagues, one season
  python ingestion/run.py --full-load --season 2025

  # Target a specific database
  python ingestion/run.py --db superligaen
"""

import argparse
import logging
from datetime import date, timedelta

from config import CURRENT_SEASON, FIRST_SEASON, LEAGUES
from db import connect, delete_season, ensure_schema_and_tables, truncate_all
from ingest_fixtures import delete_fixture_window, fetch_fixtures, load_fixture_details, load_fixtures_bulk
from ingest_league import load_reference_data, load_season_aggregates, load_season_reference
from ingest_teams import load_team_data

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)


def run(
    lookback_days: int = 2,
    full_load: bool = False,
    league_id: int | None = None,
    season: int | None = None,
    target_db: str | None = None,
) -> None:
    conn = connect(target_db)
    ensure_schema_and_tables(conn)

    leagues = [l for l in LEAGUES if league_id is None or l["id"] == league_id]
    if not leagues:
        raise ValueError(f"League {league_id} not found in config.LEAGUES")

    if full_load:
        seasons = [season] if season else list(range(FIRST_SEASON, CURRENT_SEASON + 1))
        log.info("Full load — leagues: %s  seasons: %s", [l["id"] for l in leagues], seasons)

        # Wipe everything only when loading all leagues and all seasons
        if not league_id and not season:
            truncate_all(conn)

        for league in leagues:
            lid  = league["id"]
            load_reference_data(conn, lid, league["country"])

            for s in seasons:
                log.info("=== League %d  Season %d ===", lid, s)
                if league_id or season:
                    # Targeted run — clean only what we're about to reload
                    delete_season(conn, lid, s)
                load_season_aggregates(conn, lid, s)
                fixtures = fetch_fixtures(lid, s)
                load_fixtures_bulk(conn, fixtures)
                load_fixture_details(conn, fixtures)
                load_season_reference(conn, lid, s)
                load_team_data(conn, lid, s)

    else:
        from_date = (date.today() - timedelta(days=lookback_days)).isoformat()
        to_date   = date.today().isoformat()
        log.info("Incremental load — window: %s to %s", from_date, to_date)

        for league in leagues:
            lid = league["id"]
            log.info("=== League %d ===", lid)

            # Season aggregates — full refresh for current season
            load_season_aggregates(conn, lid, CURRENT_SEASON, incremental=True)

            # Fixtures — delete date window then reload
            delete_fixture_window(conn, lid, from_date, to_date)
            fixtures = fetch_fixtures(lid, CURRENT_SEASON, from_date=from_date, to_date=to_date)
            load_fixtures_bulk(conn, fixtures)
            load_fixture_details(conn, fixtures)

            # Reference and team data — full refresh for current season
            load_reference_data(conn, lid, league["country"])
            load_season_reference(conn, lid, CURRENT_SEASON)
            load_team_data(conn, lid, CURRENT_SEASON)

    conn.close()
    log.info("Bronze ingestion complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest bronze data into MotherDuck")
    parser.add_argument("--lookback", type=int, default=2,
                        help="Days to look back for finished fixtures (default: 2)")
    parser.add_argument("--full-load", action="store_true",
                        help="Historical load — requires upgraded API plan")
    parser.add_argument("--league", type=int, default=None,
                        help="League ID to load (default: all leagues in config.LEAGUES)")
    parser.add_argument("--season", type=int, default=None,
                        help="Season year for --full-load (e.g. 2025). Omit to load all seasons.")
    parser.add_argument("--db", dest="target_db", default=None,
                        help="Target MotherDuck database (default: $TARGET_DB or 'superligaen_dev')")
    args = parser.parse_args()
    run(
        lookback_days=args.lookback,
        full_load=args.full_load,
        league_id=args.league,
        season=args.season,
        target_db=args.target_db,
    )
