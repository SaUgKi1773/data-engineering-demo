WITH from_venues AS (
    SELECT DISTINCT ON (id)
        id           AS venue_id,
        name,
        address,
        city_name    AS city,
        country_name AS country,
        surface,
        capacity
    FROM {{ ref('venues') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
from_fixtures AS (
    SELECT DISTINCT
        venue_id,
        venue_name   AS name,
        NULL         AS address,
        venue_city   AS city,
        NULL         AS country,
        venue_surface AS surface,
        venue_capacity AS capacity
    FROM {{ ref('fixtures') }}
    WHERE venue_id IS NOT NULL
      AND venue_id NOT IN (SELECT venue_id FROM from_venues)
      AND venue_name IS NOT NULL
),
combined AS (
    SELECT * FROM from_venues
    UNION ALL
    SELECT * FROM from_fixtures
)
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_id) AS stadium_sk,
    venue_id   AS stadium_id,
    name       AS stadium_name,
    address    AS stadium_address,
    city       AS stadium_city,
    country    AS stadium_country,
    capacity   AS stadium_capacity,
    surface    AS stadium_surface
FROM combined
UNION ALL SELECT -1, NULL, 'Unknown Stadium',        NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Stadium', NULL, NULL, NULL, NULL, NULL
