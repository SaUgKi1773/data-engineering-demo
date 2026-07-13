-- A prediction row is only trustworthy if its probabilities are possible:
-- each within [0, 1], the three summing to 1, and points_expected consistent
-- with them (3·win + 1·draw). Violations mean producer garbage reached gold
-- and must block the publish.
SELECT match_sk, team_side_sk, win_probability, draw_probability, loss_probability, points_expected
FROM {{ ref('fct_match_predictions') }}
WHERE win_probability  NOT BETWEEN 0 AND 1
   OR draw_probability NOT BETWEEN 0 AND 1
   OR loss_probability NOT BETWEEN 0 AND 1
   OR ABS(win_probability + draw_probability + loss_probability - 1) > 0.001
   OR ABS(points_expected - (3 * win_probability + draw_probability)) > 0.001
