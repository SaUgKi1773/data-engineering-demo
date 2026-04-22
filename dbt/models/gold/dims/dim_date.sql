{{
    config(
        materialized='table',
        schema='gold'
    )
}}

WITH seasons_raw AS (
    SELECT
        (s->>'year')::INTEGER AS season_year,
        (s->>'start')::DATE   AS season_start,
        (s->>'end')::DATE     AS season_end
    FROM {{ ref('leagues') }},
         UNNEST(seasons::JSON[]) AS t(s)
    WHERE league_id = 119
),
season_ranges AS (
    SELECT
        season_year::VARCHAR || '/' || RIGHT((season_year + 1)::VARCHAR, 2) AS season,
        -- boundary_start: one day after the midpoint of the gap with the previous season;
        -- first season uses its own start (no prior gap to split)
        COALESCE(
            (LAG(season_end) OVER (ORDER BY season_year)
             + ((season_start - LAG(season_end) OVER (ORDER BY season_year)) / 2
                * INTERVAL '1 day') + INTERVAL '1 day')::DATE,
            season_start
        ) AS boundary_start,
        -- boundary_end: midpoint of the gap with the next season (inclusive);
        -- last season uses its own end (no following gap to split yet)
        COALESCE(
            (season_end
             + ((LEAD(season_start) OVER (ORDER BY season_year) - season_end) / 2
                * INTERVAL '1 day'))::DATE,
            season_end
        ) AS boundary_end
    FROM seasons_raw
)
SELECT
    strftime('%Y%m%d', d)::INTEGER           AS date_sk,
    d::DATE                                  AS date,
    EXTRACT(year    FROM d)::INTEGER         AS year,
    'Q' || EXTRACT(quarter FROM d)::INTEGER  AS quarter,
    EXTRACT(month   FROM d)::INTEGER         AS month,
    monthname(d)                             AS month_name,
    weekofyear(d)::INTEGER                   AS week_number,
    isodow(d)::INTEGER                       AS day_of_week,
    dayname(d)                               AS day_name,
    CASE WHEN isodow(d) IN (6, 7) THEN 'Yes' ELSE 'No' END AS is_weekend,
    sr.season
FROM generate_series(DATE '2020-01-01', DATE '2030-12-31', INTERVAL '1 day') t(d)
LEFT JOIN season_ranges sr ON d::DATE BETWEEN sr.boundary_start AND sr.boundary_end
