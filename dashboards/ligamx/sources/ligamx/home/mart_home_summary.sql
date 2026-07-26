-- Headline numbers for the current Liga MX tournament.
--
-- "Current" is the tournament that is running now, which in Mexico changes
-- twice a year rather than once: Apertura from July, Clausura from January.
-- Everything below is scoped to the 17 regular rounds, since that is what the
-- table is made of.
WITH regular AS (
    SELECT
        d.season_mexico            AS tournament,
        d.is_current_season_mexico AS is_current,
        f.match_sk,
        f.team_sk,
        f.goals_scored,
        f.points_earned,
        f.yellow_cards,
        f.red_cards,
        f.expected_goals,
        m.match_round_number       AS round
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date  d ON d.date_sk  = f.date_sk
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND m.match_round_type = 'Regular Season'
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND d.season_mexico IS NOT NULL
)
SELECT
    tournament,
    is_current,
    COUNT(DISTINCT match_sk)                       AS matches_played,
    COUNT(DISTINCT team_sk)                        AS teams,
    MAX(round)                                     AS latest_round,
    SUM(goals_scored)                              AS goals,
    ROUND(SUM(goals_scored) * 1.0
          / NULLIF(COUNT(DISTINCT match_sk), 0), 2) AS goals_per_match,
    SUM(yellow_cards)                              AS yellow_cards,
    SUM(red_cards)                                 AS red_cards,
    -- xG is only carried from 2025 onwards; NULL rather than 0 where the
    -- provider never recorded it.
    ROUND(AVG(expected_goals), 2)                  AS avg_xg_per_team_match
FROM regular
GROUP BY 1, 2
