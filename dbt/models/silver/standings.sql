{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['league_id', 'season_id', '_source']
) }}

-- unique_key is a delete SCOPE: re-processing a league season replaces its
-- whole table for that source. Highlightly standing rows have no ids, and a
-- Sportmonks incremental window always carries complete season standings.
-- group_name holds Highlightly's raw table label ("Liga MX: Apertura",
-- "Primera División"); note the label DRIFTS across seasons for the same
-- league - conform in gold, never equality-match on it blindly.

SELECT
    s.id,
    (s.raw_json->>'participant_id')::INTEGER   AS team_id,
    (s.raw_json->>'league_id')::INTEGER        AS league_id,
    (s.raw_json->>'season_id')::INTEGER        AS season_id,
    (s.raw_json->>'stage_id')::INTEGER         AS stage_id,
    (s.raw_json->>'group_id')::INTEGER         AS group_id,
    (s.raw_json->>'round_id')::INTEGER         AS round_id,
    (s.raw_json->>'standing_rule_id')::INTEGER AS standing_rule_id,
    (s.raw_json->>'position')::INTEGER         AS position,
    s.raw_json->>'result'                      AS result,
    (s.raw_json->>'points')::INTEGER           AS points,
    s.raw_json->'participant'->>'name'         AS team_name,
    s.raw_json->'participant'->>'short_code'   AS team_short_code,
    s.raw_json->'participant'->>'image_path'   AS team_image_path,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 129 THEN (d->>'value')::INTEGER END) AS overall_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 130 THEN (d->>'value')::INTEGER END) AS overall_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 131 THEN (d->>'value')::INTEGER END) AS overall_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 132 THEN (d->>'value')::INTEGER END) AS overall_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 133 THEN (d->>'value')::INTEGER END) AS goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 134 THEN (d->>'value')::INTEGER END) AS goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 179 THEN (d->>'value')::INTEGER END) AS goal_diff,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 187 THEN (d->>'value')::INTEGER END) AS overall_points,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 135 THEN (d->>'value')::INTEGER END) AS home_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 136 THEN (d->>'value')::INTEGER END) AS home_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 137 THEN (d->>'value')::INTEGER END) AS home_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 138 THEN (d->>'value')::INTEGER END) AS home_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 139 THEN (d->>'value')::INTEGER END) AS home_goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 140 THEN (d->>'value')::INTEGER END) AS home_goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 185 THEN (d->>'value')::INTEGER END) AS home_points,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 141 THEN (d->>'value')::INTEGER END) AS away_played,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 142 THEN (d->>'value')::INTEGER END) AS away_won,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 143 THEN (d->>'value')::INTEGER END) AS away_draw,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 144 THEN (d->>'value')::INTEGER END) AS away_lost,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 145 THEN (d->>'value')::INTEGER END) AS away_goals_for,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 146 THEN (d->>'value')::INTEGER END) AS away_goals_against,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 186 THEN (d->>'value')::INTEGER END) AS away_points,
    MAX(CASE WHEN (d->>'type_id')::INTEGER = 176 THEN d->>'value' END)            AS streak,
    NULL::VARCHAR                                                                  AS group_name,
    'sportmonks'                                                                   AS _source,
    MAX(s._ingested_at)                                                            AS _ingested_at
FROM {{ source('bronze', 'sportmonks__standings') }} AS s,
unnest(json_transform(s.raw_json::VARCHAR, '{"details": ["JSON"]}').details) AS t(d)
WHERE json_array_length(json_extract(s.raw_json::VARCHAR, '$.details')) > 0
{% if is_incremental() %}
AND s._ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
{% endif %}
GROUP BY s.id, s.raw_json

UNION ALL

-- Highlightly branch: one bronze row per table group (Liga MX gets two per
-- season, Apertura + Clausura), unnested to one row per team. total/home/away
-- blocks map onto the overall/home/away measures; home_points/away_points and
-- streak are not provided and stay NULL. goal_diff is derived - the payload
-- does not carry it.
SELECT
    NULL::INTEGER                                        AS id,
    (st->'team'->>'id')::INTEGER                         AS team_id,
    s._league_id                                         AS league_id,
    s._season_id                                         AS season_id,
    NULL::INTEGER                                        AS stage_id,
    NULL::INTEGER                                        AS group_id,
    NULL::INTEGER                                        AS round_id,
    NULL::INTEGER                                        AS standing_rule_id,
    (st->>'position')::INTEGER                           AS position,
    NULL::VARCHAR                                        AS result,
    (st->>'points')::INTEGER                             AS points,
    st->'team'->>'name'                                  AS team_name,
    NULL::VARCHAR                                        AS team_short_code,
    st->'team'->>'logo'                                  AS team_image_path,
    (st->'total'->>'games')::INTEGER                     AS overall_played,
    (st->'total'->>'wins')::INTEGER                      AS overall_won,
    (st->'total'->>'draws')::INTEGER                     AS overall_draw,
    (st->'total'->>'loses')::INTEGER                     AS overall_lost,
    (st->'total'->>'scoredGoals')::INTEGER               AS goals_for,
    (st->'total'->>'receivedGoals')::INTEGER             AS goals_against,
    (st->'total'->>'scoredGoals')::INTEGER
      - (st->'total'->>'receivedGoals')::INTEGER         AS goal_diff,
    (st->>'points')::INTEGER                             AS overall_points,
    (st->'home'->>'games')::INTEGER                      AS home_played,
    (st->'home'->>'wins')::INTEGER                       AS home_won,
    (st->'home'->>'draws')::INTEGER                      AS home_draw,
    (st->'home'->>'loses')::INTEGER                      AS home_lost,
    (st->'home'->>'scoredGoals')::INTEGER                AS home_goals_for,
    (st->'home'->>'receivedGoals')::INTEGER              AS home_goals_against,
    NULL::INTEGER                                        AS home_points,
    (st->'away'->>'games')::INTEGER                      AS away_played,
    (st->'away'->>'wins')::INTEGER                       AS away_won,
    (st->'away'->>'draws')::INTEGER                      AS away_draw,
    (st->'away'->>'loses')::INTEGER                      AS away_lost,
    (st->'away'->>'scoredGoals')::INTEGER                AS away_goals_for,
    (st->'away'->>'receivedGoals')::INTEGER              AS away_goals_against,
    NULL::INTEGER                                        AS away_points,
    NULL::VARCHAR                                        AS streak,
    json_extract_string(s.raw_json, '$.name')            AS group_name,
    'highlightly'                                        AS _source,
    s._ingested_at
FROM {{ source('bronze', 'highlightly__standings') }} AS s,
unnest(json_transform(s.raw_json::VARCHAR, '{"standings": ["JSON"]}').standings) AS t(st)
{% if is_incremental() %}
WHERE s._ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
