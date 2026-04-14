-- Dimension: side
-- Static dimension describing whether a team played at home or away.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_side AS
SELECT  1 AS side_sk, 'Home'                  AS side
UNION ALL SELECT  2, 'Away'
UNION ALL SELECT -1, 'Unknown Side'
UNION ALL SELECT -2, 'Not Applicable Side';
