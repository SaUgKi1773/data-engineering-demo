{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='player_id',
        merge_update_columns=['player_name', 'player_firstname', 'player_lastname', 'player_nationality', 'player_birth_date', 'player_birth_place', 'player_birth_country', 'player_height', 'player_weight', 'player_photo', 'player_position', 'player_detailed_position'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Player', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::DATE, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Player', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::DATE, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(player_sk, player_id, player_name, player_firstname, player_lastname, player_nationality, player_birth_date, player_birth_place, player_birth_country, player_height, player_weight, player_photo, player_position, player_detailed_position) WHERE t.player_sk NOT IN (SELECT player_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (id)
        id, display_name, firstname, lastname, nationality_name,
        date_of_birth, city_name, country_name, height, weight,
        image_path, position_name, detailed_position_name
    FROM {{ ref('players') }}
    WHERE id IS NOT NULL
      AND position_name != 'Coach'
    ORDER BY id, _ingested_at DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(player_sk), 0) FROM {{ this }} WHERE player_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY id) AS player_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY id) AS player_sk,
    {% endif %}
    id                     AS player_id,
    display_name           AS player_name,
    firstname              AS player_firstname,
    lastname               AS player_lastname,
    nationality_name       AS player_nationality,
    date_of_birth          AS player_birth_date,
    city_name              AS player_birth_place,
    country_name           AS player_birth_country,
    height                 AS player_height,
    weight                 AS player_weight,
    image_path             AS player_photo,
    position_name          AS player_position,
    detailed_position_name AS player_detailed_position
FROM latest
