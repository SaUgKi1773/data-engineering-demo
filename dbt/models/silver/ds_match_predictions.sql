{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_id', 'model_version', 'predicted_at']
) }}

-- Predictions published by the data science pipeline (append-only bronze).
-- History is kept on purpose: the accuracy tracker scores the last prediction
-- made before kickoff, so later re-predictions must not overwrite earlier ones.
-- Contract violations (probabilities out of range / not summing to 1) are NOT
-- filtered here — they fail the contract tests and stop the pipeline loudly.

SELECT
    match_id,
    league_id,
    season,
    round_number,
    match_name,
    model_version,
    p_home_win,
    p_draw,
    p_away_win,
    expected_home_goals,
    expected_away_goals,
    predicted_at
FROM {{ source('bronze', 'ds__match_predictions') }}
{% if is_incremental() %}
WHERE predicted_at > (SELECT COALESCE(MAX(predicted_at), '1970-01-01'::TIMESTAMP) FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY match_id, model_version, predicted_at
    ORDER BY p_home_win
) = 1
