-- When-inside-the-match at match-clock grain: one row per displayed minute,
-- including each stoppage minute ('45+3' is its own row). minute_label is the
-- natural key; the period -> bucket -> minute rollup rides on top. Stoppage
-- offsets are sized from observed data (max legit 90+19, 45+11) with headroom;
-- glitch offsets beyond the range resolve to the Unknown row. The SK is
-- deterministic (minute * 100 + stoppage offset) like date_sk, so fact reloads
-- can never shuffle references.
WITH regulation AS (
    SELECT m AS minute_of_match, 0 AS stoppage_offset
    FROM generate_series(1, 120) t(m)
),
stoppage AS (
    -- Stoppage exists only at the end of a playing period
    SELECT b.base_minute AS minute_of_match, o.o AS stoppage_offset
    FROM (VALUES (45, 25), (90, 25), (105, 10), (120, 10)) b(base_minute, max_offset)
    JOIN generate_series(1, 25) o(o) ON o.o <= b.max_offset
),
minutes AS (
    SELECT
        minute_of_match,
        stoppage_offset,
        CASE
            WHEN minute_of_match <= 45 THEN 'First Half'
            WHEN minute_of_match <= 90 THEN 'Second Half'
            ELSE                            'Extra Time'
        END AS period_name,
        CASE
            WHEN stoppage_offset > 0 THEN minute_of_match || '+' || stoppage_offset
            ELSE                          minute_of_match::VARCHAR
        END AS minute_label
    FROM (SELECT * FROM regulation UNION ALL SELECT * FROM stoppage)
)
SELECT
    minute_of_match * 100 + stoppage_offset AS match_minute_sk,
    minute_label,
    period_name,
    minute_of_match,
    stoppage_offset,
    CASE WHEN stoppage_offset > 0 THEN 'Stoppage' ELSE 'Regulation' END AS minute_type,
    CASE
        WHEN period_name = 'Extra Time'  THEN 'Extra Time'
        WHEN stoppage_offset > 0
             AND minute_of_match = 45    THEN '45+'
        WHEN stoppage_offset > 0
             AND minute_of_match = 90    THEN '90+'
        WHEN minute_of_match <= 15       THEN '0-15'
        WHEN minute_of_match <= 30       THEN '16-30'
        WHEN minute_of_match <= 45       THEN '31-45'
        WHEN minute_of_match <= 60       THEN '46-60'
        WHEN minute_of_match <= 75       THEN '61-75'
        ELSE                                  '76-90'
    END AS minute_bucket,
    CASE
        WHEN period_name = 'Extra Time'  THEN 9
        WHEN stoppage_offset > 0
             AND minute_of_match = 45    THEN 4
        WHEN stoppage_offset > 0
             AND minute_of_match = 90    THEN 8
        WHEN minute_of_match <= 15       THEN 1
        WHEN minute_of_match <= 30       THEN 2
        WHEN minute_of_match <= 45       THEN 3
        WHEN minute_of_match <= 60       THEN 5
        WHEN minute_of_match <= 75       THEN 6
        ELSE                                  7
    END AS minute_bucket_sort
FROM minutes
UNION ALL SELECT -1, 'Unknown Minute',        'Unknown Period',        NULL, NULL, 'Unknown Minute Type',        'Unknown Minute Bucket',        NULL
UNION ALL SELECT -2, 'Not Applicable Minute', 'Not Applicable Period', NULL, NULL, 'Not Applicable Minute Type', 'Not Applicable Minute Bucket', NULL
