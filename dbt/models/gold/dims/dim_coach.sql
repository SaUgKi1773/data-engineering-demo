{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='coach_id',
        merge_update_columns=['coach_name', 'coach_display_name', 'coach_firstname', 'coach_lastname', 'coach_nationality_id', 'coach_image_path'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Coach', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::VARCHAR)) t(coach_sk, coach_id, coach_name, coach_display_name, coach_firstname, coach_lastname, coach_nationality_id, coach_image_path) WHERE t.coach_sk NOT IN (SELECT coach_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (coach_id)
        coach_id,
        common_name,
        display_name,
        firstname,
        lastname,
        nationality_id,
        image_path
    FROM {{ ref('fixture_coaches') }}
    ORDER BY coach_id, _ingested_at DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(coach_sk), 0) FROM {{ this }} WHERE coach_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY coach_id) AS coach_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY coach_id) AS coach_sk,
    {% endif %}
    coach_id,
    common_name    AS coach_name,
    display_name   AS coach_display_name,
    firstname      AS coach_firstname,
    lastname       AS coach_lastname,
    nationality_id AS coach_nationality_id,
    image_path     AS coach_image_path
FROM latest
WHERE coach_id IS NOT NULL
