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
    country_name                                     AS league_country,
    country_code                                     AS league_country_code,
    country_flag                                     AS league_country_flag
FROM {db}.silver.leagues
UNION ALL
SELECT -1, NULL, 'Unknown League',        'Unknown League', NULL, 'Unknown League', 'Unknown League', NULL
UNION ALL
SELECT -2, NULL, 'Not Applicable League', 'Not Applicable League', NULL, 'Not Applicable League', 'Not Applicable League', NULL;
