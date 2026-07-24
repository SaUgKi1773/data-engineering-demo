"""
Highlightly bronze ingestion entry point.

Every league in config.LEAGUES rides the same code path; adding one is a line
of config, and --leagues scopes a run to a subset.

Usage
-----
  python run.py --from-date 2024-07-01 --to-date 2024-12-31   # seed a window
  python run.py --days-back 7                                 # rolling window
  python run.py --seasons 2024                                # a whole season
  python run.py --leagues 223746                              # one league only
  python run.py --details-limit 20                            # cap detail calls
  python run.py --db md:superligaen                           # target MotherDuck

Not in the nightly pipeline yet
-------------------------------
This runs by hand (or from the highlightly.yml dispatch workflow) while the
historical backfill is seeded a window at a time. Once coverage is complete it
joins master.yml as a parallel bronze job using --days-back, the same rolling
shape as the Sportmonks ingest.

Scoping
-------
A run does two passes: refresh the season lists it touches (cheap, 4 calls per
season, and it keeps scheduled fixtures/scores current), then fetch missing
match details (one call per finished match — the expensive part).

  --from-date/--to-date   window for the detail pass; also decides which
                          seasons get re-listed. A window spanning July covers
                          two Highlightly seasons and both are handled.
  --days-back N           shorthand for a window ending today.
  --seasons               explicit season scope, overriding the window.
  (none of the above)     details are fetched newest-first across all seasons
                          in scope, so the freshest football lands first.

Budget
------
The free plan allows 100 requests/day, shared across every league on the key.
The client reads the remaining quota from every response and stops cleanly when
it runs out, so a large window is safe to ask for: it fetches what it can and
the next run resumes. Nothing stores a cursor — the outstanding work is derived
from the data (finished matches with no detail row).

With more than one league in scope the detail pass interleaves them, so the
quota is shared rather than drained by whichever league comes first.
"""

import argparse
import logging
import os
import sys
from datetime import date, datetime, timedelta, timezone

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


def _parse_date(value: str, flag: str) -> date:
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        log.error("%s must be YYYY-MM-DD, got %r", flag, value)
        sys.exit(2)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Highlightly bronze ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--mode", choices=["full", "incremental"], default="incremental",
                        help="full = re-list every season in scope (default: only those touched)")
    parser.add_argument("--db", default=None, metavar="PATH_OR_URL",
                        help="DuckDB path or MotherDuck URL. Falls back to DUCKDB_PATH.")
    parser.add_argument("--leagues", default=None, metavar="ID1,ID2",
                        help="Comma-separated Highlightly league ids "
                             "(default: every league in config.LEAGUES).")
    parser.add_argument("--seasons", default=None, metavar="YEAR1,YEAR2",
                        help="Comma-separated Highlightly season years; overrides the date window.")
    parser.add_argument("--from-date", default=None, metavar="YYYY-MM-DD",
                        help="Start of the match-detail window.")
    parser.add_argument("--to-date", default=None, metavar="YYYY-MM-DD",
                        help="End of the match-detail window (default: today when --from-date is given).")
    parser.add_argument("--days-back", type=int, default=None, metavar="N",
                        help="Shorthand for a window of the last N days ending today.")
    parser.add_argument("--details-limit", type=int, default=None, metavar="N",
                        help="Cap match-detail calls this run (default: whatever budget allows).")
    args = parser.parse_args()

    if "HIGHLIGHTLY_API_KEY" not in os.environ:
        log.error("HIGHLIGHTLY_API_KEY is not set — check your .env file")
        sys.exit(1)

    if args.days_back is not None and (args.from_date or args.to_date):
        log.error("--days-back cannot be combined with --from-date/--to-date")
        sys.exit(2)

    from_date = to_date = None
    if args.days_back is not None:
        to_date = date.today()
        from_date = to_date - timedelta(days=args.days_back)
    else:
        if args.from_date:
            from_date = _parse_date(args.from_date, "--from-date")
        if args.to_date:
            to_date = _parse_date(args.to_date, "--to-date")
        # A start with no end means "from there to now", which is what someone
        # seeding a backfill forward from a date means.
        if from_date and not to_date:
            to_date = date.today()
    if from_date and to_date and from_date > to_date:
        log.error("--from-date (%s) is after --to-date (%s)", from_date, to_date)
        sys.exit(2)

    seasons = [int(s) for s in args.seasons.split(",")] if args.seasons else None
    leagues = None
    if args.leagues and args.leagues.strip().lower() != "all":
        leagues = [int(x) for x in args.leagues.split(",")]

    conn = connect(args.db)
    ensure_schema(conn)
    started_at = datetime.now(timezone.utc).replace(tzinfo=None)
    try:
        engine.run(conn, mode=args.mode, leagues=leagues, seasons=seasons,
                   from_date=from_date, to_date=to_date,
                   details_limit=args.details_limit)
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
