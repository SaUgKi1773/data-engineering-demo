-- At most eleven starters per team per fixture.
-- More means a reissued lineup left its superseded rows behind: gold ranks a
-- pre-match starter above the bench row that replaced them, so the XI grows
-- past eleven and can field two goalkeepers.
-- Fewer is not asserted - Sportmonks ships the occasional ten-man lineup.
SELECT fixture_id, team_id, count(*) AS starter_rows
FROM {{ ref('fixture_lineups') }}
WHERE type_id = 11
GROUP BY fixture_id, team_id
HAVING count(*) > 11
