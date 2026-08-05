{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='fixture_id'
) }}

-- unique_key is a delete SCOPE, not a row identity: one bronze row carries a
-- fixture's complete lineup, so re-processing it replaces the whole thing.
-- Sportmonks publishes a provisional XI before kick-off and reissues the
-- confirmed one under NEW lineup ids, so keying on the lineup id would leave
-- every superseded row behind. Gold picks type_id 11 over 12 per player, so a
-- leftover pre-match starter outranks the bench row that replaced them and the
-- match shows more than eleven starters — two goalkeepers included.
WITH src AS MATERIALIZED (
    SELECT *
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    {% if is_incremental() %}
    WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
    {% endif %}
)

SELECT
    (lu->>'id')::BIGINT               AS id,
    f.id                              AS fixture_id,
    (lu->>'player_id')::INTEGER       AS player_id,
    (lu->>'team_id')::INTEGER         AS team_id,
    (lu->>'position_id')::INTEGER     AS position_id,
    (lu->>'type_id')::INTEGER         AS type_id,
    lu->>'player_name'                AS player_name,
    (lu->>'jersey_number')::INTEGER   AS jersey_number,
    lu->>'formation_field'            AS formation_field,
    (lu->>'formation_position')::INTEGER AS formation_position,
    lu->'type'->>'name'                  AS type_name,
    lu->'position'->>'name'              AS position_name,
    lu->'position'->>'code'              AS position_code,
    lu->'detailedposition'->>'name'      AS detailed_position_name,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"lineups": ["JSON"]}').lineups) AS t(lu)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.lineups')) > 0
