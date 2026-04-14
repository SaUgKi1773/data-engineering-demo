-- Dimension: venue
-- One row per venue plus an 'Unknown' sentinel (venue_sk = 0) for fixtures
-- where the venue is not populated. Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_venue AS
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_id)::INTEGER AS venue_sk,
    venue_id,
    venue_name,
    address,
    city,
    country,
    capacity,
    surface
FROM {db}.silver.venues
UNION ALL
SELECT -1, NULL, 'Unknown Venue',        NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT -2, NULL, 'Not Applicable Venue', NULL, NULL, NULL, NULL, NULL;
