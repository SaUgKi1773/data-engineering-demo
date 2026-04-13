-- Group 4 | refresh: full replace
-- One row per sidelined entry per team.
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE OR REPLACE TABLE {db}.silver.sidelined AS
SELECT
    team_id,
    (elem->>'$.player.id')::INTEGER   AS player_id,
    elem->>'$.player.name'            AS player_name,
    elem->>'$.description'            AS description,
    elem->>'$.type'                   AS sidelined_type,
    ingested_at
FROM {db}.bronze.api_football__sidelined,
UNNEST(raw_json::JSON[]) AS t(elem);
