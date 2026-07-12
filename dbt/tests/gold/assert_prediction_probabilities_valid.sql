-- Data contract with the data science pipeline (issue #342): every prediction
-- row must carry probabilities in [0, 1] that sum to 1, and non-negative
-- expected goals. A violation means the producer broke the contract — fail
-- loudly before the marts are built.
SELECT match_sk, team_side_sk, prediction_model_sk, predicted_at,
       win_probability, draw_probability, loss_probability,
       expected_goals_scored, expected_goals_conceded
FROM {{ ref('fct_match_predictions') }}
WHERE win_probability  NOT BETWEEN 0 AND 1
   OR draw_probability NOT BETWEEN 0 AND 1
   OR loss_probability NOT BETWEEN 0 AND 1
   OR ABS(win_probability + draw_probability + loss_probability - 1) > 0.001
   OR expected_goals_scored   < 0
   OR expected_goals_conceded < 0
