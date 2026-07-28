-- Game state at team-match grain, carrying the page's slice dimensions.
-- trailed / led mean behind / ahead at any point in the match, from the running
-- score on the event stream; ht_state comes from the half-time goals on the
-- team fact. The page aggregates (comeback wins, points from trailing, ...) at
-- query time. None of it needs the deep stats, so it works across all six
-- seasons.
WITH match_extremes AS (
    -- Deepest deficit each match reached, from either side's view
    SELECT
        match_sk,
        MAX(away_score_after_event - home_score_after_event) AS max_home_deficit,
        MAX(home_score_after_event - away_score_after_event) AS max_away_deficit
    FROM superligaen.gold.fct_match_events
    WHERE match_sk > 0
    GROUP BY match_sk
)
SELECT
    d.season_turkey                                      AS season,
    t.team_name,
    ot.opponent_team_name,
    m.match_round_number                                 AS round_order,
    ts.team_side,
    r.match_result                                       AS result,
    f.points_earned,
    CASE WHEN ts.team_side = 'Home'
         THEN COALESCE(me.max_home_deficit, 0)
         ELSE COALESCE(me.max_away_deficit, 0) END > 0   AS trailed,
    CASE WHEN ts.team_side = 'Home'
         THEN COALESCE(me.max_away_deficit, 0)
         ELSE COALESCE(me.max_home_deficit, 0) END > 0   AS led,
    -- NULL, not 'Behind', where the interval score was never recorded: a fixture
    -- whose provider published neither a half-time score nor a timeline. 29
    -- Süper Lig matches are in exactly that state, and letting the ELSE swallow
    -- them is how #482 happened.
    CASE
        WHEN f.goals_ht_scored IS NULL               THEN NULL
        WHEN f.goals_ht_scored > f.goals_ht_conceded THEN 'Ahead'
        WHEN f.goals_ht_scored = f.goals_ht_conceded THEN 'Level'
        ELSE 'Behind'
    END                                                  AS ht_state
FROM superligaen.gold.fct_team_matches f
JOIN superligaen.gold.dim_date          d  ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_team          t  ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team ot ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match         m  ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team_side     ts ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_match_result  r  ON r.match_result_sk   = f.match_result_sk
LEFT JOIN match_extremes                me ON me.match_sk         = f.match_sk
WHERE r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 173537)  -- Süper Lig only
  AND d.season_turkey IS NOT NULL
ORDER BY d.season_turkey DESC, t.team_name, round_order
