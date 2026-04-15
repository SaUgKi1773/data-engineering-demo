-- Dimension: team side
-- Static dimension describing whether a team played at home or away.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_team_side AS
SELECT  1 AS team_side_sk, 'Home'                        AS team_side
UNION ALL SELECT  2, 'Away'
UNION ALL SELECT -1, 'Unknown Team Side'
UNION ALL SELECT -2, 'Not Applicable Team Side';
