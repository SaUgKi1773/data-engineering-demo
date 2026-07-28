{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

-- Country names arrive from Sportmonks and are used as display names wherever
-- a league, club or coach shows its country. They come through as English
-- exonyms with one exception: Turkey, which Sportmonks writes under its
-- endonym. Normalising it here rather than in each dimension keeps one spelling
-- across the warehouse - dim_team already carried both, "Turkey" on the 33 clubs
-- Highlightly reports directly and "Türkiye" on the 34 that arrive through a
-- transfer payload and resolve their country through this table.
--
-- `official_name` and `fifa_name` are left exactly as the provider sends them:
-- they are reference attributes, not display names, and nothing renders them.
SELECT
    id,
    (raw_json->>'continent_id')::INTEGER AS continent_id,
    CASE raw_json->>'name'
        WHEN 'Türkiye' THEN 'Turkey'
        ELSE raw_json->>'name'
    END                                  AS name,
    raw_json->>'official_name'           AS official_name,
    raw_json->>'fifa_name'               AS fifa_name,
    raw_json->>'iso2'                    AS iso2,
    raw_json->>'iso3'                    AS iso3,
    raw_json->>'image_path'              AS flag_image_path,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__core_countries') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
