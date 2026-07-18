-- Game state at team-match grain, carrying the page's slice dimensions.
-- trailed/led mean behind/ahead at any point in the match, derived from the
-- running score on the event stream; ht_trailed comes from half-time scores.
-- The page aggregates (comeback wins, points from trailing, ...) at query time.
WITH match_extremes AS (
    -- Deepest deficit / biggest lead each match reached, from either side's view
    SELECT
        match_sk,
        MAX(away_score_after_event - home_score_after_event) AS max_home_deficit,
        MAX(home_score_after_event - away_score_after_event) AS max_away_deficit
    FROM superligaen.gold.fct_match_events
    WHERE match_sk > 0
    GROUP BY match_sk
)
SELECT
    d.season_scotland AS season,
    t.team_name,
    ot.opponent_team_name,
    m.match_round_number,
    m.match_round_type,
    ts.team_side,
    r.match_result                                       AS result,
    f.points_earned,
    CASE WHEN ts.team_side = 'Home'
         THEN COALESCE(me.max_home_deficit, 0)
         ELSE COALESCE(me.max_away_deficit, 0) END > 0   AS trailed,
    CASE WHEN ts.team_side = 'Home'
         THEN COALESCE(me.max_away_deficit, 0)
         ELSE COALESCE(me.max_home_deficit, 0) END > 0   AS led,
    CASE
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
WHERE d.season_scotland >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
ORDER BY d.season_scotland DESC, t.team_name, m.match_round_number
