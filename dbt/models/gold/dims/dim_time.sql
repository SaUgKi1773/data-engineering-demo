SELECT
    hour::INTEGER AS time_sk,
    hour::INTEGER AS hour,
    CASE
        WHEN hour BETWEEN  5 AND 10 THEN 'Morning'
        WHEN hour BETWEEN 11 AND 15 THEN 'Noon'
        WHEN hour BETWEEN 16 AND 20 THEN 'Evening'
        ELSE 'Night'
    END           AS period_of_day
FROM generate_series(0, 23) t(hour)
UNION ALL SELECT -1, NULL, 'Unknown Period Of Day'
UNION ALL SELECT -2, NULL, 'Not Applicable Period Of Day'
