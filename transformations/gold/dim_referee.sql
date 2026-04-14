-- Dimension: referee
-- One row per distinct referee derived from silver.fixtures, plus an
-- 'Unknown' sentinel (referee_sk = 0) for fixtures with no referee.
-- SK assigned by alphabetical sort — gold is always fully rebuilt so
-- SK values are consistent within a single pipeline run.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_referee AS
SELECT
    ROW_NUMBER() OVER (ORDER BY referee_name)::INTEGER AS referee_sk,
    referee_name
FROM (
    SELECT DISTINCT referee AS referee_name
    FROM {db}.silver.fixtures
    WHERE referee IS NOT NULL AND referee <> ''
)
UNION ALL
SELECT -1, 'Unknown Referee'
UNION ALL
SELECT -2, 'Not Applicable Referee';
