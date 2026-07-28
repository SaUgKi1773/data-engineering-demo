-- One row per (team, season): the season totals, home/away splits and
-- table position behind the Season Overview block on Team Intelligence.
--
-- `season_rank` is ranked exactly as the standings page ranks its table —
-- points, then the mini-table between clubs level on points, then overall goal
-- difference — so the two pages never disagree about where a club finished.
--
-- No coach and no squad age: the Highlightly feed publishes neither a coach
-- per match nor any player-level data to take birth dates from.
WITH per_match AS (
    SELECT
        d.season_turkey                         AS season,
        f.team_sk,
        f.opponent_team_sk,
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
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 173537)  -- Süper Lig only
      AND d.season_turkey IS NOT NULL
),
season_agg AS (
    SELECT
        season,
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
    GROUP BY season, team_sk
),
-- The Süper Lig separates clubs level on points by the mini-table between just
-- those clubs, so each club is re-aggregated over its matches against
-- opponents on its own points total. Same rule, same shape as the standings
-- page; see mart_standings.
head_to_head AS (
    SELECT
        pm.season,
        pm.team_sk,
        SUM(pm.points_earned)                          AS h2h_pts,
        SUM(pm.goals_scored) - SUM(pm.goals_conceded)  AS h2h_gd
    FROM per_match pm
    JOIN season_agg mine ON mine.season  = pm.season
                        AND mine.team_sk = pm.team_sk
    JOIN season_agg tied ON tied.season  = pm.season
                        AND tied.team_sk = pm.opponent_team_sk
                        AND tied.pts     = mine.pts
    GROUP BY pm.season, pm.team_sk
)
SELECT
    s.season,
    s.team_name,
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
    ROW_NUMBER() OVER (
        PARTITION BY s.season
        ORDER BY s.pts DESC,
                 COALESCE(h.h2h_pts, 0) DESC,
                 COALESCE(h.h2h_gd, 0) DESC,
                 (s.gf - s.ga) DESC,
                 s.gf DESC,
                 s.team_name
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
FROM season_agg s
LEFT JOIN head_to_head h ON h.season = s.season AND h.team_sk = s.team_sk
