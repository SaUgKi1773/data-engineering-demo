{{ config(severity='warn') }}
-- Goalkeeper goals_conceded summed per team-match must equal the team's
-- goals_conceded in fct_team_matches. Guards the goals_against_team event
-- derivation (issue #427: own-goal misattribution + excluded penalties).
-- Severity warn: ~34 team-matches have residual event-stream gaps (missing
-- or team-misattributed goal events in the source) that cannot be derived.
WITH gk_conceded AS (
    SELECT match_sk, team_sk, SUM(goals_conceded) AS gk_goals_conceded
    FROM {{ ref('fct_player_appearances') }}
    WHERE goals_conceded IS NOT NULL AND match_sk > 0
    GROUP BY match_sk, team_sk
)
SELECT
    g.match_sk,
    g.team_sk,
    g.gk_goals_conceded,
    t.goals_conceded AS team_goals_conceded
FROM gk_conceded g
JOIN {{ ref('fct_team_matches') }} t
    ON t.match_sk = g.match_sk AND t.team_sk = g.team_sk
WHERE g.gk_goals_conceded != t.goals_conceded
