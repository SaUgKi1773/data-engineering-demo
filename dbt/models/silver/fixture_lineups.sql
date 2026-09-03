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
    -- Embedded player biography. This is the warehouse's only source of player
    -- attributes: /players was dropped from the manifest because it cannot be
    -- paged inside the provider's hourly request budget, and every field it
    -- carried is repeated here on each appearance. Country and nationality
    -- arrive as ids only, so dim_player resolves the names via core_countries.
    (lu->'player'->>'country_id')::INTEGER           AS player_country_id,
    (lu->'player'->>'nationality_id')::INTEGER       AS player_nationality_id,
    (lu->'player'->>'city_id')::INTEGER              AS player_city_id,
    (lu->'player'->>'detailed_position_id')::INTEGER AS player_detailed_position_id,
    lu->'player'->>'firstname'                       AS player_firstname,
    lu->'player'->>'lastname'                        AS player_lastname,
    lu->'player'->>'common_name'                     AS player_common_name,
    lu->'player'->>'display_name'                    AS player_display_name,
    lu->'player'->>'image_path'                      AS player_image_path,
    lu->'player'->>'gender'                          AS player_gender,
    (lu->'player'->>'date_of_birth')::DATE           AS player_date_of_birth,
    (lu->'player'->>'height')::INTEGER               AS player_height,
    (lu->'player'->>'weight')::INTEGER               AS player_weight,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"lineups": ["JSON"]}').lineups) AS t(lu)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.lineups')) > 0
