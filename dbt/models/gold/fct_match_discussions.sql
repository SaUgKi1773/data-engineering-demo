{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_sk', 'persona_sk']
) }}

WITH match_dates AS (
    SELECT DISTINCT match_sk, date_sk
    FROM {{ ref('fct_team_matches') }}
)
SELECT
    dm.match_sk,
    dp.persona_sk,
    md.date_sk,
    s.message
FROM {{ ref('llm_match_discussions') }}  s
JOIN {{ ref('dim_match') }}              dm ON dm.match_id    = s.match_id
JOIN {{ ref('dim_persona') }}            dp ON dp.persona_name = s.persona_name
JOIN match_dates                         md ON md.match_sk    = dm.match_sk
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 FROM {{ this }} t
    WHERE t.match_sk = dm.match_sk AND t.persona_sk = dp.persona_sk
)
{% endif %}
