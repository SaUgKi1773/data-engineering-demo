"""
Gold transformation runner — builds the Kimball dimensional model.

Dimensions are always fully replaced. The fact table uses an incremental
DELETE + INSERT pattern matching the silver fixture window.

Load modes:
  Daily incremental  — dimensions full replace; fact refreshed within the
                       lookback + 4-week-ahead date window.
  Full load          — dimensions full replace; fact fully rebuilt.

Usage:
  python transformations/run_gold.py                    # daily incremental
  python transformations/run_gold.py --lookback 5       # custom lookback window
  python transformations/run_gold.py --full-load        # full rebuild
  python transformations/run_gold.py --db superligaen   # target prod database
"""

import argparse
import logging
import os
from datetime import date, timedelta
from pathlib import Path

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

SQL_DIR = Path(__file__).parent / "gold"

DIMENSIONS = [
    "dim_date",
    "dim_time",
    "dim_team",
    "dim_opponent_team",
    "dim_league",
    "dim_stadium",
    "dim_referee",
    "dim_match",
    "dim_team_side",
    "dim_match_result",
]

FACTS = [
    "fct_match_results",
]


def _connect(target_db: str | None) -> tuple[duckdb.DuckDBPyConnection, str]:
    db = target_db or os.getenv("TARGET_DB", "superligaen_dev")
    token = os.environ["MOTHERDUCK_TOKEN"]
    conn = duckdb.connect(f"md:{db}?motherduck_token={token}")
    log.info("Connected to MotherDuck: %s", db)
    return conn, db


def _run_sql(
    conn: duckdb.DuckDBPyConnection,
    db: str,
    table: str,
    delete_filter: str = "TRUE",
    insert_filter: str = "TRUE",
) -> None:
    """Read a SQL file, substitute placeholders, execute each statement."""
    sql = (SQL_DIR / f"{table}.sql").read_text().format(
        db=db,
        delete_filter=delete_filter,
        insert_filter=insert_filter,
    )
    stripped = "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")
    )
    for stmt in stripped.split(";"):
        stmt = stmt.strip()
        if stmt:
            conn.execute(stmt)
    log.info("  %-35s  filter: %s", f"{db}.gold.{table}", insert_filter)


def _date_sk(d: date) -> int:
    """Convert a date to the YYYYMMDD integer used as date_sk."""
    return int(d.strftime("%Y%m%d"))


def run(
    lookback_days: int = 2,
    full_load: bool = False,
    target_db: str | None = None,
) -> None:
    conn, db = _connect(target_db)

    # Dimensions are always fully replaced
    log.info("=== Gold layer build — %s.gold ===", db)
    log.info("-- Dimensions (full replace) --")
    for table in DIMENSIONS:
        _run_sql(conn, db, table)

    log.info("-- Facts --")
    if full_load:
        log.info("Mode: full load")
        for table in FACTS:
            _run_sql(conn, db, table, delete_filter="TRUE", insert_filter="TRUE")
    else:
        from_sk  = _date_sk(date.today() - timedelta(days=lookback_days))
        to_sk    = _date_sk(date.today() + timedelta(weeks=4))
        scope    = f"date_sk >= {from_sk} AND date_sk <= {to_sk}"
        log.info("Mode: incremental  from=%d  to=%d", from_sk, to_sk)
        for table in FACTS:
            _run_sql(conn, db, table, delete_filter=scope, insert_filter=scope)

    conn.close()
    log.info("Gold build complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build gold Kimball dimensional model")
    parser.add_argument(
        "--lookback", type=int, default=2,
        help="Days to look back for incremental fact window (default: 2)",
    )
    parser.add_argument(
        "--full-load", action="store_true",
        help="Full rebuild — replace all fact rows from current silver",
    )
    parser.add_argument(
        "--db", dest="target_db", default=None,
        help="Target MotherDuck database (default: $TARGET_DB or 'superligaen_dev')",
    )
    args = parser.parse_args()
    run(
        lookback_days=args.lookback,
        full_load=args.full_load,
        target_db=args.target_db,
    )
