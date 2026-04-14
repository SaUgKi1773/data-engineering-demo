-- Dimension: match role
-- Static 2-row dimension describing whether a team played at home or away.
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_match_role AS
SELECT  1 AS match_role_sk, 'Home'           AS match_role
UNION ALL SELECT  2, 'Away'
UNION ALL SELECT -1, 'Unknown Role'
UNION ALL SELECT -2, 'Not Applicable Role';
