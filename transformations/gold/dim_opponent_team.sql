-- Role-playing dimension: opponent team
-- Alias of dim_team for the opponent role in fct_match_results.
-- Allows clean joins without aliasing dim_team twice in queries.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE VIEW {db}.gold.dim_opponent_team AS
SELECT
    team_sk           AS opponent_team_sk,
    team_id           AS opponent_team_id,
    team_name         AS opponent_team_name,
    team_code         AS opponent_team_code,
    team_country      AS opponent_team_country,
    team_founded_year AS opponent_team_founded_year,
    team_logo         AS opponent_team_logo
FROM {db}.gold.dim_team;
