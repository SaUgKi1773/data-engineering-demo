-- Dimension: match round
-- One row per league/season/round combination.
-- round_number is extracted from the trailing integer in round_name (e.g. 'Regular Season - 12' -> 12).
-- league_id is retained as a natural key for fact table lookups only —
-- it is not a reporting attribute (use dim_league via the fact's league_sk for league descriptors).
-- SK is stable: new rounds get the next available SK; existing rounds keep theirs.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.dim_match_round (
    match_round_sk INTEGER NOT NULL,
    league_id      INTEGER,
    season         INTEGER,
    round_name     VARCHAR,
    round_number   INTEGER
);

-- Sentinels (idempotent)
INSERT INTO {db}.gold.dim_match_round
SELECT * FROM (VALUES
    (-1, NULL::INTEGER, NULL::INTEGER, 'Unknown Match Round',        NULL::INTEGER),
    (-2, NULL::INTEGER, NULL::INTEGER, 'Not Applicable Match Round', NULL::INTEGER)
) t(match_round_sk, league_id, season, round_name, round_number)
WHERE t.match_round_sk NOT IN (SELECT match_round_sk FROM {db}.gold.dim_match_round);

-- Insert new rounds not yet in the dim
INSERT INTO {db}.gold.dim_match_round
SELECT
    (SELECT COALESCE(MAX(match_round_sk), 0) FROM {db}.gold.dim_match_round WHERE match_round_sk > 0)
        + ROW_NUMBER() OVER (
            ORDER BY src.league_id, src.season, src.round_number NULLS LAST, src.round_name
        ) AS match_round_sk,
    src.league_id,
    src.season,
    src.round_name,
    src.round_number
FROM (
    SELECT
        league_id,
        season,
        round_name,
        TRY_CAST(regexp_extract(round_name, '(\d+)$', 1) AS INTEGER) AS round_number
    FROM {db}.silver.rounds
) src
WHERE NOT EXISTS (
    SELECT 1 FROM {db}.gold.dim_match_round tgt
    WHERE tgt.league_id  = src.league_id
      AND tgt.season     = src.season
      AND tgt.round_name = src.round_name
);

-- Update round_number for existing rows (in case extraction logic changes)
UPDATE {db}.gold.dim_match_round tgt
SET round_number = src.round_number
FROM (
    SELECT
        league_id,
        season,
        round_name,
        TRY_CAST(regexp_extract(round_name, '(\d+)$', 1) AS INTEGER) AS round_number
    FROM {db}.silver.rounds
) src
WHERE tgt.league_id  = src.league_id
  AND tgt.season     = src.season
  AND tgt.round_name = src.round_name;
