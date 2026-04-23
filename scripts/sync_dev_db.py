"""
Syncs superligaen_dev from superligaen (prod).

Steps:
  1. Discover all schemas and tables in prod
  2. Drop all existing tables in dev
  3. Recreate each table in dev, filtering by season where the column exists

Pass --season <year> (e.g. 2024) or comma-separated years (e.g. 2023,2024).
Tables without a season column are always copied in full (e.g. venues).
"""

import argparse
import logging
import os

import duckdb
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger(__name__)

PROD_DB = "superligaen"
DEV_DB  = "superligaen_dev"


def connect():
    token = os.environ["MOTHERDUCK_TOKEN"]
    return duckdb.connect(f"md:?motherduck_token={token}")


def season_column_info(con, db):
    """Returns {(schema, table): data_type} for every table that has a season column."""
    rows = con.execute(f"""
        SELECT schema_name, table_name, data_type
        FROM duckdb_columns()
        WHERE database_name = '{db}'
          AND column_name = 'season'
    """).fetchall()
    return {(schema, table): dtype for schema, table, dtype in rows}


def season_filter(dtype, seasons):
    """Build a WHERE season IN (...) clause matching the season column's type."""
    if "INT" in dtype.upper():
        vals = ", ".join(str(s) for s in seasons)
        return f"WHERE season IN ({vals})"
    vals = ", ".join(f"'{s}/{str(s + 1)[-2:]}'" for s in seasons)
    return f"WHERE season IN ({vals})"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--season", required=True,
                        help="Comma-separated season year(s) to copy (e.g. 2024 or 2023,2024)")
    args = parser.parse_args()
    seasons = [int(s.strip()) for s in args.season.split(",")]

    con = connect()

    # Discover all base tables in prod
    prod_tables = con.execute(f"""
        SELECT schema_name, table_name
        FROM duckdb_tables()
        WHERE database_name = '{PROD_DB}'
        ORDER BY schema_name, table_name
    """).fetchall()

    if not prod_tables:
        log.error("No tables found in %s — aborting", PROD_DB)
        raise SystemExit(1)

    log.info("Found %d tables in %s", len(prod_tables), PROD_DB)

    # Determine which tables have a season column and their type
    season_cols = season_column_info(con, PROD_DB)
    log.info("Season-filterable tables: %d", len(season_cols))

    # Drop existing tables in dev
    dev_tables = con.execute(f"""
        SELECT schema_name, table_name
        FROM duckdb_tables()
        WHERE database_name = '{DEV_DB}'
        ORDER BY schema_name, table_name DESC
    """).fetchall()

    for schema, table in dev_tables:
        log.info("Dropping %s.%s.%s", DEV_DB, schema, table)
        con.execute(f"DROP TABLE IF EXISTS {DEV_DB}.{schema}.{table}")

    # Ensure schemas exist in dev
    schemas = {row[0] for row in prod_tables}
    for schema in schemas:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {DEV_DB}.{schema}")

    # Copy each table from prod to dev
    copied = 0
    for schema, table in prod_tables:
        key = (schema, table)
        if key in season_cols:
            where = season_filter(season_cols[key], seasons)
            log.info("Copying %s.%s (seasons=%s)", schema, table, seasons)
        else:
            where = ""
            log.info("Copying %s.%s (full)", schema, table)

        con.execute(f"""
            CREATE OR REPLACE TABLE {DEV_DB}.{schema}.{table} AS
            SELECT * FROM {PROD_DB}.{schema}.{table}
            {where}
        """)
        copied += 1

    log.info("Sync complete — %d tables copied from %s to %s (seasons: %s)",
             copied, PROD_DB, DEV_DB, seasons)


if __name__ == "__main__":
    main()
