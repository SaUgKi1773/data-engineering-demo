-- Dimension: stadium
-- One row per stadium plus sentinel rows for fixtures with no stadium data.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_stadium AS
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_id)::INTEGER AS stadium_sk,
    venue_id                                        AS stadium_id,
    venue_name                                      AS stadium_name,
    address,
    city,
    country,
    capacity,
    surface
FROM {db}.silver.venues
UNION ALL
SELECT -1, NULL, 'Unknown Stadium',        NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT -2, NULL, 'Not Applicable Stadium', NULL, NULL, NULL, NULL, NULL;
