-- Game-state season summary: one row per season and team.
-- "Trailing/leading at any point" derives from the running score on the event
-- stream; half-time states come from fct_team_matches directly.
WITH match_extremes AS (
    -- Deepest deficit / biggest lead each match reached, from either side's view
    SELECT
        match_sk,
        MAX(away_score_after_event - home_score_after_event) AS max_home_deficit,
        MAX(home_score_after_event - away_score_after_event) AS max_away_deficit
    FROM superligaen.gold.fct_match_events
    WHERE match_sk > 0
    GROUP BY match_sk
),
team_matches AS (
    SELECT
        d.season_scotland AS season,
        t.team_name,
        t.team_logo,
        r.match_result,
        f.points_earned,
        CASE WHEN ts.team_side = 'Home'
             THEN COALESCE(me.max_home_deficit, 0)
             ELSE COALESCE(me.max_away_deficit, 0) END > 0 AS trailed,
        CASE WHEN ts.team_side = 'Home'
             THEN COALESCE(me.max_away_deficit, 0)
             ELSE COALESCE(me.max_home_deficit, 0) END > 0 AS led,
        f.goals_ht_scored < f.goals_ht_conceded AS ht_trailed
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date         d  ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_team         t  ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match_result r  ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_team_side    ts ON ts.team_side_sk   = f.team_side_sk
    LEFT JOIN match_extremes               me ON me.match_sk       = f.match_sk
    WHERE d.season_scotland >= '2020/21'
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
)
SELECT
    season,
    team_name,
    team_logo,
    COUNT(*)                                                        AS matches,
    -- Fighting back
    COUNT(*) FILTER (WHERE trailed)                                 AS matches_trailed,
    COUNT(*) FILTER (WHERE trailed AND match_result = 'Win')        AS comeback_wins,
    COUNT(*) FILTER (WHERE trailed AND match_result = 'Draw')       AS comeback_draws,
    COALESCE(SUM(points_earned) FILTER (WHERE trailed), 0)          AS points_from_trailing,
    COUNT(*) FILTER (WHERE ht_trailed AND match_result = 'Win')     AS ht_comeback_wins,
    -- Holding on
    COUNT(*) FILTER (WHERE led)                                     AS matches_led,
    COUNT(*) FILTER (WHERE led AND match_result = 'Loss')           AS leads_lost,
    COUNT(*) FILTER (WHERE led AND match_result = 'Draw')           AS leads_drawn,
    COALESCE(3 * COUNT(*) FILTER (WHERE led)
             - SUM(points_earned) FILTER (WHERE led), 0)            AS points_dropped_leading
FROM team_matches
GROUP BY season, team_name, team_logo
ORDER BY season DESC, points_from_trailing DESC
