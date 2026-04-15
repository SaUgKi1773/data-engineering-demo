-- Dimension: match
-- One row per fixture. Captures round, season, and current match status.
-- SK is stable: new matches get the next available SK; existing matches keep theirs.
-- match_status is updated on every run as fixtures progress (e.g. NS -> FT).
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_match (
    match_sk          INTEGER NOT NULL,
    match_id          INTEGER,
    season            INTEGER,
    match_round_name  VARCHAR,
    match_round_number INTEGER,
    match_status      VARCHAR
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_match
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, NULL::INTEGER, 'Unknown Match',        NULL::INTEGER, 'Unknown Match'),
    (-2, NULL::INTEGER, NULL::INTEGER, 'Not Applicable Match', NULL::INTEGER, 'Not Applicable Match')
) t(match_sk, match_id, season, round_name, round_number, match_status)
WHERE t.match_sk NOT IN (SELECT match_sk FROM {db}.gold.dim_match);

-- Insert new matches not yet in the dim
INSERT INTO {db}.gold.dim_match
SELECT
    (SELECT COALESCE(MAX(match_sk), 0) FROM {db}.gold.dim_match WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.fixture_id) AS match_sk,
    src.fixture_id                                     AS match_id,
    src.season,
    src.league_round                                   AS match_round_name,
    TRY_CAST(regexp_extract(src.league_round, '(\d+)$', 1) AS INTEGER) AS match_round_number,
    src.status_short                                   AS match_status
FROM {db}.silver.fixtures src
WHERE src.fixture_id NOT IN (
    SELECT match_id FROM {db}.gold.dim_match WHERE match_id IS NOT NULL
);

-- Update match_status for existing matches (changes as fixtures are played)
UPDATE {db}.gold.dim_match tgt
SET match_status = src.status_short
FROM {db}.silver.fixtures src
WHERE tgt.match_id = src.fixture_id;
