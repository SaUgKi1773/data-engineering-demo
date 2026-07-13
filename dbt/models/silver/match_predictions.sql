{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['match_id']
) }}

-- Typed pass-through of the data science handover (see ingestion/datascience/README.md).
-- Silver preserves the contract shape (one row per fixture, home/away perspective);
-- the explosion to team-side grain happens in gold.
SELECT
    match_id,
    league_id,
    season,
    round_number,
    match_name,
    kickoff_at,
    home_win_prob,
    draw_prob,
    away_win_prob,
    home_goals_exp,
    away_goals_exp,
    model_version,
    predicted_at
FROM {{ source('bronze', 'datascience__match_predictions') }}
{% if is_incremental() %}
WHERE predicted_at > (SELECT COALESCE(MAX(predicted_at), '1970-01-01'::TIMESTAMP) FROM {{ this }})
{% endif %}
