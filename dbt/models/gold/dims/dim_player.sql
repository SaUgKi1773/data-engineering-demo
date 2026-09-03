{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['player_id', '_source'],
        merge_update_columns=['player_name', 'player_firstname', 'player_lastname', 'player_nationality', 'player_birth_date', 'player_birth_place', 'player_birth_country', 'player_height', 'player_weight', 'player_photo', 'player_position', 'player_detailed_position', 'player_main_position'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE player_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player', 'Unknown', 'Unknown', 'Unknown Player Nationality', NULL::DATE, 'Unknown Player Birth Place', 'Unknown Player Birth Country', NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Unknown Player Position', 'Unknown Player Position', 'Unknown Main Position', NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Player', 'Not Applicable', 'Not Applicable', 'Not Applicable Player Nationality', NULL::DATE, 'Not Applicable Player Birth Place', 'Not Applicable Player Birth Country', NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Player Position', 'Not Applicable Player Position', 'Not Applicable Main Position', NULL::VARCHAR)) t(player_sk, player_id, player_name, player_firstname, player_lastname, player_nationality, player_birth_date, player_birth_place, player_birth_country, player_height, player_weight, player_photo, player_position, player_detailed_position, player_main_position, _source)"
        ]
    )
}}

-- Player attributes come from the lineup rows themselves. Sportmonks' /players
-- endpoint was dropped from ingestion (see ingestion/sportmonks/config.py): it
-- cannot be paged inside the provider's per-entity hourly request budget, and
-- every attribute it served is embedded in each fixture's lineups[].player.
-- The trade is birth place, which needs a cities endpoint we do not ingest, and
-- players who never appeared in a fixture, which no mart selects.
WITH countries AS (
    SELECT id, name FROM {{ ref('core_countries') }}
),
from_lineups AS (
    SELECT DISTINCT ON (l.player_id)
        l.player_id,
        COALESCE(l.player_display_name, l.player_name) AS player_name,
        l.player_firstname,
        l.player_lastname,
        nat.name              AS player_nationality,
        l.player_date_of_birth AS player_birth_date,
        -- birth place needs a city lookup the pipeline does not ingest
        NULL::VARCHAR         AS player_birth_place,
        ctry.name             AS player_birth_country,
        l.player_height,
        l.player_weight,
        l.player_image_path   AS player_photo,
        l.position_name       AS player_position,
        l.detailed_position_name AS player_detailed_position,
        CASE l.position_name
            WHEN 'Goalkeeper'   THEN 'Goalkeeper'
            WHEN 'Centre Back'  THEN 'Defender'
            WHEN 'Defender'     THEN 'Defender'
            WHEN 'Central Midfield' THEN 'Midfielder'
            WHEN 'Midfielder'   THEN 'Midfielder'
            WHEN 'Attacker'     THEN 'Attacker'
            WHEN 'Centre Forward' THEN 'Attacker'
            WHEN 'Not Applicable Player Position' THEN 'Not Applicable Main Position'
            ELSE 'Unknown Main Position'
        END AS player_main_position
    FROM {{ ref('fixture_lineups') }} l
    LEFT JOIN countries nat  ON nat.id  = l.player_nationality_id
    LEFT JOIN countries ctry ON ctry.id = l.player_country_id
    WHERE l.player_id IS NOT NULL
      AND (l.position_name IS NULL OR l.position_name <> 'Coach')
    -- newest appearance wins: position and photo follow the player's latest club
    ORDER BY l.player_id, l._ingested_at DESC
),
from_transfers AS (
    -- Players we only know from a transfer (e.g. foreign signings who never
    -- appeared in an ingested fixture). Name, photo and position come from the
    -- embedded transfer payload; the rest is unknown.
    SELECT DISTINCT ON (player_id)
        player_id,
        player_display_name    AS player_name,
        NULL::VARCHAR  AS player_firstname,
        NULL::VARCHAR  AS player_lastname,
        NULL::VARCHAR  AS player_nationality,
        NULL::DATE     AS player_birth_date,
        NULL::VARCHAR  AS player_birth_place,
        NULL::VARCHAR  AS player_birth_country,
        NULL::INTEGER  AS player_height,
        NULL::INTEGER  AS player_weight,
        player_image_path      AS player_photo,
        position_name          AS player_position,
        detailed_position_name AS player_detailed_position,
        CASE position_name
            WHEN 'Goalkeeper'   THEN 'Goalkeeper'
            WHEN 'Centre Back'  THEN 'Defender'
            WHEN 'Defender'     THEN 'Defender'
            WHEN 'Central Midfield' THEN 'Midfielder'
            WHEN 'Midfielder'   THEN 'Midfielder'
            WHEN 'Attacker'     THEN 'Attacker'
            WHEN 'Centre Forward' THEN 'Attacker'
            WHEN 'Not Applicable Player Position' THEN 'Not Applicable Main Position'
            ELSE 'Unknown Main Position'
        END AS player_main_position
    FROM {{ ref('transfers') }}
    WHERE player_id IS NOT NULL
      AND (position_name IS NULL OR position_name <> 'Coach')
      AND player_id NOT IN (SELECT player_id FROM from_lineups)
    ORDER BY player_id, transfer_date DESC NULLS LAST
),
-- Highlightly has no player endpoint and no usable lineups, so its players are
-- distilled from the people who appear in match events.
--
-- The id is trustworthy - one id traces one coherent career across clubs - but
-- the NAME is not: 68% of ids carry several spellings, and the provider both
-- abbreviates ("J. Márquez") and corrects itself ("Ángel" -> "Jeremy"). The
-- canonical form is therefore the most recent NON-abbreviated spelling, which
-- prefers a real name over an initial and a correction over what it replaced.
from_highlightly_events AS (
    SELECT
        player_id,
        FIRST(player_name ORDER BY is_abbreviated ASC, starting_at DESC) AS player_name
    FROM (
        SELECT
            e.player_id,
            e.player_name,
            f.starting_at,
            regexp_matches(e.player_name, '^[A-Za-zÀ-ÿ]\.') AS is_abbreviated
        FROM {{ ref('fixture_events') }} e
        JOIN {{ ref('fixtures') }} f ON f.id = e.fixture_id AND f._source = e._source
        WHERE e._source = 'highlightly'
          AND e.player_id  IS NOT NULL
          AND e.player_name IS NOT NULL
    )
    GROUP BY player_id
),
from_highlightly AS (
    SELECT
        player_id,
        player_name,
        NULL::VARCHAR  AS player_firstname,
        NULL::VARCHAR  AS player_lastname,
        NULL::VARCHAR  AS player_nationality,
        NULL::DATE     AS player_birth_date,
        NULL::VARCHAR  AS player_birth_place,
        NULL::VARCHAR  AS player_birth_country,
        NULL::INTEGER  AS player_height,
        NULL::INTEGER  AS player_weight,
        NULL::VARCHAR  AS player_photo,
        -- the feed carries no position for these players, and an event does
        -- not imply one
        'Unknown Player Position' AS player_position,
        'Unknown Player Position' AS player_detailed_position,
        'Unknown Main Position'   AS player_main_position
    FROM from_highlightly_events
),
combined AS (
    SELECT *, 'sportmonks'  AS _source FROM from_lineups
    UNION ALL
    SELECT *, 'sportmonks'  AS _source FROM from_transfers
    UNION ALL
    SELECT *, 'highlightly' AS _source FROM from_highlightly
),
sourced AS (
    SELECT * FROM combined
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(player_sk), 0) FROM {{ this }} WHERE player_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY player_id, _source) AS player_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY player_id, _source) AS player_sk,
    {% endif %}
    player_id,
    player_name,
    player_firstname,
    player_lastname,
    player_nationality,
    player_birth_date,
    player_birth_place,
    player_birth_country,
    player_height,
    player_weight,
    player_photo,
    player_position,
    player_detailed_position,
    player_main_position,
    _source
FROM sourced
