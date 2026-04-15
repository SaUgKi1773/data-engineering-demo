-- Dimension: stadium
-- One row per stadium.
-- SK is stable: new stadiums get the next available SK; existing stadiums keep theirs.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_stadium (
    stadium_sk       INTEGER NOT NULL,
    stadium_id       INTEGER,
    stadium_name     VARCHAR,
    stadium_address  VARCHAR,
    stadium_city     VARCHAR,
    stadium_country  VARCHAR,
    stadium_capacity INTEGER,
    stadium_surface  VARCHAR
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_stadium
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, 'Unknown Stadium',        'Unknown Stadium',        'Unknown Stadium',        'Unknown Stadium',        NULL::INTEGER, 'Unknown Stadium'),
    (-2, NULL::INTEGER, 'Not Applicable Stadium', 'Not Applicable Stadium', 'Not Applicable Stadium', 'Not Applicable Stadium', NULL::INTEGER, 'Not Applicable Stadium')
) t(stadium_sk, stadium_id, stadium_name, stadium_address, stadium_city, stadium_country, stadium_capacity, stadium_surface)
WHERE t.stadium_sk NOT IN (SELECT stadium_sk FROM {db}.gold.dim_stadium);

-- Insert new stadiums not yet in the dim
INSERT INTO {db}.gold.dim_stadium
SELECT
    (SELECT COALESCE(MAX(stadium_sk), 0) FROM {db}.gold.dim_stadium WHERE stadium_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.venue_id) AS stadium_sk,
    src.venue_id    AS stadium_id,
    src.venue_name  AS stadium_name,
    src.address     AS stadium_address,
    src.city        AS stadium_city,
    src.country     AS stadium_country,
    src.capacity    AS stadium_capacity,
    src.surface     AS stadium_surface
FROM {db}.silver.venues src
WHERE src.venue_id NOT IN (
    SELECT stadium_id FROM {db}.gold.dim_stadium WHERE stadium_id IS NOT NULL
);

-- Update attributes for existing stadiums
UPDATE {db}.gold.dim_stadium tgt
SET
    stadium_name     = src.venue_name,
    stadium_address  = src.address,
    stadium_city     = src.city,
    stadium_country  = src.country,
    stadium_capacity = src.capacity,
    stadium_surface  = src.surface
FROM {db}.silver.venues src
WHERE tgt.stadium_id = src.venue_id;
