-- Dimension: stadium
-- One row per stadium plus sentinel rows for fixtures with no stadium data.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_stadium AS
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_id)::INTEGER AS stadium_sk,
    venue_id                                        AS stadium_id,
    venue_name                                      AS stadium_name,
    address                                         AS stadium_address,
    city                                            AS stadium_city,
    country                                         AS stadium_country,
    capacity                                        AS stadium_capacity,
    surface                                         AS stadium_surface
FROM {db}.silver.venues
UNION ALL
SELECT -1, NULL, 'Unknown Stadium',        'Unknown Stadium', 'Unknown Stadium', 'Unknown Stadium', NULL, 'Unknown Stadium'
UNION ALL
SELECT -2, NULL, 'Not Applicable Stadium', 'Not Applicable Stadium', 'Not Applicable Stadium', 'Not Applicable Stadium', NULL, 'Not Applicable Stadium';
