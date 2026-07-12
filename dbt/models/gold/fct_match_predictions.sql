{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'team_side_sk', 'prediction_model_sk', 'predicted_at']
    )
}}

-- Match outcome predictions published by the data science pipeline, conformed
-- to the warehouse grain: one row per team per match per prediction event,
-- mirroring fct_team_matches. A match can be re-predicted on later runs, so
-- predicted_at is part of the grain; the accuracy marts score the latest
-- prediction with is_pre_kickoff = true.

WITH predictions AS (
    SELECT
        match_id,
        league_id,
        model_version,
        predicted_at,
        p_home_win,
        p_draw,
        p_away_win,
        expected_home_goals,
        expected_away_goals
    FROM {{ ref('ds_match_predictions') }}
    {% if is_incremental() %}
    WHERE predicted_at > (SELECT COALESCE(MAX(predicted_at), '1970-01-01'::TIMESTAMP) FROM {{ this }})
    {% endif %}
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
match_teams AS (
    SELECT
        p.fixture_id,
        p.team_id,
        p.location,
        opp.team_id AS opponent_team_id
    FROM participants p
    JOIN participants opp
        ON opp.fixture_id = p.fixture_id
       AND opp.location  != p.location
),
src AS (
    SELECT
        s.match_id,
        s.league_id,
        s.model_version,
        s.predicted_at,
        fx.starting_at,
        mt.team_id,
        mt.location,
        mt.opponent_team_id,
        CASE mt.location WHEN 'home' THEN s.p_home_win          ELSE s.p_away_win          END AS win_probability,
        s.p_draw                                                                               AS draw_probability,
        CASE mt.location WHEN 'home' THEN s.p_away_win          ELSE s.p_home_win          END AS loss_probability,
        CASE mt.location WHEN 'home' THEN s.expected_home_goals ELSE s.expected_away_goals END AS expected_goals_scored,
        CASE mt.location WHEN 'home' THEN s.expected_away_goals ELSE s.expected_home_goals END AS expected_goals_conceded
    FROM predictions s
    JOIN match_teams            mt ON mt.fixture_id = s.match_id
    LEFT JOIN {{ ref('fixtures') }} fx ON fx.id      = s.match_id
)
SELECT
    COALESCE(dd.date_sk,              -1) AS date_sk,
    COALESCE(dteam.team_sk,           -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk,   -1) AS opponent_team_sk,
    COALESCE(dl.league_sk,            -1) AS league_sk,
    COALESCE(dm.match_sk,             -1) AS match_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                   AS team_side_sk,
    COALESCE(dpm.prediction_model_sk, -1) AS prediction_model_sk,
    src.predicted_at,
    src.predicted_at < src.starting_at    AS is_pre_kickoff,
    src.win_probability,
    src.draw_probability,
    src.loss_probability,
    src.expected_goals_scored,
    src.expected_goals_conceded
FROM src
LEFT JOIN {{ ref('dim_date') }}             dd    ON dd.date                        = src.starting_at::DATE
LEFT JOIN {{ ref('dim_team') }}             dteam ON dteam.team_id                  = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }}    dopp  ON dopp.opponent_team_id          = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}           dl    ON dl.league_id                   = src.league_id
LEFT JOIN {{ ref('dim_match') }}            dm    ON dm.match_id                    = src.match_id
LEFT JOIN {{ ref('dim_prediction_model') }} dpm   ON dpm.prediction_model_version   = src.model_version
