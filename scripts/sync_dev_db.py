"""
Syncs superligaen_dev from superligaen (prod).

Steps:
  1. Discover all schemas and tables in prod
  2. Drop all existing tables in dev
  3. Recreate each table in dev as a full copy from prod
"""

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


def main():
    con = connect()

    # Discover all base tables in prod
    prod_tables = con.execute(f"""
        SELECT table_schema, table_name
        FROM {PROD_DB}.information_schema.tables
        WHERE table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name
    """).fetchall()

    if not prod_tables:
        log.error("No tables found in %s — aborting", PROD_DB)
        raise SystemExit(1)

    log.info("Found %d tables in %s", len(prod_tables), PROD_DB)

    # Drop existing tables in dev (in reverse to respect any dependencies)
    dev_tables = con.execute(f"""
        SELECT table_schema, table_name
        FROM {DEV_DB}.information_schema.tables
        WHERE table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name DESC
    """).fetchall()

    for schema, table in dev_tables:
        log.info("Dropping %s.%s.%s", DEV_DB, schema, table)
        con.execute(f"DROP TABLE IF EXISTS {DEV_DB}.{schema}.{table}")

    # Ensure schemas exist in dev
    schemas = {row[0] for row in prod_tables}
    for schema in schemas:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {DEV_DB}.{schema}")

    # Copy each table from prod to dev
    for schema, table in prod_tables:
        log.info("Copying %s.%s -> %s.%s", PROD_DB, f"{schema}.{table}", DEV_DB, f"{schema}.{table}")
        con.execute(f"""
            CREATE OR REPLACE TABLE {DEV_DB}.{schema}.{table} AS
            SELECT * FROM {PROD_DB}.{schema}.{table}
        """)

    log.info("Sync complete — %d tables copied from %s to %s", len(prod_tables), PROD_DB, DEV_DB)


if __name__ == "__main__":
    main()
