-- For completed matches (result is Win/Draw/Loss), core dimension FKs must resolve
-- to real rows (not Unknown/-1). team_sk, opponent_team_sk, match_sk, and
-- stadium_sk falling back to -1 indicates a broken join that would corrupt reporting.
SELECT 'team_sk'          AS fk, match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND team_sk = -1
UNION ALL
SELECT 'opponent_team_sk', match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND opponent_team_sk = -1
UNION ALL
SELECT 'match_sk',         match_sk FROM {{ ref('fct_team_matches') }}
WHERE match_result_sk IN (1, 2, 3) AND match_sk = -1
UNION ALL
-- stadium_sk resolving to Unknown is only a defect when the source actually
-- recorded a venue. Highlightly publishes a ground for roughly a third of its
-- fixtures, so asserting a stadium on every finished match would be asserting
-- one provider's data completeness, not referential integrity. This checks the
-- join instead: a venue was named, yet no dimension member was found.
SELECT 'stadium_sk',       f.match_sk
FROM {{ ref('fct_team_matches') }} f
JOIN {{ ref('dim_match') }} dm ON dm.match_sk = f.match_sk
JOIN {{ ref('fixtures') }} fx ON fx.id = dm.match_id AND fx._source = dm._source
WHERE f.match_result_sk IN (1, 2, 3)
  AND f.stadium_sk = -1
  AND fx.venue_name IS NOT NULL
