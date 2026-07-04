"""
Sportmonks bronze ingestion entry point.

Usage
-----
  python run.py --mode full --db /path/to/local.duckdb
  python run.py --mode incremental --db md:superligaen
  python run.py                          # DUCKDB_PATH env var or config default
  python run.py --tables sportmonks__states,sportmonks__tv_stations
  python run.py --mode full --leagues 501                      # one league only
  python run.py --mode full --leagues 501 --seasons 2015/2016  # one season backfill

Note: --tables skips the seasons/teams bootstrap, so date_based and
season_based entries will produce 0 rows when run in isolation.

League/season scoping: deletes on league-tagged tables (league, seasons,
fixtures) are constrained to the scoped leagues, so other leagues' bronze
rows survive a scoped run.  Cross-league tables (players, transfers, rivals,
reference data) are always refreshed in full.  --seasons narrows which
seasons are iterated (use with --mode full); bronze season storage stays
complete regardless.

Modes
-----
Both modes load every table.  The difference is refresh granularity, driven by
each table's delete strategy in ENDPOINT_MANIFEST:

  full          Complete historical load from FIRST_SEASON_YEAR onwards.
                  global tables   → full truncate + reload
                  seasonal tables → all in-scope seasons deleted + reloaded
                  fixtures        → all season date ranges in 90-day chunks

  incremental   Daily refresh (default).
                  global tables   → full truncate + reload  (same as full)
                  seasonal tables → current season only deleted + reloaded
                  fixtures        → rolling window: last 7 days + next 60 days

The entire pipeline is driven by ENDPOINT_MANIFEST in config.py.
To add, remove, or adjust an endpoint — edit the manifest, not this file.
"""

import argparse
import logging
import os
import sys
from datetime import datetime, timezone

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

from db import connect, ensure_schema
import engine


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sportmonks football bronze ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="incremental",
        help="full = initial historical load; incremental = daily refresh (default)",
    )
    parser.add_argument(
        "--db",
        default=None,
        metavar="PATH_OR_URL",
        help=(
            "DuckDB file path or MotherDuck URL (e.g. md:superligaen). "
            "Falls back to DUCKDB_PATH env var, then config default."
        ),
    )
    parser.add_argument(
        "--tables",
        default=None,
        metavar="TABLE1,TABLE2",
        help="Comma-separated list of table names to run (default: all).",
    )
    parser.add_argument(
        "--leagues",
        default=None,
        metavar="ID1,ID2",
        help="Comma-separated league ids to scope the run to "
             "(default: all configured leagues).",
    )
    parser.add_argument(
        "--seasons",
        default=None,
        metavar="NAME1,NAME2",
        help='Comma-separated season names to iterate, e.g. "2015/2016" '
             "(default: all in scope). Intended for --mode full backfills.",
    )
    args = parser.parse_args()

    if "SPORTMONKS_API_KEY" not in os.environ:
        log.error("SPORTMONKS_API_KEY is not set — check your .env file")
        sys.exit(1)

    tables  = set(args.tables.split(",")) if args.tables else None
    leagues = [int(x) for x in args.leagues.split(",")] if args.leagues else None
    seasons = [s.strip() for s in args.seasons.split(",")] if args.seasons else None
    conn = connect(args.db)
    ensure_schema(conn)
    started_at = datetime.now(timezone.utc).replace(tzinfo=None)
    try:
        engine.run(conn, mode=args.mode, tables=tables, leagues=leagues, seasons=seasons)
        conn.execute(
            "INSERT INTO meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["sportmonks", args.mode, "success", started_at, datetime.now(timezone.utc).replace(tzinfo=None), None],
        )
    except Exception as exc:
        conn.execute(
            "INSERT INTO meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["sportmonks", args.mode, "failure", started_at, datetime.now(timezone.utc).replace(tzinfo=None), str(exc)],
        )
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
