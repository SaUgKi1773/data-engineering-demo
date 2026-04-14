-- Dimension: round
-- One row per league/season/round combination, plus sentinel rows.
-- round_number is extracted from the trailing integer in round_name
-- (e.g. 'Regular Season - 12' -> 12).
-- league_id is retained as a natural key for fact table lookups only —
-- it is not a reporting attribute (use dim_league via the fact's league_sk
-- for league descriptors).
-- SK assigned by league_id/season/round_number sort — gold is always
-- fully rebuilt so SK values are consistent within a single pipeline run.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_round AS
WITH rounds_raw AS (
    SELECT
        league_id,
        season,
        round_name,
        TRY_CAST(regexp_extract(round_name, '(\d+)$', 1) AS INTEGER) AS round_number
    FROM {db}.silver.rounds
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY league_id, season, round_number NULLS LAST, round_name
    )::INTEGER AS round_sk,
    league_id,
    season,
    round_name,
    round_number
FROM rounds_raw
UNION ALL
SELECT -1, NULL, NULL, 'Unknown Round',        NULL
UNION ALL
SELECT -2, NULL, NULL, 'Not Applicable Round', NULL;
