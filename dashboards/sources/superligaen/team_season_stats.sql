WITH base AS (
    SELECT
        f.team_sk,
        f.opponent_team_sk,
        f.team_side_sk,
        m.season,
        m.match_round_type,
        f.match_result_sk,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned
    FROM superligaen.gold.fct_match_results f
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    WHERE f.match_result_sk IN (1, 2, 3)
),
team_stats AS (
    SELECT
        t.team_name,
        b.team_sk,
        b.season,
        COUNT(*)                                                    AS gp,
        SUM(CASE WHEN b.match_result_sk = 1 THEN 1 ELSE 0 END)    AS w,
        SUM(CASE WHEN b.match_result_sk = 2 THEN 1 ELSE 0 END)    AS d,
        SUM(CASE WHEN b.match_result_sk = 3 THEN 1 ELSE 0 END)    AS l,
        SUM(b.goals_scored)                                         AS gf,
        SUM(b.goals_conceded)                                       AS ga,
        SUM(b.goals_scored) - SUM(b.goals_conceded)                AS gd,
        SUM(COALESCE(b.points_earned, 0))                          AS pts,
        CASE
            WHEN MAX(CASE WHEN b.match_round_type = 'Championship' THEN 1 ELSE 0 END) = 1 THEN 'Championship Group'
            WHEN MAX(CASE WHEN b.match_round_type = 'Relegation'   THEN 1 ELSE 0 END) = 1 THEN 'Relegation Group'
            ELSE 'Regular Season'
        END                                                         AS round_group
    FROM base b
    JOIN superligaen.gold.dim_team t ON t.team_sk = b.team_sk
    GROUP BY t.team_name, b.team_sk, b.season
),
h2h_pairwise AS (
    -- head-to-head stats per (team, opponent, season) across all round types
    SELECT
        b.team_sk,
        b.opponent_team_sk,
        b.season,
        SUM(COALESCE(b.points_earned, 0))                                 AS h2h_pts,
        SUM(b.goals_scored) - SUM(b.goals_conceded)                       AS h2h_gd,
        SUM(b.goals_scored)                                                AS h2h_gf,
        SUM(CASE WHEN b.team_side_sk = 2 THEN b.goals_scored ELSE 0 END) AS h2h_away_gf
    FROM base b
    GROUP BY b.team_sk, b.opponent_team_sk, b.season
),
h2h_vs_tied AS (
    -- sum h2h stats only against teams tied on pts, gd, gf within same round_group
    SELECT
        s.team_sk,
        s.season,
        s.round_group,
        COALESCE(SUM(h.h2h_pts),     0) AS h2h_pts,
        COALESCE(SUM(h.h2h_gd),      0) AS h2h_gd,
        COALESCE(SUM(h.h2h_gf),      0) AS h2h_gf,
        COALESCE(SUM(h.h2h_away_gf), 0) AS h2h_away_gf
    FROM team_stats s
    JOIN team_stats tied ON
        tied.season      = s.season      AND
        tied.round_group = s.round_group AND
        tied.pts         = s.pts         AND
        tied.gd          = s.gd          AND
        tied.gf          = s.gf          AND
        tied.team_sk    != s.team_sk
    LEFT JOIN h2h_pairwise h ON
        h.team_sk          = s.team_sk       AND
        h.opponent_team_sk = tied.team_sk    AND
        h.season           = s.season
    GROUP BY s.team_sk, s.season, s.round_group
)
SELECT
    s.team_name,
    s.season,
    s.gp, s.w, s.d, s.l,
    s.gf, s.ga, s.gd, s.pts,
    s.round_group,
    COALESCE(h.h2h_pts,     0) AS h2h_pts,
    COALESCE(h.h2h_gd,      0) AS h2h_gd,
    COALESCE(h.h2h_gf,      0) AS h2h_gf,
    COALESCE(h.h2h_away_gf, 0) AS h2h_away_gf
FROM team_stats s
LEFT JOIN h2h_vs_tied h ON
    h.team_sk     = s.team_sk     AND
    h.season      = s.season      AND
    h.round_group = s.round_group
ORDER BY
    s.season DESC,
    s.round_group,
    s.pts          DESC,
    s.gd           DESC,
    s.gf           DESC,
    COALESCE(h.h2h_pts,     0) DESC,
    COALESCE(h.h2h_gd,      0) DESC,
    COALESCE(h.h2h_gf,      0) DESC,
    COALESCE(h.h2h_away_gf, 0) DESC
