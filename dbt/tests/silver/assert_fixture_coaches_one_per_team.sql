-- At most one match-day coach per team per fixture.
-- More means a coach change left the outgoing coach behind, which fans out
-- every gold fact joining coaches on (fixture_id, team_id).
SELECT fixture_id, team_id, count(*) AS coach_count
FROM {{ ref('fixture_coaches') }}
GROUP BY fixture_id, team_id
HAVING count(*) > 1
