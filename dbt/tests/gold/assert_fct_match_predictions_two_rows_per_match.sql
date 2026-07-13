-- Every predicted match must have exactly 2 rows: home + away perspective.
-- One row means a missing participant leg; more means a broken incremental merge.
SELECT match_sk, count(*) AS row_count
FROM {{ ref('fct_match_predictions') }}
WHERE match_sk > 0
GROUP BY match_sk
HAVING count(*) != 2
