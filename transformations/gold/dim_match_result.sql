-- Dimension: match result (from the perspective of the team row)
-- Static dimension. Known status_short mappings:
--   Win/Draw/Loss  : FT, AET, PEN  (decided by goals comparison)
--   Pending        : NS, TBD, 1H, HT, 2H, ET, BT, P, LIVE
--   Not Applicable : PST, CANC, ABD, AWD, WO, SUSP, INT
--   Unknown        : any status not listed above (SK = -1)
-- Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_match_result AS
SELECT  1 AS match_result_sk, 'Win'                      AS match_result
UNION ALL SELECT  2, 'Draw'
UNION ALL SELECT  3, 'Loss'
UNION ALL SELECT  4, 'Pending'
UNION ALL SELECT -1, 'Unknown Match Result'
UNION ALL SELECT -2, 'Not Applicable Match Result';
