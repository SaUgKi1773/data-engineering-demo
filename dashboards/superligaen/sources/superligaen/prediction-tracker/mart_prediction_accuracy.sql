-- Model vs. reality: every finished Superliga match that had a pre-kickoff
-- prediction (data science pipeline, issue #342), scored against the actual
-- result. One row per match, home perspective. The baseline_* columns hold the
-- league's long-run home/draw/away rates so the page can show whether the
-- model beats always-guessing base rates.
WITH latest_prediction AS (
    SELECT
        p.match_sk,
        dpm.prediction_model_version,
        p.predicted_at,
        p.win_probability   AS home_win_prob,
        p.draw_probability  AS draw_prob,
        p.loss_probability  AS away_win_prob
    FROM superligaen.gold.fct_match_predictions   p
    JOIN superligaen.gold.dim_prediction_model    dpm ON dpm.prediction_model_sk = p.prediction_model_sk
    WHERE p.team_side_sk = 1
      AND p.is_pre_kickoff
      AND p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
    QUALIFY ROW_NUMBER() OVER (PARTITION BY p.match_sk ORDER BY p.predicted_at DESC) = 1
),
results AS (
    SELECT
        f.match_sk,
        m.match_id,
        d.date                                                                                  AS match_date,
        d.season,
        m.match_round_number,
        m.match_round_name                                                                      AS round,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name END)                        AS home_team_short,
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name END)                        AS away_team_short,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_logo       END)                        AS home_team_logo,
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_logo       END)                        AS away_team_logo,
        MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_scored    END)                        AS home_goals,
        MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_scored    END)                        AS away_goals
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_date          d   ON d.date_sk          = f.date_sk
    JOIN superligaen.gold.dim_match         m   ON m.match_sk         = f.match_sk
    JOIN superligaen.gold.dim_team          t   ON t.team_sk          = f.team_sk
    JOIN superligaen.gold.dim_team_side     ts  ON ts.team_side_sk    = f.team_side_sk
    JOIN superligaen.gold.dim_match_result  r   ON r.match_result_sk  = f.match_result_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
    GROUP BY f.match_sk, m.match_id, d.date, d.season, m.match_round_number, m.match_round_name
),
baseline AS (
    -- long-run league base rates over all finished matches (build-time constant)
    SELECT
        AVG((home_goals > away_goals)::INT) AS baseline_home_prob,
        AVG((home_goals = away_goals)::INT) AS baseline_draw_prob,
        AVG((home_goals < away_goals)::INT) AS baseline_away_prob
    FROM results
),
outcomes AS (
    SELECT
        r.*,
        lp.prediction_model_version,
        lp.predicted_at,
        lp.home_win_prob,
        lp.draw_prob,
        lp.away_win_prob,
        b.baseline_home_prob,
        b.baseline_draw_prob,
        b.baseline_away_prob,
        CASE WHEN r.home_goals > r.away_goals THEN 'Home'
             WHEN r.home_goals = r.away_goals THEN 'Draw'
             ELSE                                  'Away' END                                   AS actual_outcome,
        CASE WHEN lp.home_win_prob >= lp.draw_prob AND lp.home_win_prob >= lp.away_win_prob THEN 'Home'
             WHEN lp.away_win_prob >= lp.draw_prob                                          THEN 'Away'
             ELSE                                                                                'Draw' END AS predicted_outcome,
        CASE WHEN b.baseline_home_prob >= b.baseline_draw_prob AND b.baseline_home_prob >= b.baseline_away_prob THEN 'Home'
             WHEN b.baseline_away_prob >= b.baseline_draw_prob                                                  THEN 'Away'
             ELSE                                                                                                    'Draw' END AS baseline_outcome
    FROM results r
    JOIN latest_prediction lp ON lp.match_sk = r.match_sk
    CROSS JOIN baseline b
),
scored AS (
    SELECT
        match_id, match_date, season, match_round_number, round,
        home_team_short, away_team_short, home_team_logo, away_team_logo,
        home_goals, away_goals,
        actual_outcome, predicted_outcome, baseline_outcome,
        (predicted_outcome = actual_outcome)                                                    AS is_correct,
        (baseline_outcome  = actual_outcome)                                                    AS baseline_is_correct,
        home_win_prob, draw_prob, away_win_prob,
        baseline_home_prob, baseline_draw_prob, baseline_away_prob,
        POWER(home_win_prob - (actual_outcome = 'Home')::INT, 2)
          + POWER(draw_prob     - (actual_outcome = 'Draw')::INT, 2)
          + POWER(away_win_prob - (actual_outcome = 'Away')::INT, 2)                            AS brier_score,
        POWER(baseline_home_prob - (actual_outcome = 'Home')::INT, 2)
          + POWER(baseline_draw_prob - (actual_outcome = 'Draw')::INT, 2)
          + POWER(baseline_away_prob - (actual_outcome = 'Away')::INT, 2)                       AS baseline_brier_score,
        prediction_model_version,
        predicted_at
    FROM outcomes
)
SELECT * FROM scored
UNION ALL
-- sentinel row so parquet is never empty (filtered out in page queries via match_id > 0)
SELECT -1, date '1900-01-01', '0000-00', 0, '----',
       NULL, NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM scored)
ORDER BY match_date DESC
