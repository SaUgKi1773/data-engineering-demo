WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_total)     AS total_shots,
        SUM(passes_total)    AS total_passes,
        SUM(passes_accurate) AS passes_accurate
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
per_match AS (
    SELECT
        d.season,
        f.team_sk,
        t.team_name,
        t.team_logo,
        MAX(dc.coach_name) OVER (PARTITION BY f.team_sk, d.season)  AS coach_name,
        m.match_id,
        r.match_result                          AS result,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        f.yellow_cards,
        f.red_cards,
        f.ball_possession_pct                   AS possession_pct,
        ts.team_side,
        COALESCE(pa.total_shots, 0)             AS total_shots,
        COALESCE(pa.total_passes, 0)            AS total_passes,
        COALESCE(pa.passes_accurate, 0)         AS passes_accurate,
        m.match_round_number,
        CASE
            WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Championship Group'
            WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Relegation Group'
            ELSE 'Regular Season'
        END                                     AS standings_type,
        SUM(f.points_earned) OVER (
            PARTITION BY f.team_sk, d.season
            ORDER BY m.match_round_number
        )                                       AS cumulative_pts
    FROM superligaen.gold.fct_team_matches    f
    JOIN superligaen.gold.dim_date            d   ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match           m   ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_team            t   ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk   = f.team_side_sk
    JOIN superligaen.gold.dim_coach           dc  ON dc.coach_sk       = f.coach_sk
    LEFT JOIN player_agg                      pa  ON pa.match_sk       = f.match_sk
                                               AND pa.team_sk          = f.team_sk
    WHERE d.season >= '2020/21'
),
season_agg AS (
    SELECT
        season,
        team_sk,
        MAX(team_name)                          AS team_name,
        MAX(team_logo)                          AS team_logo,
        MAX(coach_name)                         AS coach_name,
        COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')) AS matches,
        SUM(CASE WHEN result = 'Win'  THEN 1 ELSE 0 END) AS wins,
        SUM(CASE WHEN result = 'Draw' THEN 1 ELSE 0 END) AS draws,
        SUM(CASE WHEN result = 'Loss' THEN 1 ELSE 0 END) AS losses,
        SUM(goals_scored)   FILTER (WHERE result IN ('Win','Draw','Loss')) AS gf,
        SUM(goals_conceded) FILTER (WHERE result IN ('Win','Draw','Loss')) AS ga,
        SUM(points_earned)  FILTER (WHERE result IN ('Win','Draw','Loss')) AS pts,
        MAX(match_round_number) FILTER (WHERE result IN ('Win','Draw','Loss')) AS max_round,
        MAX(standings_type) AS standings_type,
        -- full-season rates
        ROUND(SUM(goals_scored)::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 2)                    AS goals_per_match,
        ROUND(SUM(goals_conceded)::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 2)                  AS conceded_per_match,
        ROUND(100.0 * SUM(passes_accurate) FILTER (WHERE result IN ('Win','Draw','Loss')) / NULLIF(SUM(total_passes) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 1) AS pass_accuracy,
        ROUND(SUM(possession_pct) FILTER (WHERE result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 1) AS avg_possession,
        ROUND(100.0 * SUM(goals_scored) FILTER (WHERE result IN ('Win','Draw','Loss')) / NULLIF(SUM(total_shots) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 1)     AS shot_conv,
        ROUND(SUM(yellow_cards)::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 2)                    AS yc_per_match,
        ROUND(100.0 * SUM(CASE WHEN result = 'Win' THEN 1 ELSE 0 END)::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE result IN ('Win','Draw','Loss')), 0), 1)     AS win_rate,
        SUM(red_cards)::int AS total_red_cards,
        -- home split
        COUNT(DISTINCT match_id) FILTER (WHERE team_side = 'Home' AND result IN ('Win','Draw','Loss'))  AS home_matches,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Win'  THEN 1 ELSE 0 END)   AS home_wins,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Draw' THEN 1 ELSE 0 END)   AS home_draws,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Loss' THEN 1 ELSE 0 END)   AS home_losses,
        SUM(CASE WHEN team_side = 'Home' AND result IN ('Win','Draw','Loss') THEN points_earned ELSE 0 END) AS home_pts,
        ROUND(SUM(goals_scored) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss')), 0), 2) AS home_goals_per_match,
        ROUND(SUM(goals_conceded) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss')), 0), 2) AS home_conceded_per_match,
        ROUND(SUM(possession_pct) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss')), 0), 1) AS home_avg_possession,
        ROUND(100.0 * SUM(passes_accurate) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss')) / NULLIF(SUM(total_passes) FILTER (WHERE team_side='Home' AND result IN ('Win','Draw','Loss')), 0), 1) AS home_pass_accuracy,
        -- away split
        COUNT(DISTINCT match_id) FILTER (WHERE team_side = 'Away' AND result IN ('Win','Draw','Loss'))  AS away_matches,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Win'  THEN 1 ELSE 0 END)   AS away_wins,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Draw' THEN 1 ELSE 0 END)   AS away_draws,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Loss' THEN 1 ELSE 0 END)   AS away_losses,
        SUM(CASE WHEN team_side = 'Away' AND result IN ('Win','Draw','Loss') THEN points_earned ELSE 0 END) AS away_pts,
        ROUND(SUM(goals_scored) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss')), 0), 2) AS away_goals_per_match,
        ROUND(SUM(goals_conceded) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss')), 0), 2) AS away_conceded_per_match,
        ROUND(SUM(possession_pct) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss'))::double / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss')), 0), 1) AS away_avg_possession,
        ROUND(100.0 * SUM(passes_accurate) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss')) / NULLIF(SUM(total_passes) FILTER (WHERE team_side='Away' AND result IN ('Win','Draw','Loss')), 0), 1) AS away_pass_accuracy
    FROM per_match
    GROUP BY season, team_sk
),
with_rank AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY season
            ORDER BY
                CASE standings_type
                    WHEN 'Championship Group' THEN 1
                    WHEN 'Relegation Group'   THEN 2
                    ELSE                           3
                END,
                pts DESC,
                (gf - ga) DESC,
                gf DESC
        ) AS season_rank
    FROM season_agg
),
avg_age_calc AS (
    SELECT
        d.season,
        f.team_sk,
        ROUND(AVG(CAST(LEFT(d.season, 4) AS INTEGER) - YEAR(p.player_birth_date)), 1) AS avg_age
    FROM (
        SELECT DISTINCT
            f.date_sk, f.team_sk, f.player_sk
        FROM superligaen.gold.fct_player_appearances f
        JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
        WHERE r.match_result IN ('Win', 'Draw', 'Loss')
    ) f
    JOIN superligaen.gold.dim_date   d ON d.date_sk   = f.date_sk
    JOIN superligaen.gold.dim_player p ON p.player_sk = f.player_sk
    WHERE d.season >= '2020/21'
      AND p.player_birth_date IS NOT NULL
    GROUP BY d.season, f.team_sk
)
SELECT
    r.season,
    r.team_name,
    r.team_logo,
    r.coach_name,
    r.matches,
    r.wins,
    r.draws,
    r.losses,
    r.gf,
    r.ga,
    r.gf - r.ga                             AS gd,
    r.pts,
    r.max_round,
    r.standings_type,
    r.season_rank,
    r.goals_per_match,
    r.conceded_per_match,
    r.pass_accuracy,
    r.avg_possession,
    r.shot_conv,
    r.yc_per_match,
    r.win_rate,
    r.total_red_cards,
    r.home_matches,
    r.home_wins,
    r.home_draws,
    r.home_losses,
    r.home_pts,
    r.home_goals_per_match,
    r.home_conceded_per_match,
    r.home_avg_possession,
    r.home_pass_accuracy,
    r.away_matches,
    r.away_wins,
    r.away_draws,
    r.away_losses,
    r.away_pts,
    r.away_goals_per_match,
    r.away_conceded_per_match,
    r.away_avg_possession,
    r.away_pass_accuracy,
    a.avg_age
FROM with_rank r
LEFT JOIN avg_age_calc a ON a.season = r.season AND a.team_sk = r.team_sk
