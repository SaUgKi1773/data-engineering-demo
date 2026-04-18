-- Dimension: match
-- One row per fixture. Captures round, season, and current match status.
-- SK is stable: new matches get the next available SK; existing matches keep theirs.
-- match_status, match_result, and match_short_name are updated on every run.
-- match_round_number: ROW_NUMBER per (season, league, team) ordered by kick_off from
--   fixture_statistics; MIN() across both teams gives one number per match.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_match (
    match_sk             INTEGER NOT NULL,
    match_id             INTEGER,
    season               INTEGER,
    season_name          VARCHAR,
    match_round_name     VARCHAR,
    match_round_type     VARCHAR,
    match_round_number   INTEGER,
    match_status         VARCHAR,
    match_name           VARCHAR,
    match_short_name     VARCHAR,
    match_result         VARCHAR
);

-- Add new columns to existing tables (idempotent)
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS season_name        VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_round_type   VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_round_number INTEGER;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_name         VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_short_name   VARCHAR;
ALTER TABLE {db}.gold.dim_match ADD COLUMN IF NOT EXISTS match_result       VARCHAR;

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_match
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Unknown Match',        'Unknown',       NULL::INTEGER, 'Unknown Match',        'Unknown Match',        'Unknown',        NULL::VARCHAR),
    (-2, NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Match', 'Not Applicable',NULL::INTEGER, 'Not Applicable Match', 'Not Applicable Match', 'Not Applicable', NULL::VARCHAR)
) t(match_sk, match_id, season, season_name, round_name, round_type, round_number, match_status, match_name, match_short_name, match_result)
WHERE t.match_sk NOT IN (SELECT match_sk FROM {db}.gold.dim_match);

-- Insert new matches not yet in the dim
INSERT INTO {db}.gold.dim_match
WITH team_round_base AS (
    SELECT fixture_id,
           ROW_NUMBER() OVER (
               PARTITION BY season, league_id, team_id
               ORDER BY kick_off
           ) AS round_number
    FROM {db}.silver.fixture_statistics
),
team_round AS (
    SELECT fixture_id, MIN(round_number) AS round_number
    FROM team_round_base
    GROUP BY fixture_id
)
SELECT
    (SELECT COALESCE(MAX(match_sk), 0) FROM {db}.gold.dim_match WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.fixture_id)                        AS match_sk,
    src.fixture_id                                                            AS match_id,
    src.season,
    src.season::VARCHAR || '/' || RIGHT((src.season + 1)::VARCHAR, 2)        AS season_name,
    src.league_round                                                          AS match_round_name,
    CASE SPLIT_PART(src.league_round, ' - ', 1)
        WHEN 'Championship Group' THEN 'Championship'
        WHEN 'Championship Round' THEN 'Championship'
        WHEN 'Relegation Group'   THEN 'Relegation'
        WHEN 'Relegation Round'   THEN 'Relegation'
        ELSE SPLIT_PART(src.league_round, ' - ', 1)
    END                                                                       AS match_round_type,
    tr.round_number                                                           AS match_round_number,
    src.status_long                                                           AS match_status,
    src.home_team_name || ' - ' || src.away_team_name                        AS match_name,
    COALESCE(ht.team_code, src.home_team_name) || ' - ' || COALESCE(awt.team_code, src.away_team_name) AS match_short_name,
    CASE
        WHEN src.status_short IN ('FT', 'AET', 'PEN')
        THEN src.goals_home::VARCHAR || ' - ' || src.goals_away::VARCHAR
    END                                                                       AS match_result
FROM {db}.silver.fixtures src
LEFT JOIN team_round tr ON tr.fixture_id = src.fixture_id
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) ht ON ht.team_id = src.home_team_id
LEFT JOIN (
    SELECT DISTINCT ON (team_id) team_id, team_code
    FROM {db}.silver.teams
    ORDER BY team_id, season DESC
) awt ON awt.team_id = src.away_team_id
WHERE src.fixture_id NOT IN (
    SELECT match_id FROM {db}.gold.dim_match WHERE match_id IS NOT NULL
);

-- Update mutable fields for existing matches
UPDATE {db}.gold.dim_match tgt
SET
    season_name        = ranked.season_name,
    match_round_type   = ranked.match_round_type,
    match_round_number = ranked.match_round_number,
    match_status       = ranked.status_long,
    match_name         = ranked.match_name,
    match_short_name   = ranked.match_short_name,
    match_result       = ranked.match_result
FROM (
    WITH team_round_base AS (
        SELECT fixture_id,
               ROW_NUMBER() OVER (
                   PARTITION BY season, league_id, team_id
                   ORDER BY kick_off
               ) AS round_number
        FROM {db}.silver.fixture_statistics
    ),
    team_round AS (
        SELECT fixture_id, MIN(round_number) AS round_number
        FROM team_round_base
        GROUP BY fixture_id
    )
    SELECT
        src.fixture_id,
        src.season::VARCHAR || '/' || RIGHT((src.season + 1)::VARCHAR, 2)     AS season_name,
        CASE SPLIT_PART(src.league_round, ' - ', 1)
            WHEN 'Championship Group' THEN 'Championship'
            WHEN 'Championship Round' THEN 'Championship'
            WHEN 'Relegation Group'   THEN 'Relegation'
            WHEN 'Relegation Round'   THEN 'Relegation'
            ELSE SPLIT_PART(src.league_round, ' - ', 1)
        END                                                                   AS match_round_type,
        tr.round_number                                                       AS match_round_number,
        src.status_long,
        src.home_team_name || ' - ' || src.away_team_name                    AS match_name,
        COALESCE(ht.team_code, src.home_team_name) || ' - ' || COALESCE(awt.team_code, src.away_team_name) AS match_short_name,
        CASE
            WHEN src.status_short IN ('FT', 'AET', 'PEN')
            THEN src.goals_home::VARCHAR || ' - ' || src.goals_away::VARCHAR
        END                                                                   AS match_result
    FROM {db}.silver.fixtures src
    LEFT JOIN team_round tr ON tr.fixture_id = src.fixture_id
    LEFT JOIN (
        SELECT DISTINCT ON (team_id) team_id, team_code
        FROM {db}.silver.teams
        ORDER BY team_id, season DESC
    ) ht ON ht.team_id = src.home_team_id
    LEFT JOIN (
        SELECT DISTINCT ON (team_id) team_id, team_code
        FROM {db}.silver.teams
        ORDER BY team_id, season DESC
    ) awt ON awt.team_id = src.away_team_id
) ranked
WHERE tgt.match_id = ranked.fixture_id;
