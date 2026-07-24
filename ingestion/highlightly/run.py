"""
Highlightly bronze ingestion entry point (Liga MX).

Usage
-----
  python run.py                                  # nightly: current season + backfill chip
  python run.py --mode full                      # re-list every in-scope season too
  python run.py --seasons 2024                   # scope to one season
  python run.py --details-limit 10               # cap detail calls (probing / dry runs)
  python run.py --db md:superligaen              # target MotherDuck

Modes
-----
There is no separate backfill job. Both modes refresh season lists and then
spend the remaining daily budget on missing match details, newest first:

  incremental  (default)  re-lists the CURRENT season only. Historical seasons
                          are finished and do not change, so re-listing them
                          nightly would waste 4 calls each.
  full                    re-lists every season in scope. Use after changing
                          FIRST_SEASON, or to repair a season list.

The free plan allows 100 requests/day, so the historical backfill lands over
roughly a week of nightly runs rather than in one go. That is by design: the
run stops cleanly when the quota is spent and resumes the next night, and the
outstanding work is derived from the data (finished matches with no detail
row) rather than from any stored cursor.
"""

import argparse
import logging
import os
import sys
from datetime import datetime, timezone

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

import engine
from db import connect, ensure_schema

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Highlightly (Liga MX) bronze ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--mode", choices=["full", "incremental"], default="incremental",
                        help="incremental = current season list + backfill chip (default)")
    parser.add_argument("--db", default=None, metavar="PATH_OR_URL",
                        help="DuckDB path or MotherDuck URL. Falls back to DUCKDB_PATH.")
    parser.add_argument("--seasons", default=None, metavar="YEAR1,YEAR2",
                        help="Comma-separated Highlightly season years (default: all in scope).")
    parser.add_argument("--details-limit", type=int, default=None, metavar="N",
                        help="Cap match-detail calls this run (default: whatever budget allows).")
    args = parser.parse_args()

    if "HIGHLIGHTLY_API_KEY" not in os.environ:
        log.error("HIGHLIGHTLY_API_KEY is not set — check your .env file")
        sys.exit(1)

    seasons = [int(s) for s in args.seasons.split(",")] if args.seasons else None

    conn = connect(args.db)
    ensure_schema(conn)
    started_at = datetime.now(timezone.utc).replace(tzinfo=None)
    try:
        engine.run(conn, mode=args.mode, seasons=seasons, details_limit=args.details_limit)
        conn.execute(
            "INSERT INTO meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["highlightly", args.mode, "success", started_at,
             datetime.now(timezone.utc).replace(tzinfo=None), None],
        )
    except Exception as exc:
        conn.execute(
            "INSERT INTO meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["highlightly", args.mode, "failure", started_at,
             datetime.now(timezone.utc).replace(tzinfo=None), str(exc)],
        )
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
