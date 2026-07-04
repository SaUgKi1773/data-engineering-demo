-- One row per calendar date. Season boundaries differ per country (and a
-- future league may even run calendar-year seasons), so each league in scope
-- gets its own season columns via its own range join — a date matches at most
-- one season per league, which guarantees uniqueness by construction.
--
-- `season` / `is_current_season` are the Danish columns under their original
-- names: the Superliga marts and the discussion generator query them, and
-- they predate multi-league support. New (Scottish) marts must use the
-- country-suffixed columns.
WITH season_ranges AS (
    SELECT
        league_id,
        name          AS season,
        starting_at::DATE AS season_start,
        ending_at::DATE   AS season_end,
        is_current
    FROM {{ ref('seasons') }}
)
SELECT
    (year(d) * 10000 + month(d) * 100 + day(d))::INTEGER AS date_sk,
    d::DATE                                               AS date,
    year(d)::INTEGER                                      AS year,
    'Q' || quarter(d)::INTEGER                            AS quarter,
    month(d)::INTEGER                                     AS month,
    monthname(d)                                          AS month_name,
    weekofyear(d)::INTEGER                                AS week_number,
    isodow(d)::INTEGER                                    AS day_of_week,
    dayname(d)                                            AS day_name,
    CASE WHEN isodow(d) IN (6, 7) THEN 'Weekend' ELSE 'Weekday' END AS is_weekend,
    LEFT(dk.season, 4) || '/' || RIGHT(dk.season, 2)      AS season,
    COALESCE(dk.is_current, false)                        AS is_current_season,
    LEFT(dk.season, 4) || '/' || RIGHT(dk.season, 2)      AS season_denmark,
    COALESCE(dk.is_current, false)                        AS is_current_season_denmark,
    LEFT(sco.season, 4) || '/' || RIGHT(sco.season, 2)    AS season_scotland,
    COALESCE(sco.is_current, false)                       AS is_current_season_scotland
FROM generate_series(DATE '2010-01-01', DATE '2030-12-31', INTERVAL '1 day') t(d)
LEFT JOIN season_ranges dk  ON d::DATE BETWEEN dk.season_start  AND dk.season_end  AND dk.league_id  = 271
LEFT JOIN season_ranges sco ON d::DATE BETWEEN sco.season_start AND sco.season_end AND sco.league_id = 501
