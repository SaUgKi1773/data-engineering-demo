-- Dimension: team
-- One row per team. Most recent season's attributes used. Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_team AS
SELECT
    ROW_NUMBER() OVER (ORDER BY team_id)::INTEGER AS team_sk,
    team_id,
    team_name,
    team_code,
    team_country,
    team_founded,
    team_logo
FROM (
    SELECT DISTINCT ON (team_id)
        team_id, team_name, team_code, team_country, team_founded, team_logo
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
)
UNION ALL
SELECT -1, NULL, 'Unknown Team',        NULL, NULL, NULL, NULL
UNION ALL
SELECT -2, NULL, 'Not Applicable Team', NULL, NULL, NULL, NULL;
