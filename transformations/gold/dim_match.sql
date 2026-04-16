-- Dimension: match
-- One row per fixture. Captures round, season, and current match status.
-- SK is stable: new matches get the next available SK; existing matches keep theirs.
-- match_status, match_result, and match_short_name are updated on every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_match (
    match_sk           INTEGER NOT NULL,
    match_id           INTEGER,
    season             INTEGER,
    match_round_name   VARCHAR,
    match_round_number INTEGER,
    match_round_type   VARCHAR,
    match_status       VARCHAR,
    match_name         VARCHAR,
    match_short_name   VARCHAR,
    match_result       VARCHAR
);

-- Add new columns to existing tables (idempotent)
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_round_type  VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_name        VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_short_name  VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_result      VARCHAR;

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_match
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, NULL::INTEGER, 'Unknown Match',        NULL::INTEGER, 'Unknown',       'Unknown Match',        'Unknown Match',        'Unknown',        NULL::VARCHAR),
    (-2, NULL::INTEGER, NULL::INTEGER, 'Not Applicable Match', NULL::INTEGER, 'Not Applicable','Not Applicable Match', 'Not Applicable Match', 'Not Applicable', NULL::VARCHAR)
) t(match_sk, match_id, season, round_name, round_number, round_type, match_status, match_name, match_short_name, match_result)
WHERE t.match_sk NOT IN (SELECT match_sk FROM {db}.gold.dim_match);

-- Insert new matches not yet in the dim
INSERT INTO {db}.gold.dim_match
SELECT
    (SELECT COALESCE(MAX(match_sk), 0) FROM {db}.gold.dim_match WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.fixture_id)          AS match_sk,
    src.fixture_id                                              AS match_id,
    src.season,
    src.league_round                                            AS match_round_name,
    TRY_CAST(regexp_extract(src.league_round, '(\d+)$', 1) AS INTEGER) AS match_round_number,
    SPLIT_PART(src.league_round, ' - ', 1)                     AS match_round_type,
    src.status_long                                             AS match_status,
    src.home_team_name || ' - ' || src.away_team_name           AS match_name,
    COALESCE(ht.team_code, src.home_team_name) || ' - ' || COALESCE(at.team_code, src.away_team_name) AS match_short_name,
    CASE
        WHEN src.status_short IN ('FT', 'AET', 'PEN')
        THEN src.goals_home::VARCHAR || ' - ' || src.goals_away::VARCHAR
    END                                                         AS match_result
FROM {db}.silver.fixtures src
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) ht ON ht.team_id = src.home_team_id
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) at ON at.team_id = src.away_team_id
WHERE src.fixture_id NOT IN (
    SELECT match_id FROM {db}.gold.dim_match WHERE match_id IS NOT NULL
);

-- Update mutable fields for existing matches
UPDATE {db}.gold.dim_match tgt
SET
    match_status     = src.status_long,
    match_short_name = COALESCE(ht.team_code, src.home_team_name) || ' - ' || COALESCE(at.team_code, src.away_team_name),
    match_result     = CASE
                           WHEN src.status_short IN ('FT', 'AET', 'PEN')
                           THEN src.goals_home::VARCHAR || ' - ' || src.goals_away::VARCHAR
                       END
FROM {db}.silver.fixtures src
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) ht ON ht.team_id = src.home_team_id
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) at ON at.team_id = src.away_team_id
WHERE tgt.match_id = src.fixture_id;
