-- Dimension: round
-- One row per league/season/round combination, plus sentinel rows.
-- round_number is extracted from the trailing integer in round_name
-- (e.g. 'Regular Season - 12' -> 12).
-- league_name/league_type are denormalized from silver.leagues.
-- SK assigned by league_name/season/round_number sort — gold is always
-- fully rebuilt so SK values are consistent within a single pipeline run.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_round AS
WITH rounds_raw AS (
    SELECT
        r.season,
        r.round_name,
        TRY_CAST(regexp_extract(r.round_name, '(\d+)$', 1) AS INTEGER) AS round_number,
        l.league_name,
        l.league_type
    FROM {db}.silver.rounds r
    JOIN {db}.silver.leagues l ON l.league_id = r.league_id
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY league_name, season, round_number NULLS LAST, round_name
    )::INTEGER AS round_sk,
    league_name,
    league_type,
    season,
    round_name,
    round_number
FROM rounds_raw
UNION ALL
SELECT -1, 'Unknown Round',        NULL, NULL, NULL, NULL
UNION ALL
SELECT -2, 'Not Applicable Round', NULL, NULL, NULL, NULL;
