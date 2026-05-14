{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='league_id',
        merge_update_columns=['league_name', 'league_type', 'league_logo', 'league_country', 'league_country_code', 'league_country_flag', 'league_short_code', 'league_sub_type', 'league_is_active'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown League', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN), (-2, NULL::INTEGER, 'Not Applicable League', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN)) t(league_sk, league_id, league_name, league_type, league_logo, league_country, league_country_code, league_country_flag, league_short_code, league_sub_type, league_is_active) WHERE t.league_sk NOT IN (SELECT league_sk FROM {{ this }})"
        ]
    )
}}

SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(league_sk), 0) FROM {{ this }} WHERE league_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY l.id) AS league_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY l.id) AS league_sk,
    {% endif %}
    l.id              AS league_id,
    l.name            AS league_name,
    l.type            AS league_type,
    l.image_path      AS league_logo,
    c.name            AS league_country,
    c.iso2            AS league_country_code,
    c.flag_image_path AS league_country_flag,
    l.short_code      AS league_short_code,
    l.sub_type        AS league_sub_type,
    l.active          AS league_is_active
FROM {{ ref('league') }} l
LEFT JOIN {{ ref('core_countries') }} c ON c.id = l.country_id
WHERE l.id IS NOT NULL
