{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_id', 'persona_name']
) }}

WITH raw AS (
    SELECT
        match_id,
        season,
        round_number,
        match_name,
        generated_at,
        -- strip markdown code fence if the model wrapped output in ```json ... ```
        REGEXP_REPLACE(
            REGEXP_REPLACE(TRIM(raw_response), '^```(json)?\n?', ''),
            '\n?```$', ''
        ) AS cleaned_response
    FROM {{ source('bronze', 'groq__llm_match_discussions') }}
    {% if is_incremental() %}
    WHERE (season, round_number) NOT IN (
        SELECT DISTINCT season, round_number FROM {{ this }}
    )
    {% endif %}
)
SELECT
    r.match_id,
    r.season,
    r.round_number,
    r.match_name,
    r.generated_at,
    j.value->>'persona'  AS persona_name,
    j.value->>'message'  AS message
FROM raw r,
     json_each(r.cleaned_response::JSON) j
