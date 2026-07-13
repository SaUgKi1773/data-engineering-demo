WITH base AS (
    SELECT
        m.match_id,
        ROUND(p.win_probability  * 100)::INT AS home_pct,
        ROUND(p.draw_probability * 100)::INT AS draw_pct,
        ROUND(p.loss_probability * 100)::INT AS away_pct,
        ROUND(p.predicted_goals_scored,   1)  AS predicted_home_goals,
        ROUND(p.predicted_goals_conceded, 1)  AS predicted_away_goals,
        p.model_version
    FROM superligaen.gold.fct_match_predictions p
    JOIN superligaen.gold.dim_match         m ON m.match_sk         = p.match_sk
    JOIN superligaen.gold.fct_team_matches  f ON f.match_sk         = p.match_sk
                                             AND f.team_side_sk     = p.team_side_sk
    JOIN superligaen.gold.dim_match_result  r ON r.match_result_sk  = f.match_result_sk
    WHERE p.team_side_sk = 1  -- home perspective carries the full match-level prediction
      AND r.match_result = 'Pending'
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
)
SELECT * FROM base
UNION ALL
-- sentinel row so parquet is never empty (pages join on match_id; -1 never matches)
SELECT -1, NULL, NULL, NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM base)
