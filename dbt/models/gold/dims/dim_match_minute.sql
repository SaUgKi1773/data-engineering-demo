-- When-inside-the-match at (period, minute, minute type) grain, with the
-- period -> bucket -> minute rollup. Stoppage time is its own grain member
-- because a 45+3 event belongs to the '45+' bucket, not '31-45', and the
-- half cannot be derived from the minute alone at the boundaries. The SK is
-- deterministic (minute * 10 + 1 for stoppage) like date_sk, so fact reloads
-- can never shuffle references.
WITH regulation AS (
    SELECT
        m               AS minute_of_match,
        CASE
            WHEN m <= 45 THEN 'First Half'
            WHEN m <= 90 THEN 'Second Half'
            ELSE              'Extra Time'
        END             AS period_name,
        'Regulation'    AS minute_type
    FROM generate_series(1, 120) t(m)
),
stoppage AS (
    -- Stoppage exists only at the end of a playing period
    SELECT minute_of_match, period_name, 'Stoppage' AS minute_type
    FROM (VALUES
        ( 45, 'First Half'),
        ( 90, 'Second Half'),
        (105, 'Extra Time'),
        (120, 'Extra Time')
    ) t(minute_of_match, period_name)
),
minutes AS (
    SELECT * FROM regulation
    UNION ALL
    SELECT * FROM stoppage
)
SELECT
    minute_of_match * 10
        + CASE minute_type WHEN 'Stoppage' THEN 1 ELSE 0 END AS match_minute_sk,
    period_name,
    minute_of_match,
    minute_type,
    CASE minute_type
        WHEN 'Stoppage' THEN minute_of_match || '+'
        ELSE                 minute_of_match::VARCHAR
    END AS minute_label,
    CASE
        WHEN period_name = 'Extra Time'   THEN 'Extra Time'
        WHEN minute_type = 'Stoppage'
             AND minute_of_match = 45     THEN '45+'
        WHEN minute_type = 'Stoppage'
             AND minute_of_match = 90     THEN '90+'
        WHEN minute_of_match <= 15        THEN '0-15'
        WHEN minute_of_match <= 30        THEN '16-30'
        WHEN minute_of_match <= 45        THEN '31-45'
        WHEN minute_of_match <= 60        THEN '46-60'
        WHEN minute_of_match <= 75        THEN '61-75'
        ELSE                                   '76-90'
    END AS minute_bucket,
    CASE
        WHEN period_name = 'Extra Time'   THEN 9
        WHEN minute_type = 'Stoppage'
             AND minute_of_match = 45     THEN 4
        WHEN minute_type = 'Stoppage'
             AND minute_of_match = 90     THEN 8
        WHEN minute_of_match <= 15        THEN 1
        WHEN minute_of_match <= 30        THEN 2
        WHEN minute_of_match <= 45        THEN 3
        WHEN minute_of_match <= 60        THEN 5
        WHEN minute_of_match <= 75        THEN 6
        ELSE                                   7
    END AS minute_bucket_sort
FROM minutes
UNION ALL SELECT -1, 'Unknown Period',        NULL, 'Unknown Minute Type',        'Unknown Minute',        'Unknown Minute Bucket',        NULL
UNION ALL SELECT -2, 'Not Applicable Period', NULL, 'Not Applicable Minute Type', 'Not Applicable Minute', 'Not Applicable Minute Bucket', NULL
