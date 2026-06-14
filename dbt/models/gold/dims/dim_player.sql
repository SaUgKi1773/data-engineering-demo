{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='player_id',
        merge_update_columns=['player_name', 'player_firstname', 'player_lastname', 'player_nationality', 'player_birth_date', 'player_birth_place', 'player_birth_country', 'player_height', 'player_weight', 'player_photo', 'player_position', 'player_detailed_position', 'player_main_position'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE player_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player', 'Unknown', 'Unknown', 'Unknown Player Nationality', NULL::DATE, 'Unknown Player Birth Place', 'Unknown Player Birth Country', NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Unknown Player Position', 'Unknown Player Position', 'Unknown Main Position'), (-2, NULL::INTEGER, 'Not Applicable Player', 'Not Applicable', 'Not Applicable', 'Not Applicable Player Nationality', NULL::DATE, 'Not Applicable Player Birth Place', 'Not Applicable Player Birth Country', NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Player Position', 'Not Applicable Player Position', 'Not Applicable Main Position')) t(player_sk, player_id, player_name, player_firstname, player_lastname, player_nationality, player_birth_date, player_birth_place, player_birth_country, player_height, player_weight, player_photo, player_position, player_detailed_position, player_main_position)"
        ]
    )
}}

WITH from_players AS (
    SELECT DISTINCT ON (id)
        id             AS player_id,
        display_name   AS player_name,
        firstname      AS player_firstname,
        lastname       AS player_lastname,
        nationality_name AS player_nationality,
        date_of_birth  AS player_birth_date,
        city_name      AS player_birth_place,
        country_name   AS player_birth_country,
        height         AS player_height,
        weight         AS player_weight,
        image_path     AS player_photo,
        position_name  AS player_position,
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
    FROM {{ ref('players') }}
    WHERE id IS NOT NULL
      AND position_name != 'Coach'
    ORDER BY id, _ingested_at DESC
),
from_lineups AS (
    SELECT DISTINCT ON (player_id)
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
        position_name  AS player_position,
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
    FROM {{ ref('fixture_lineups') }}
    WHERE player_id IS NOT NULL
      AND player_id NOT IN (SELECT player_id FROM from_players)
    ORDER BY player_id, _ingested_at DESC
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
      AND player_id NOT IN (SELECT player_id FROM from_players)
      AND player_id NOT IN (SELECT player_id FROM from_lineups)
    ORDER BY player_id, transfer_date DESC NULLS LAST
),
combined AS (
    SELECT * FROM from_players
    UNION ALL
    SELECT * FROM from_lineups
    UNION ALL
    SELECT * FROM from_transfers
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(player_sk), 0) FROM {{ this }} WHERE player_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY player_id) AS player_sk,
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
    player_main_position
FROM combined
