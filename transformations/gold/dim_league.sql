-- Dimension: league
-- One row per league. Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_league AS
SELECT
    ROW_NUMBER() OVER (ORDER BY league_id)::INTEGER AS league_sk,
    league_id,
    league_name,
    league_type,
    league_logo,
    country_name,
    country_code,
    country_flag
FROM {db}.silver.leagues
UNION ALL
SELECT -1, NULL, 'Unknown League',        NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT -2, NULL, 'Not Applicable League', NULL, NULL, NULL, NULL, NULL;
