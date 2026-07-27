-- One row per (team, tournament): the season totals, home/away splits and
-- table position behind the Season Overview block on Team Intelligence.
--
-- Regular rounds only. A Liga MX table is complete at 17 games and the
-- liguilla awards no points, so including knockout ties would add matches to
-- every total while leaving points untouched — a team's "matches played" would
-- stop agreeing with its points, and `season_rank` would stop agreeing with
-- the table on the standings page. Liguilla ties are still reachable elsewhere
-- on this page, through the match log and the goal-timing charts.
--
-- No coach and no squad age: Liga MX publishes neither a coach per match nor
-- any player-level data to take birth dates from.
WITH per_match AS (
    SELECT
        d.season_mexico                         AS tournament,
        f.team_sk,
        t.team_name,
        t.team_logo,
        m.match_id,
        r.match_result                          AS result,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        f.yellow_cards,
        f.red_cards,
        f.ball_possession_pct                   AS possession_pct,
        ts.team_side,
        m.match_round_number,
        CASE WHEN f.shots_on_target IS NULL
              AND f.shots_off_target IS NULL
              AND f.shots_blocked IS NULL THEN NULL
             ELSE COALESCE(f.shots_on_target,  0)
                + COALESCE(f.shots_off_target, 0)
                + COALESCE(f.shots_blocked,    0)
        END                                     AS total_shots,
        f.passes_total                          AS total_passes,
        f.passes_successful                     AS passes_accurate
    FROM superligaen.gold.fct_team_matches    f
    JOIN superligaen.gold.dim_date            d   ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match           m   ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_team            t   ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk   = f.team_side_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND m.match_round_type = 'Regular Season'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
      AND d.season_mexico IS NOT NULL
),
season_agg AS (
    SELECT
        tournament,
        team_sk,
        MAX(team_name)                                   AS team_name,
        MAX(team_logo)                                   AS team_logo,
        COUNT(DISTINCT match_id)                         AS matches,
        SUM(CASE WHEN result = 'Win'  THEN 1 ELSE 0 END) AS wins,
        SUM(CASE WHEN result = 'Draw' THEN 1 ELSE 0 END) AS draws,
        SUM(CASE WHEN result = 'Loss' THEN 1 ELSE 0 END) AS losses,
        SUM(goals_scored)                                AS gf,
        SUM(goals_conceded)                              AS ga,
        SUM(points_earned)                               AS pts,
        MAX(match_round_number)                          AS max_round,
        ROUND(SUM(goals_scored)::double   / NULLIF(COUNT(DISTINCT match_id), 0), 2)          AS goals_per_match,
        ROUND(SUM(goals_conceded)::double / NULLIF(COUNT(DISTINCT match_id), 0), 2)          AS conceded_per_match,
        ROUND(100.0 * SUM(passes_accurate) / NULLIF(SUM(total_passes), 0), 1)                AS pass_accuracy,
        ROUND(SUM(possession_pct)::double / NULLIF(COUNT(DISTINCT match_id), 0), 1)          AS avg_possession,
        ROUND(100.0 * SUM(goals_scored) / NULLIF(SUM(total_shots), 0), 1)                    AS shot_conv,
        ROUND(SUM(yellow_cards)::double / NULLIF(COUNT(DISTINCT match_id), 0), 2)            AS yc_per_match,
        ROUND(100.0 * SUM(CASE WHEN result = 'Win' THEN 1 ELSE 0 END)::double
              / NULLIF(COUNT(DISTINCT match_id), 0), 1)                                      AS win_rate,
        SUM(red_cards)::int                                                                  AS total_red_cards,
        -- home split
        COUNT(DISTINCT match_id) FILTER (WHERE team_side = 'Home')                           AS home_matches,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Win'  THEN 1 ELSE 0 END)               AS home_wins,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Draw' THEN 1 ELSE 0 END)               AS home_draws,
        SUM(CASE WHEN team_side = 'Home' AND result = 'Loss' THEN 1 ELSE 0 END)               AS home_losses,
        SUM(CASE WHEN team_side = 'Home' THEN points_earned ELSE 0 END)                       AS home_pts,
        ROUND(SUM(goals_scored)   FILTER (WHERE team_side='Home')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home'), 0), 2)      AS home_goals_per_match,
        ROUND(SUM(goals_conceded) FILTER (WHERE team_side='Home')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home'), 0), 2)      AS home_conceded_per_match,
        ROUND(SUM(possession_pct) FILTER (WHERE team_side='Home')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Home'), 0), 1)      AS home_avg_possession,
        ROUND(100.0 * SUM(passes_accurate) FILTER (WHERE team_side='Home')
              / NULLIF(SUM(total_passes) FILTER (WHERE team_side='Home'), 0), 1)             AS home_pass_accuracy,
        -- away split
        COUNT(DISTINCT match_id) FILTER (WHERE team_side = 'Away')                           AS away_matches,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Win'  THEN 1 ELSE 0 END)               AS away_wins,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Draw' THEN 1 ELSE 0 END)               AS away_draws,
        SUM(CASE WHEN team_side = 'Away' AND result = 'Loss' THEN 1 ELSE 0 END)               AS away_losses,
        SUM(CASE WHEN team_side = 'Away' THEN points_earned ELSE 0 END)                       AS away_pts,
        ROUND(SUM(goals_scored)   FILTER (WHERE team_side='Away')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away'), 0), 2)      AS away_goals_per_match,
        ROUND(SUM(goals_conceded) FILTER (WHERE team_side='Away')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away'), 0), 2)      AS away_conceded_per_match,
        ROUND(SUM(possession_pct) FILTER (WHERE team_side='Away')::double
              / NULLIF(COUNT(DISTINCT match_id) FILTER (WHERE team_side='Away'), 0), 1)      AS away_avg_possession,
        ROUND(100.0 * SUM(passes_accurate) FILTER (WHERE team_side='Away')
              / NULLIF(SUM(total_passes) FILTER (WHERE team_side='Away'), 0), 1)             AS away_pass_accuracy
    FROM per_match
    GROUP BY tournament, team_sk
)
SELECT
    tournament,
    team_name,
    team_logo,
    matches,
    wins,
    draws,
    losses,
    gf,
    ga,
    gf - ga AS gd,
    pts,
    max_round,
    -- Table position by the same tiebreak the standings page uses: points,
    -- then goal difference, then goals for.
    ROW_NUMBER() OVER (
        PARTITION BY tournament
        ORDER BY pts DESC, (gf - ga) DESC, gf DESC, team_name
    ) AS season_rank,
    goals_per_match,
    conceded_per_match,
    pass_accuracy,
    avg_possession,
    shot_conv,
    yc_per_match,
    win_rate,
    total_red_cards,
    home_matches,
    home_wins,
    home_draws,
    home_losses,
    home_pts,
    home_goals_per_match,
    home_conceded_per_match,
    home_avg_possession,
    home_pass_accuracy,
    away_matches,
    away_wins,
    away_draws,
    away_losses,
    away_pts,
    away_goals_per_match,
    away_conceded_per_match,
    away_avg_possession,
    away_pass_accuracy
FROM season_agg
