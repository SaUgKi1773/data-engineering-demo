{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['id', '_source']
) }}

-- One row per league. Highlightly has no league endpoint: a league's identity
-- travels on every match payload, so its row is distilled from the matches.

WITH unambiguous_countries AS (
    -- Highlightly identifies a country by ISO2 rather than a Sportmonks id.
    -- Codes shared by several rows (GB covers Scotland, Wales and Northern
    -- Ireland) resolve to nothing rather than fanning the league row out.
    SELECT iso2, MIN(id) AS country_id
    FROM {{ ref('core_countries') }}
    WHERE iso2 IS NOT NULL
    GROUP BY iso2
    HAVING COUNT(*) = 1
),
highlightly_leagues AS (
    SELECT DISTINCT ON (id)
        id, name, image_path, country_iso2, _ingested_at
    FROM (
        SELECT
            (raw_json->'league'->>'id')::INTEGER  AS id,
            raw_json->'league'->>'name'           AS name,
            raw_json->'league'->>'logo'           AS image_path,
            raw_json->'country'->>'code'          AS country_iso2,
            _ingested_at
        FROM {{ source('bronze', 'highlightly__matches') }}
        {% if is_incremental() %}
        WHERE _ingested_at > COALESCE(
            (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'),
            '1900-01-01'::TIMESTAMP)
        {% endif %}
    )
    ORDER BY id, _ingested_at DESC
)

SELECT
    id,
    (raw_json->>'sport_id')::INTEGER    AS sport_id,
    (raw_json->>'country_id')::INTEGER  AS country_id,
    raw_json->>'name'                   AS name,
    raw_json->>'short_code'             AS short_code,
    raw_json->>'type'                   AS type,
    raw_json->>'sub_type'               AS sub_type,
    (raw_json->>'active')::BOOLEAN      AS active,
    (raw_json->>'category')::INTEGER    AS category,
    (raw_json->>'has_jerseys')::BOOLEAN AS has_jerseys,
    (raw_json->>'last_played_at')::TIMESTAMP AS last_played_at,
    raw_json->>'image_path'             AS image_path,
    'sportmonks'                        AS _source,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__league') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
{% endif %}

UNION ALL

SELECT
    hl.id,
    NULL::INTEGER       AS sport_id,
    uc.country_id,
    hl.name,
    NULL::VARCHAR       AS short_code,
    -- every Highlightly competition in scope is a domestic league; the
    -- provider carries no type field of its own
    'league'            AS type,
    NULL::VARCHAR       AS sub_type,
    TRUE                AS active,
    NULL::INTEGER       AS category,
    NULL::BOOLEAN       AS has_jerseys,
    NULL::TIMESTAMP     AS last_played_at,
    hl.image_path,
    'highlightly'       AS _source,
    hl._ingested_at
FROM highlightly_leagues hl
LEFT JOIN unambiguous_countries uc ON uc.iso2 = hl.country_iso2
