{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'sport_id')::INTEGER             AS sport_id,
    (raw_json->>'player_id')::INTEGER            AS player_id,
    (raw_json->>'type_id')::INTEGER              AS type_id,
    (raw_json->>'from_team_id')::INTEGER         AS from_team_id,
    (raw_json->>'to_team_id')::INTEGER           AS to_team_id,
    (raw_json->>'position_id')::INTEGER          AS position_id,
    (raw_json->>'detailed_position_id')::INTEGER AS detailed_position_id,
    (raw_json->>'date')::DATE                    AS transfer_date,
    (raw_json->>'career_ended')::BOOLEAN         AS career_ended,
    (raw_json->>'completed')::BOOLEAN            AS completed,
    (raw_json->>'amount')::BIGINT                AS amount,
    -- player (embedded; counterparty club is frequently foreign / not in bronze)
    raw_json->'player'->>'name'                  AS player_name,
    raw_json->'player'->>'common_name'           AS player_common_name,
    raw_json->'player'->>'display_name'          AS player_display_name,
    raw_json->'player'->>'image_path'            AS player_image_path,
    -- from team
    raw_json->'fromteam'->>'name'                AS from_team_name,
    raw_json->'fromteam'->>'short_code'          AS from_team_short_code,
    raw_json->'fromteam'->>'image_path'          AS from_team_image_path,
    (raw_json->'fromteam'->>'country_id')::INTEGER AS from_team_country_id,
    (raw_json->'fromteam'->>'placeholder')::BOOLEAN AS from_team_placeholder,
    -- to team
    raw_json->'toteam'->>'name'                  AS to_team_name,
    raw_json->'toteam'->>'short_code'            AS to_team_short_code,
    raw_json->'toteam'->>'image_path'            AS to_team_image_path,
    (raw_json->'toteam'->>'country_id')::INTEGER AS to_team_country_id,
    (raw_json->'toteam'->>'placeholder')::BOOLEAN AS to_team_placeholder,
    -- type
    raw_json->'type'->>'name'                    AS type_name,
    raw_json->'type'->>'code'                    AS type_code,
    raw_json->'type'->>'developer_name'          AS type_developer_name,
    -- position
    raw_json->'position'->>'name'                AS position_name,
    raw_json->'position'->>'code'                AS position_code,
    raw_json->'detailedposition'->>'name'        AS detailed_position_name,
    raw_json->'detailedposition'->>'code'        AS detailed_position_code,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__transfers') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
