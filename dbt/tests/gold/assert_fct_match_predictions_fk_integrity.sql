-- Every prediction must resolve to real dimension rows (not Unknown/-1).
-- An unresolved FK means the producer predicted a fixture the warehouse does
-- not know, or a dimension join broke — either way the prediction would
-- otherwise vanish or mislead silently in reporting.
SELECT 'date_sk'          AS fk, match_sk FROM {{ ref('fct_match_predictions') }}
WHERE date_sk = -1
UNION ALL
SELECT 'team_sk',          match_sk FROM {{ ref('fct_match_predictions') }}
WHERE team_sk = -1
UNION ALL
SELECT 'opponent_team_sk', match_sk FROM {{ ref('fct_match_predictions') }}
WHERE opponent_team_sk = -1
UNION ALL
SELECT 'league_sk',        match_sk FROM {{ ref('fct_match_predictions') }}
WHERE league_sk = -1
UNION ALL
SELECT 'match_sk',         match_sk FROM {{ ref('fct_match_predictions') }}
WHERE match_sk = -1
