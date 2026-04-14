-- Dimension: match result (from the perspective of the team row)
-- Static 4-row dimension. 'Pending' covers fixtures not yet played,
-- in progress, postponed, or cancelled.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_result AS
SELECT 1 AS result_sk, 'Win'     AS result
UNION ALL
SELECT 2, 'Draw'
UNION ALL
SELECT 3, 'Loss'
UNION ALL
SELECT 4, 'Pending';
