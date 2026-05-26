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
    WHERE generated_at > (SELECT COALESCE(MAX(generated_at), '1970-01-01'::TIMESTAMP) FROM {{ this }})
    {% endif %}
),
valid AS (
    SELECT * FROM raw
    WHERE TRY_CAST(cleaned_response AS JSON) IS NOT NULL
)
SELECT
    r.match_id,
    r.season,
    r.round_number,
    r.match_name,
    r.generated_at,
    j.value->>'persona'  AS persona_name,
    j.value->>'message'  AS message
FROM valid r,
     json_each(r.cleaned_response::JSON) j
QUALIFY ROW_NUMBER() OVER (PARTITION BY r.match_id, j.value->>'persona' ORDER BY r.generated_at DESC) = 1
