{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_sk', 'persona_sk']
) }}

SELECT
    dm.match_sk,
    dp.persona_sk,
    s.season,
    s.message,
    s.generated_at
FROM {{ ref('llm_match_discussions') }}  s
JOIN {{ ref('dim_match') }}              dm ON dm.match_id    = s.match_id
JOIN {{ ref('dim_persona') }}            dp ON dp.persona_name = s.persona_name
{% if is_incremental() %}
WHERE s.generated_at > (SELECT COALESCE(MAX(generated_at), '1900-01-01') FROM {{ this }})
{% endif %}
