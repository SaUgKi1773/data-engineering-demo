-- Dimension: team
-- One row per team. Attributes reflect most recent season.
-- SK is stable: new teams get the next available SK; existing teams keep theirs.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_team (
    team_sk           INTEGER NOT NULL,
    team_id           INTEGER,
    team_name         VARCHAR,
    team_code         VARCHAR,
    team_country      VARCHAR,
    team_founded_year INTEGER,
    team_logo         VARCHAR
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_team
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, 'Unknown Team',        'Unknown Team',        'Unknown Team',        NULL::INTEGER, NULL::VARCHAR),
    (-2, NULL::INTEGER, 'Not Applicable Team', 'Not Applicable Team', 'Not Applicable Team', NULL::INTEGER, NULL::VARCHAR)
) t(team_sk, team_id, team_name, team_code, team_country, team_founded_year, team_logo)
WHERE t.team_sk NOT IN (SELECT team_sk FROM {db}.gold.dim_team);

-- Insert new teams not yet in the dim
INSERT INTO {db}.gold.dim_team
SELECT
    (SELECT COALESCE(MAX(team_sk), 0) FROM {db}.gold.dim_team WHERE team_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.team_id) AS team_sk,
    src.team_id,
    src.team_name,
    src.team_code,
    src.team_country,
    src.team_founded  AS team_founded_year,
    src.team_logo
FROM (
    SELECT DISTINCT ON (team_id)
        team_id, team_name, team_code, team_country, team_founded, team_logo
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) src
WHERE src.team_id NOT IN (
    SELECT team_id FROM {db}.gold.dim_team WHERE team_id IS NOT NULL
);

-- Update attributes for existing teams
UPDATE {db}.gold.dim_team tgt
SET
    team_name         = src.team_name,
    team_code         = src.team_code,
    team_country      = src.team_country,
    team_founded_year = src.team_founded,
    team_logo         = src.team_logo
FROM (
    SELECT DISTINCT ON (team_id)
        team_id, team_name, team_code, team_country, team_founded, team_logo
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) src
WHERE tgt.team_id = src.team_id;
