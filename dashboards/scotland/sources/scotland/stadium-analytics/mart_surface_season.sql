WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)  AS shots_on_goal,
        SUM(shots_total)      AS total_shots,
        SUM(passes_total)     AS total_passes,
        SUM(passes_accurate)  AS passes_accurate,
        SUM(crosses_total)    AS crosses_total,
        SUM(crosses_accurate) AS crosses_accurate
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
fouls_agg AS (
    SELECT match_sk, team_sk, SUM(fouls_committed) AS fouls_committed
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
)
SELECT
    d.season_scotland AS season,
    st.stadium_surface,
    COUNT(DISTINCT m.match_id)::int                                                                 AS matches,
    ROUND(SUM(f.goals_scored)::double / COUNT(DISTINCT m.match_id), 2)                             AS goals_per_match,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ts.team_side = 'Home' AND r.match_result = 'Win')
          / NULLIF(COUNT(*) FILTER (WHERE ts.team_side = 'Home'), 0), 1)                           AS home_win_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.match_result = 'Draw') / COUNT(*), 1)                   AS draw_pct,
    ROUND(100.0 * SUM(COALESCE(pa.passes_accurate, 0))
          / NULLIF(SUM(COALESCE(pa.total_passes, 0)), 0), 1)                                       AS pass_accuracy,
    ROUND(SUM(f.ball_possession_pct)::double / COUNT(DISTINCT m.match_id), 1)                      AS avg_possession,
    ROUND(SUM(COALESCE(pa.shots_on_goal, 0))::double / COUNT(DISTINCT m.match_id), 1)              AS shots_per_match,
    ROUND(SUM(f.yellow_cards)::double / COUNT(DISTINCT m.match_id), 2)                             AS yc_per_match,
    ROUND(SUM(COALESCE(fouls.fouls_committed, 0))::double / COUNT(DISTINCT m.match_id), 1)         AS fouls_per_match,
    ROUND(SUM(f.corner_kicks)::double / COUNT(DISTINCT m.match_id), 1)                             AS corners_per_match,
    ROUND(100.0 * SUM(f.goals_scored)
          / NULLIF(SUM(COALESCE(pa.total_shots, 0)), 0), 1)                                        AS shot_conversion,
    ROUND(100.0 * SUM(COALESCE(pa.crosses_accurate, 0))
          / NULLIF(SUM(COALESCE(pa.crosses_total, 0)), 0), 1)                                      AS cross_accuracy
FROM superligaen.gold.fct_team_matches   f
JOIN superligaen.gold.dim_date           d   ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match          m   ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk = f.match_result_sk
JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk   = f.team_side_sk
JOIN superligaen.gold.dim_stadium        st  ON st.stadium_sk     = f.stadium_sk
LEFT JOIN player_agg                     pa  ON pa.match_sk       = f.match_sk
                                           AND pa.team_sk         = f.team_sk
LEFT JOIN fouls_agg                      fouls ON fouls.match_sk  = f.match_sk
                                               AND fouls.team_sk  = f.team_sk
WHERE d.season_scotland >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
  AND st.stadium_surface IS NOT NULL AND st.stadium_surface != ''
  AND st.stadium_latitude  BETWEEN 54.5 AND 58.7
  AND st.stadium_longitude BETWEEN -8.0 AND -1.0
GROUP BY d.season_scotland, st.stadium_surface
ORDER BY d.season_scotland DESC,
    CASE
        WHEN st.stadium_surface ILIKE '%grass%' OR st.stadium_surface ILIKE '%natural%' THEN 1
        WHEN st.stadium_surface ILIKE '%artif%' OR st.stadium_surface ILIKE '%turf%'    THEN 2
        ELSE 3
    END
