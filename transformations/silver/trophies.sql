-- Group 4 | refresh: full replace
-- One row per trophy entry per team.
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE OR REPLACE TABLE {db}.silver.trophies AS
SELECT
    team_id,
    elem->>'$.league'   AS league,
    elem->>'$.country'  AS country,
    elem->>'$.season'   AS season,
    elem->>'$.place'    AS place,
    ingested_at
FROM {db}.bronze.api_football__trophies,
UNNEST(raw_json::JSON[]) AS t(elem);
