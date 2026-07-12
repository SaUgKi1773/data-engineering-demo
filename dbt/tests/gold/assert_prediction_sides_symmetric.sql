-- Every prediction event must produce exactly two team-side rows (home and
-- away), and they must mirror each other: the home side's win probability is
-- the away side's loss probability, draws match, and expected goals swap.
-- An asymmetry means the side pivot in fct_match_predictions is broken.
WITH sides AS (
    SELECT
        match_sk, prediction_model_sk, predicted_at,
        COUNT(*)                                                        AS side_rows,
        MAX(CASE WHEN team_side_sk = 1 THEN win_probability        END) AS home_win,
        MAX(CASE WHEN team_side_sk = 2 THEN loss_probability       END) AS away_loss,
        MAX(CASE WHEN team_side_sk = 1 THEN draw_probability       END) AS home_draw,
        MAX(CASE WHEN team_side_sk = 2 THEN draw_probability       END) AS away_draw,
        MAX(CASE WHEN team_side_sk = 1 THEN expected_goals_scored  END) AS home_xg,
        MAX(CASE WHEN team_side_sk = 2 THEN expected_goals_conceded END) AS away_xga
    FROM {{ ref('fct_match_predictions') }}
    WHERE match_sk > 0
    GROUP BY match_sk, prediction_model_sk, predicted_at
)
SELECT *
FROM sides
WHERE side_rows != 2
   OR ABS(home_win  - away_loss) > 0.0001
   OR ABS(home_draw - away_draw) > 0.0001
   OR ABS(home_xg   - away_xga)  > 0.0001
