"""
Gold transformation runner — builds the Kimball dimensional model.

All tables are fully replaced on every run. Dimensions are built first
so the fact table can resolve surrogate keys via JOIN.

Usage:
  python transformations/run_gold.py                    # target dev db
  python transformations/run_gold.py --db superligaen   # target prod db
"""

import argparse
import logging
import os
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
    "dim_league",
    "dim_venue",
    "dim_referee",
    "dim_round",
    "dim_match_role",
    "dim_result",
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


def _run_sql(conn: duckdb.DuckDBPyConnection, db: str, table: str) -> None:
    """Read a SQL file, substitute the {db} placeholder, execute each statement."""
    sql = (SQL_DIR / f"{table}.sql").read_text().format(db=db)
    stripped = "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")
    )
    for stmt in stripped.split(";"):
        stmt = stmt.strip()
        if stmt:
            conn.execute(stmt)
    log.info("  %-35s  OK", f"{db}.gold.{table}")


def run(target_db: str | None = None) -> None:
    conn, db = _connect(target_db)
    log.info("=== Gold layer build — %s.gold ===", db)

    log.info("-- Dimensions --")
    for table in DIMENSIONS:
        _run_sql(conn, db, table)

    log.info("-- Facts --")
    for table in FACTS:
        _run_sql(conn, db, table)

    conn.close()
    log.info("Gold build complete")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build gold Kimball dimensional model")
    parser.add_argument(
        "--db", dest="target_db", default=None,
        help="Target MotherDuck database (default: $TARGET_DB or 'superligaen_dev')",
    )
    args = parser.parse_args()
    run(target_db=args.target_db)
