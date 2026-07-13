-- Every scored prediction, one row per played match: what the model said,
-- what it favored, and what actually happened. Full transparency, no cherry-picking.
WITH base AS (
    SELECT
        d.date                                  AS match_date,
        d.season,
        m.match_round_number::INT               AS round_number,
        t.team_short_name                       AS home_team,
        ot.opponent_team_short_name             AS away_team,
        t.team_short_name || ' - ' || ot.opponent_team_short_name AS match_name,
        m.match_result                          AS score,
        ROUND(p.win_probability  * 100)::INT    AS home_pct,
        ROUND(p.draw_probability * 100)::INT    AS draw_pct,
        ROUND(p.loss_probability * 100)::INT    AS away_pct,
        CASE
            WHEN p.win_probability  >= p.draw_probability
             AND p.win_probability  >= p.loss_probability THEN t.team_short_name
            WHEN p.loss_probability >= p.draw_probability  THEN ot.opponent_team_short_name
            ELSE 'Draw'
        END AS model_pick,
        CASE r.match_result
            WHEN 'Win'  THEN t.team_short_name
            WHEN 'Loss' THEN ot.opponent_team_short_name
            ELSE 'Draw'
        END AS actual_result,
        (CASE
            WHEN p.win_probability  >= p.draw_probability
             AND p.win_probability  >= p.loss_probability THEN 'Win'
            WHEN p.loss_probability >= p.draw_probability  THEN 'Loss'
            ELSE 'Draw'
        END = r.match_result)                   AS hit
    FROM superligaen.gold.fct_match_predictions p
    JOIN superligaen.gold.fct_team_matches   f  ON f.match_sk         = p.match_sk
                                               AND f.team_side_sk     = p.team_side_sk
    JOIN superligaen.gold.dim_match_result   r  ON r.match_result_sk  = f.match_result_sk
    JOIN superligaen.gold.dim_match          m  ON m.match_sk         = p.match_sk
    JOIN superligaen.gold.dim_date           d  ON d.date_sk          = p.date_sk
    JOIN superligaen.gold.dim_team           t  ON t.team_sk          = p.team_sk
    JOIN superligaen.gold.dim_opponent_team  ot ON ot.opponent_team_sk = p.opponent_team_sk
    WHERE p.team_side_sk = 1
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
)
SELECT * FROM base
UNION ALL
-- sentinel row so parquet is never empty (filtered out in page queries via home_team IS NOT NULL)
SELECT date '1900-01-01', '0000-00', 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM base)
ORDER BY match_date DESC
