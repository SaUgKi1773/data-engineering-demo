WITH base AS (
    SELECT
        m.match_id,
        d.date                                                                                  AS match_date,
        d.season,
        m.match_round_number,
        m.match_round_name                                                                      AS round,
        m.kick_off_time,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name       END)                        AS home_team,
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name       END)                        AS away_team,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name END)                        AS home_team_short,
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name END)                        AS away_team_short,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name END) || ' - ' ||
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name END)                        AS match_short_name,
        CASE WHEN st.stadium_name LIKE '%Unknown%' OR st.stadium_name LIKE '%Applicable%'
             THEN 'TBD' ELSE st.stadium_name END                                               AS stadium,
        ref.referee_common_name                                                                 AS referee,
        MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_logo END)                                AS home_team_logo,
        MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_logo END)                                AS away_team_logo
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_date          d   ON d.date_sk          = f.date_sk
    JOIN superligaen.gold.dim_match         m   ON m.match_sk         = f.match_sk
    JOIN superligaen.gold.dim_team          t   ON t.team_sk          = f.team_sk
    JOIN superligaen.gold.dim_team_side     ts  ON ts.team_side_sk    = f.team_side_sk
    JOIN superligaen.gold.dim_match_result  r   ON r.match_result_sk  = f.match_result_sk
    JOIN superligaen.gold.dim_stadium       st  ON st.stadium_sk      = f.stadium_sk
    JOIN superligaen.gold.dim_referee       ref ON ref.referee_sk     = f.referee_sk
    WHERE r.match_result = 'Pending'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
    GROUP BY m.match_id, d.date, d.season, m.match_round_number, m.match_round_name,
             m.kick_off_time, st.stadium_name, ref.referee_common_name
),
-- latest pre-kickoff prediction per fixture, home perspective (data science pipeline, issue #342)
latest_prediction AS (
    SELECT
        m.match_id,
        p.win_probability                                                                       AS home_win_prob,
        p.draw_probability                                                                      AS draw_prob,
        p.loss_probability                                                                      AS away_win_prob,
        p.expected_goals_scored                                                                 AS home_expected_goals,
        p.expected_goals_conceded                                                               AS away_expected_goals,
        p.predicted_at
    FROM superligaen.gold.fct_match_predictions p
    JOIN superligaen.gold.dim_match             m ON m.match_sk = p.match_sk
    WHERE p.team_side_sk = 1
      AND p.is_pre_kickoff
    QUALIFY ROW_NUMBER() OVER (PARTITION BY p.match_sk ORDER BY p.predicted_at DESC) = 1
),
enriched AS (
    SELECT b.*, lp.home_win_prob, lp.draw_prob, lp.away_win_prob,
           lp.home_expected_goals, lp.away_expected_goals, lp.predicted_at
    FROM base b
    LEFT JOIN latest_prediction lp ON lp.match_id = b.match_id
)
SELECT * FROM enriched
UNION ALL
-- sentinel row so parquet is never empty (filtered out in page queries via home_team IS NOT NULL)
SELECT -1, date '1900-01-01', '0000-00', 0, '----', '00:00',
       NULL, NULL, NULL, NULL, NULL, 'TBD', NULL, NULL, NULL,
       NULL, NULL, NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM enriched)
ORDER BY match_date ASC, kick_off_time ASC
