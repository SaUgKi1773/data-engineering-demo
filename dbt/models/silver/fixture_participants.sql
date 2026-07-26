{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', 'team_id', '_source']
) }}

WITH src AS MATERIALIZED (
    SELECT *
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    {% if is_incremental() %}
    WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
    {% endif %}
)

SELECT
    f.id                                       AS fixture_id,
    (participant->>'id')::INTEGER              AS team_id,
    participant->>'name'                       AS team_name,
    participant->>'short_code'                 AS team_short_code,
    participant->>'image_path'                 AS team_image_path,
    participant->'meta'->>'location'           AS location,
    (participant->'meta'->>'winner')::BOOLEAN  AS winner,
    (participant->'meta'->>'position')::INTEGER AS position,
    'sportmonks'                               AS _source,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"participants": ["JSON"]}').participants) AS t(participant)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.participants')) > 0

UNION ALL

-- Highlightly branch: exactly two participants per match, straight off the
-- homeTeam/awayTeam objects. winner stays NULL — gold derives results from
-- fixture_scores, where penalty shootouts are represented properly.
SELECT
    id                                         AS fixture_id,
    COALESCE(o.canonical_team_id, (raw_json->'homeTeam'->>'id')::INTEGER)     AS team_id,
    COALESCE(o.canonical_team_name, raw_json->'homeTeam'->>'name')            AS team_name,
    NULL::VARCHAR                              AS team_short_code,
    raw_json->'homeTeam'->>'logo'              AS team_image_path,
    'home'                                     AS location,
    NULL::BOOLEAN                              AS winner,
    NULL::INTEGER                              AS position,
    'highlightly'                              AS _source,
    _ingested_at
FROM {{ source('bronze', 'highlightly__matches') }}
-- A placeholder participant the provider never resolved; repaired from the
-- other leg of the same tie. See the seed for the evidence.
LEFT JOIN {{ ref('highlightly_team_overrides') }} o
    ON o.placeholder_team_id = (raw_json->'homeTeam'->>'id')::INTEGER
{% if is_incremental() %}
WHERE _ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}

UNION ALL

SELECT
    id                                         AS fixture_id,
    COALESCE(o.canonical_team_id, (raw_json->'awayTeam'->>'id')::INTEGER)     AS team_id,
    COALESCE(o.canonical_team_name, raw_json->'awayTeam'->>'name')            AS team_name,
    NULL::VARCHAR                              AS team_short_code,
    raw_json->'awayTeam'->>'logo'              AS team_image_path,
    'away'                                     AS location,
    NULL::BOOLEAN                              AS winner,
    NULL::INTEGER                              AS position,
    'highlightly'                              AS _source,
    _ingested_at
FROM {{ source('bronze', 'highlightly__matches') }}
LEFT JOIN {{ ref('highlightly_team_overrides') }} o
    ON o.placeholder_team_id = (raw_json->'awayTeam'->>'id')::INTEGER
{% if is_incremental() %}
WHERE _ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
