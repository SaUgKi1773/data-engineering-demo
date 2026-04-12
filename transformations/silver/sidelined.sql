-- Group 4 | refresh: full replace
-- One row per sidelined entry per team (aggregated from coach-level fetches).
SELECT
    team_id,
    (elem->>'$.player.id')::INTEGER   AS player_id,
    elem->>'$.player.name'            AS player_name,
    elem->>'$.description'            AS description,
    elem->>'$.type'                   AS sidelined_type,
    ingested_at
FROM {db}.bronze.api_football__sidelined,
UNNEST(raw_json::JSON[]) AS t(elem)
