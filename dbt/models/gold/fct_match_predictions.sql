{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'team_side_sk']
    )
}}

-- Pre-match win/draw/loss probabilities at team-side grain: two rows per
-- fixture, each from that team's perspective, mirroring fct_team_matches.
-- Predictions freeze at kickoff in bronze, so past rows never change here.
WITH participants AS (
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
        s.kickoff_at,
        mt.team_id,
        mt.opponent_team_id,
        mt.location,
        CASE mt.location WHEN 'home' THEN s.home_win_prob  ELSE s.away_win_prob  END AS win_probability,
        s.draw_prob                                                                  AS draw_probability,
        CASE mt.location WHEN 'home' THEN s.away_win_prob  ELSE s.home_win_prob  END AS loss_probability,
        CASE mt.location WHEN 'home' THEN s.home_goals_exp ELSE s.away_goals_exp END AS expected_goals_scored,
        CASE mt.location WHEN 'home' THEN s.away_goals_exp ELSE s.home_goals_exp END AS expected_goals_conceded,
        s.model_version,
        s.predicted_at
    FROM {{ ref('match_predictions') }} s
    JOIN match_teams mt ON mt.fixture_id = s.match_id
)
SELECT
    COALESCE(dd.date_sk,            -1) AS date_sk,
    COALESCE(dteam.team_sk,         -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk, -1) AS opponent_team_sk,
    COALESCE(dl.league_sk,          -1) AS league_sk,
    COALESCE(dm.match_sk,           -1) AS match_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                 AS team_side_sk,
    src.win_probability,
    src.draw_probability,
    src.loss_probability,
    src.expected_goals_scored,
    src.expected_goals_conceded,
    ROUND(3 * src.win_probability + src.draw_probability, 4) AS expected_points,
    src.model_version,
    src.predicted_at
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd    ON dd.date               = src.kickoff_at::DATE
LEFT JOIN {{ ref('dim_team') }}          dteam ON dteam.team_id         = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp  ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}        dl    ON dl.league_id          = src.league_id
LEFT JOIN {{ ref('dim_match') }}         dm    ON dm.match_id           = src.match_id
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
