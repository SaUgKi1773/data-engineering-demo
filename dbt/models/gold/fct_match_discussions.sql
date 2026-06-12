{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_sk', 'persona_sk']
) }}

SELECT
    dm.match_sk,
    dp.persona_sk,
    (year(s.generated_at) * 10000 + month(s.generated_at) * 100 + day(s.generated_at))::INTEGER AS date_sk,
    s.message
FROM {{ ref('llm_match_discussions') }}  s
JOIN {{ ref('dim_match') }}              dm ON dm.match_id    = s.match_id
JOIN {{ ref('dim_persona') }}            dp ON dp.persona_name = s.persona_name
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
