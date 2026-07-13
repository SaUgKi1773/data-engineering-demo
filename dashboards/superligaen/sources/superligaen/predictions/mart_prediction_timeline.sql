-- Cumulative hit rate by kickoff date, model vs the always-home-win baseline.
-- Rates are pre-computed here so the browser does zero work.
WITH scored AS (
    SELECT
        d.date AS match_date,
        r.match_result,
        CASE
            WHEN p.win_probability  >= p.draw_probability
             AND p.win_probability  >= p.loss_probability THEN 'Win'
            WHEN p.loss_probability >= p.draw_probability  THEN 'Loss'
            ELSE 'Draw'
        END AS model_pick
    FROM superligaen.gold.fct_match_predictions p
    JOIN superligaen.gold.fct_team_matches  f ON f.match_sk        = p.match_sk
                                             AND f.team_side_sk    = p.team_side_sk
    JOIN superligaen.gold.dim_match_result  r ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_date          d ON d.date_sk         = p.date_sk
    WHERE p.team_side_sk = 1
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
),
daily AS (
    SELECT
        match_date,
        COUNT(*)                              AS matches,
        SUM((model_pick   = match_result)::INT) AS model_hits,
        SUM((match_result = 'Win')::INT)        AS baseline_hits
    FROM scored
    GROUP BY match_date
),
cumulative AS (
    SELECT
        match_date,
        SUM(matches) OVER w::INT                                          AS cum_matches,
        ROUND(SUM(model_hits)    OVER w * 100.0 / SUM(matches) OVER w, 1) AS model_hit_pct,
        ROUND(SUM(baseline_hits) OVER w * 100.0 / SUM(matches) OVER w, 1) AS baseline_hit_pct
    FROM daily
    WINDOW w AS (ORDER BY match_date)
)
SELECT * FROM cumulative
UNION ALL
-- sentinel row so parquet is never empty (filtered out in page queries via cum_matches > 0)
SELECT date '1900-01-01', 0, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM cumulative)
ORDER BY match_date ASC
