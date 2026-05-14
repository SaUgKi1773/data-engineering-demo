{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='team_id',
        merge_update_columns=['team_name', 'team_code', 'team_country', 'team_founded_year', 'team_logo'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Team', NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Team', NULL::VARCHAR, NULL::VARCHAR, NULL::INTEGER, NULL::VARCHAR)) t(team_sk, team_id, team_name, team_code, team_country, team_founded_year, team_logo) WHERE t.team_sk NOT IN (SELECT team_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (id)
        id, name, short_code, country_name, founded, image_path
    FROM {{ ref('teams') }}
    ORDER BY id, last_played_at DESC NULLS LAST
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(team_sk), 0) FROM {{ this }} WHERE team_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY id) AS team_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY id) AS team_sk,
    {% endif %}
    id           AS team_id,
    name         AS team_name,
    short_code   AS team_code,
    country_name AS team_country,
    founded      AS team_founded_year,
    image_path   AS team_logo
FROM latest
WHERE id IS NOT NULL
