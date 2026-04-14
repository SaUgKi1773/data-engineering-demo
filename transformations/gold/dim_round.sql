-- Dimension: round
-- One row per league/season/round combination, plus an 'Unknown' sentinel
-- (round_sk = 0). round_number is extracted from the trailing integer in
-- round_name (e.g. 'Regular Season - 12' -> 12).
-- SK assigned by league/season/round_number sort — gold is always fully
-- rebuilt so SK values are consistent within a single pipeline run.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_round AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY league_id, season, round_number NULLS LAST, round_name
    )::INTEGER                                                       AS round_sk,
    league_id,
    season,
    round_name,
    TRY_CAST(regexp_extract(round_name, '(\d+)$', 1) AS INTEGER)    AS round_number
FROM {db}.silver.rounds
UNION ALL
SELECT -1, NULL, NULL, 'Unknown',        NULL
UNION ALL
SELECT -2, NULL, NULL, 'Not Applicable', NULL;
