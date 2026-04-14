-- Dimension: team
-- One row per team. Most recent season's attributes used. Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_team AS
SELECT DISTINCT ON (team_id)
    team_id      AS team_sk,
    team_id,
    team_name,
    team_code,
    team_country,
    team_founded,
    team_logo
FROM {db}.silver.teams
ORDER BY team_id, season DESC;
