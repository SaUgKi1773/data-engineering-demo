-- Dimension: time (hour-level granularity)
-- 24 rows — one per hour of the day. Full replace every run.
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE OR REPLACE TABLE {db}.gold.dim_time AS
SELECT
    hour::INTEGER AS time_sk,
    hour::INTEGER AS hour,
    CASE
        WHEN hour BETWEEN 6  AND 11 THEN 'Morning'
        WHEN hour BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN hour BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END           AS period_of_day
FROM generate_series(0, 23) t(hour)
UNION ALL
SELECT -1, NULL, 'Unknown Time'
UNION ALL
SELECT -2, NULL, 'Not Applicable Time';
