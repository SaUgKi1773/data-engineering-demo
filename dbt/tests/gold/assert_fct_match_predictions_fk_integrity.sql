-- Every prediction row must resolve its core dimension FKs to real rows
-- (not Unknown/-1). Predictions are only produced for fixtures already in the
-- warehouse, so a -1 here means the producer sent an unknown match/team/league
-- or an unregistered model_version — a contract breach, not missing data.
SELECT 'match_sk'            AS fk, match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE match_sk = -1
UNION ALL
SELECT 'team_sk',             match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE team_sk = -1
UNION ALL
SELECT 'opponent_team_sk',    match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE opponent_team_sk = -1
UNION ALL
SELECT 'league_sk',           match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE league_sk = -1
UNION ALL
SELECT 'date_sk',             match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE date_sk = -1
UNION ALL
SELECT 'prediction_model_sk', match_sk, predicted_at FROM {{ ref('fct_match_predictions') }}
WHERE prediction_model_sk = -1
