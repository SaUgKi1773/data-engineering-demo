-- A transfer always moves a player between two different clubs; the source and
-- destination team can never be the same. Both sides may legitimately be null
-- (counterparty club outside our scope), so only flag rows where both are set
-- and equal.
SELECT id, player_name, from_team_id, to_team_id
FROM {{ ref('transfers') }}
WHERE from_team_id IS NOT NULL
  AND to_team_id IS NOT NULL
  AND from_team_id = to_team_id
