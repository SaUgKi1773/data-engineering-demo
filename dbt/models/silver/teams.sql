{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['id', '_source']
) }}

SELECT
    id,
    (raw_json->>'country_id')::INTEGER       AS country_id,
    (raw_json->>'venue_id')::INTEGER         AS venue_id,
    raw_json->>'name'                        AS name,
    raw_json->>'short_code'                  AS short_code,
    raw_json->>'gender'                      AS gender,
    raw_json->>'type'                        AS type,
    (raw_json->>'founded')::INTEGER          AS founded,
    (raw_json->>'placeholder')::BOOLEAN      AS placeholder,
    (raw_json->>'last_played_at')::TIMESTAMP AS last_played_at,
    raw_json->>'image_path'                  AS image_path,
    raw_json->'country'->>'name'             AS country_name,
    raw_json->'venue'->>'name'               AS venue_name,
    raw_json->'venue'->>'city_name'          AS venue_city,
    (raw_json->'venue'->>'capacity')::INTEGER AS venue_capacity,
    _season_id,
    'sportmonks'                             AS _source,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__teams') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
{% endif %}

UNION ALL

-- Highlightly branch: no team entity endpoint in bronze, so teams are
-- distilled from match participants — one row per team id, latest match wins
-- (name/logo can change over time). country_name is the league's country,
-- which holds for every club in a domestic league.
SELECT
    t.id,
    NULL::INTEGER                            AS country_id,
    NULL::INTEGER                            AS venue_id,
    t.name,
    NULL::VARCHAR                            AS short_code,
    NULL::VARCHAR                            AS gender,
    NULL::VARCHAR                            AS type,
    NULL::INTEGER                            AS founded,
    NULL::BOOLEAN                            AS placeholder,
    NULL::TIMESTAMP                          AS last_played_at,
    t.image_path,
    t.country_name,
    NULL::VARCHAR                            AS venue_name,
    NULL::VARCHAR                            AS venue_city,
    NULL::INTEGER                            AS venue_capacity,
    t._season_id,
    'highlightly'                            AS _source,
    t._ingested_at
FROM (
    SELECT
        (raw_json->'homeTeam'->>'id')::INTEGER AS id,
        raw_json->'homeTeam'->>'name'          AS name,
        raw_json->'homeTeam'->>'logo'          AS image_path,
        raw_json->'country'->>'name'           AS country_name,
        _season_id,
        _fixture_date,
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
    UNION ALL
    SELECT
        (raw_json->'awayTeam'->>'id')::INTEGER,
        raw_json->'awayTeam'->>'name',
        raw_json->'awayTeam'->>'logo',
        raw_json->'country'->>'name',
        _season_id,
        _fixture_date,
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
) t
WHERE 1=1
{% if is_incremental() %}
  AND t._ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
  -- placeholder participants are not clubs; their fixtures are repaired to the
  -- real opponent in fixture_participants
  AND t.id NOT IN (SELECT placeholder_team_id FROM {{ ref('highlightly_team_overrides') }})
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.id ORDER BY t._fixture_date DESC, t._ingested_at DESC) = 1
