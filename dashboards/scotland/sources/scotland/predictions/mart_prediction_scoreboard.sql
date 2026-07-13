-- One-row scoreboard for the predictions tracker. Aggregates over zero scored
-- matches still yield exactly one row (count 0, NULL rates), so the page can
-- render an honest empty state before the first predicted match is played.
WITH scored AS (
    SELECT
        p.win_probability  AS home_p,
        p.draw_probability AS draw_p,
        p.loss_probability AS away_p,
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
    WHERE p.team_side_sk = 1
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
),
pending AS (
    SELECT COUNT(*) AS n, MIN(d.date) AS first_kickoff
    FROM superligaen.gold.fct_match_predictions p
    JOIN superligaen.gold.fct_team_matches  f ON f.match_sk        = p.match_sk
                                             AND f.team_side_sk    = p.team_side_sk
    JOIN superligaen.gold.dim_match_result  r ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_date          d ON d.date_sk         = p.date_sk
    WHERE p.team_side_sk = 1
      AND r.match_result = 'Pending'
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
)
SELECT
    COUNT(*)::INT                                                 AS matches_scored,
    COALESCE(SUM((model_pick = match_result)::INT), 0)::INT       AS model_hits,
    ROUND(AVG((model_pick = match_result)::INT) * 100, 1)         AS model_hit_pct,
    COALESCE(SUM((match_result = 'Win')::INT), 0)::INT            AS baseline_hits,
    ROUND(AVG((match_result = 'Win')::INT) * 100, 1)              AS baseline_hit_pct,
    ROUND(AVG(CASE match_result
                  WHEN 'Win'  THEN home_p
                  WHEN 'Draw' THEN draw_p
                  ELSE             away_p
              END) * 100, 1)                                      AS avg_prob_on_result_pct,
    (SELECT n FROM pending)                                       AS pending_predictions,
    (SELECT strftime(first_kickoff, '%d %B %Y') FROM pending)     AS first_kickoff
FROM scored
