WITH base AS (
    SELECT
        f.team_sk,
        f.opponent_team_sk,
        f.team_side_sk,
        f.match_result_sk,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned
    FROM superligaen.gold.fct_match_results f
    JOIN superligaen.gold.dim_match        m ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE m.season = (SELECT max(season) FROM superligaen.gold.dim_match WHERE season IS NOT NULL)
      AND r.match_result IN ('Win', 'Draw', 'Loss')
),
team_stats AS (
    SELECT
        t.team_name,
        b.team_sk,
        SUM(COALESCE(b.points_earned, 0))           AS pts,
        SUM(b.goals_scored) - SUM(b.goals_conceded) AS gd,
        SUM(b.goals_scored)                          AS gf
    FROM base b
    JOIN superligaen.gold.dim_team t ON t.team_sk = b.team_sk
    GROUP BY t.team_name, b.team_sk
),
h2h_pairwise AS (
    SELECT
        b.team_sk,
        b.opponent_team_sk,
        SUM(COALESCE(b.points_earned, 0))                                 AS h2h_pts,
        SUM(b.goals_scored) - SUM(b.goals_conceded)                       AS h2h_gd,
        SUM(b.goals_scored)                                                AS h2h_gf,
        SUM(CASE WHEN b.team_side_sk = 2 THEN b.goals_scored ELSE 0 END) AS h2h_away_gf
    FROM base b
    GROUP BY b.team_sk, b.opponent_team_sk
),
h2h_vs_tied AS (
    SELECT
        s.team_sk,
        COALESCE(SUM(h.h2h_pts),     0) AS h2h_pts,
        COALESCE(SUM(h.h2h_gd),      0) AS h2h_gd,
        COALESCE(SUM(h.h2h_gf),      0) AS h2h_gf,
        COALESCE(SUM(h.h2h_away_gf), 0) AS h2h_away_gf
    FROM team_stats s
    JOIN team_stats tied ON
        tied.pts     = s.pts     AND
        tied.gd      = s.gd      AND
        tied.gf      = s.gf      AND
        tied.team_sk != s.team_sk
    LEFT JOIN h2h_pairwise h ON
        h.team_sk          = s.team_sk    AND
        h.opponent_team_sk = tied.team_sk
    GROUP BY s.team_sk
)
SELECT
    s.team_name,
    s.pts::integer AS pts
FROM team_stats s
LEFT JOIN h2h_vs_tied h ON h.team_sk = s.team_sk
ORDER BY
    s.pts                      DESC,
    s.gd                       DESC,
    s.gf                       DESC,
    COALESCE(h.h2h_pts,     0) DESC,
    COALESCE(h.h2h_gd,      0) DESC,
    COALESCE(h.h2h_gf,      0) DESC,
    COALESCE(h.h2h_away_gf, 0) DESC
LIMIT 1
