SELECT
    m.season,
    m.match_round_number                                       AS round,
    t.team_name,
    SUM(f.points_earned) OVER (
        PARTITION BY t.team_name, m.season
        ORDER BY m.match_round_number
    )                                                          AS cumulative_points,
    SUM(f.goals_scored - f.goals_conceded) OVER (
        PARTITION BY t.team_name, m.season
        ORDER BY m.match_round_number
    )                                                          AS cumulative_gd,
    SUM(f.goals_scored) OVER (
        PARTITION BY t.team_name, m.season
        ORDER BY m.match_round_number
    )                                                          AS cumulative_gf
FROM superligaen_dev.gold.fct_match_results f
JOIN superligaen_dev.gold.dim_match        m   ON m.match_sk        = f.match_sk
JOIN superligaen_dev.gold.dim_team         t   ON t.team_sk         = f.team_sk
JOIN superligaen_dev.gold.dim_match_result r   ON r.match_result_sk = f.match_result_sk
WHERE r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.match_result_sk > 0
ORDER BY m.season, t.team_name, m.match_round_number
