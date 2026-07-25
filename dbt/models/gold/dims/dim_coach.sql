{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['coach_id', '_source'],
        merge_update_columns=['coach_name', 'coach_display_name', 'coach_firstname', 'coach_lastname', 'coach_nationality', 'coach_image_path'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE coach_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Coach', 'Unknown Coach', 'Unknown', 'Unknown', 'Unknown Coach Nationality', NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Coach', 'Not Applicable Coach', 'Not Applicable', 'Not Applicable', 'Not Applicable Coach Nationality', NULL::VARCHAR, NULL::VARCHAR)) t(coach_sk, coach_id, coach_name, coach_display_name, coach_firstname, coach_lastname, coach_nationality, coach_image_path, _source)"
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
),
-- src exists so _source is a real column the surrogate-key ordering can use:
-- a window ORDER BY cannot reference a SELECT alias.
src AS (
    SELECT
        l.coach_id,
        l.common_name  AS coach_name,
        l.display_name AS coach_display_name,
        l.firstname    AS coach_firstname,
        l.lastname     AS coach_lastname,
        c.name         AS coach_nationality,
        l.image_path   AS coach_image_path,
        -- fixture_coaches is a Sportmonks-only feed; Highlightly carries no
        -- coach data at all
        'sportmonks'   AS _source
    FROM latest l
    LEFT JOIN {{ ref('core_countries') }} c ON c.id = l.nationality_id
    WHERE l.coach_id IS NOT NULL
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(coach_sk), 0) FROM {{ this }} WHERE coach_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY coach_id, _source) AS coach_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY coach_id, _source) AS coach_sk,
    {% endif %}
    coach_id,
    coach_name,
    coach_display_name,
    coach_firstname,
    coach_lastname,
    coach_nationality,
    coach_image_path,
    _source
FROM src
