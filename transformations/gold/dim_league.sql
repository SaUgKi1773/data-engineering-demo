-- Dimension: league
-- One row per league.
-- SK is stable: new leagues get the next available SK; existing leagues keep theirs.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_league (
    league_sk           INTEGER NOT NULL,
    league_id           INTEGER,
    league_name         VARCHAR,
    league_type         VARCHAR,
    league_logo         VARCHAR,
    league_country      VARCHAR,
    league_country_code VARCHAR,
    league_country_flag VARCHAR
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_league
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, 'Unknown League',        'Unknown League',        NULL::VARCHAR, 'Unknown League',        'Unknown League',        NULL::VARCHAR),
    (-2, NULL::INTEGER, 'Not Applicable League', 'Not Applicable League', NULL::VARCHAR, 'Not Applicable League', 'Not Applicable League', NULL::VARCHAR)
) t(league_sk, league_id, league_name, league_type, league_logo, league_country, league_country_code, league_country_flag)
WHERE t.league_sk NOT IN (SELECT league_sk FROM {db}.gold.dim_league);

-- Insert new leagues not yet in the dim
INSERT INTO {db}.gold.dim_league
SELECT
    (SELECT COALESCE(MAX(league_sk), 0) FROM {db}.gold.dim_league WHERE league_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.league_id) AS league_sk,
    src.league_id,
    src.league_name,
    src.league_type,
    src.league_logo,
    src.country_name AS league_country,
    src.country_code AS league_country_code,
    src.country_flag AS league_country_flag
FROM {db}.silver.leagues src
WHERE src.league_id NOT IN (
    SELECT league_id FROM {db}.gold.dim_league WHERE league_id IS NOT NULL
);

-- Update attributes for existing leagues
UPDATE {db}.gold.dim_league tgt
SET
    league_name         = src.league_name,
    league_type         = src.league_type,
    league_logo         = src.league_logo,
    league_country      = src.country_name,
    league_country_code = src.country_code,
    league_country_flag = src.country_flag
FROM {db}.silver.leagues src
WHERE tgt.league_id = src.league_id;
