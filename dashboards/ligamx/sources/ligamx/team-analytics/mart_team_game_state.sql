-- Game state at team-match grain, carrying the page's slice dimensions.
-- trailed / led mean behind / ahead at any point in the match, and ht_state is
-- the score at the interval. Both come from the running score on the event
-- stream. The page aggregates (comeback wins, points from trailing, ...) at
-- query time. None of it needs the deep stats, so it works across all thirteen
-- tournaments.
--
-- ht_state is reconstructed here rather than read from goals_ht_scored /
-- goals_ht_conceded on the team fact, which are a hard 0 for every Liga MX
-- match ever played — the Mexican feed does not publish a half-time score and
-- the value lands as zero rather than NULL. Reading it made every match "Level
-- at HT", collapsing the Half-Time vs Full-Time chart onto a single bar.
-- Taking the running score after the last first-half goal instead gives the
-- real split (43% level, 28% ahead, 28% behind across all tournaments).
WITH half_time AS (
    -- Score at the interval: the running score carried by the last goal of the
    -- first half. A match with no first-half goal has no row here and is 0-0,
    -- which the COALESCE below handles.
    SELECT
        e.match_sk,
        MAX_BY(e.home_score_after_event,
               mm.minute_of_match * 100 + COALESCE(mm.stoppage_offset, 0)) AS ht_home,
        MAX_BY(e.away_score_after_event,
               mm.minute_of_match * 100 + COALESCE(mm.stoppage_offset, 0)) AS ht_away
    FROM superligaen.gold.fct_match_events      e
    JOIN superligaen.gold.dim_match_minute      mm ON mm.match_minute_sk     = e.match_minute_sk
    JOIN superligaen.gold.dim_match_event_type  et ON et.match_event_type_sk = e.match_event_type_sk
    WHERE e.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND et.event_group = 'Goal'
      AND mm.period_name = 'First Half'
    GROUP BY e.match_sk
),
match_extremes AS (
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
    d.season_mexico                                      AS tournament,
    t.team_name,
    ot.opponent_team_name,
    m.match_round_type,
    CASE m.match_round_type
        WHEN 'Regular Season'  THEN m.match_round_number
        WHEN 'Reclasificación' THEN 18
        WHEN 'Play-offs'       THEN 19
        WHEN 'Quarter-finals'  THEN 20
        WHEN 'Semi-finals'     THEN 21
        WHEN 'Final'           THEN 22
    END                                                  AS round_order,
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
        WHEN COALESCE(CASE WHEN ts.team_side = 'Home' THEN ht.ht_home ELSE ht.ht_away END, 0)
           > COALESCE(CASE WHEN ts.team_side = 'Home' THEN ht.ht_away ELSE ht.ht_home END, 0) THEN 'Ahead'
        WHEN COALESCE(CASE WHEN ts.team_side = 'Home' THEN ht.ht_home ELSE ht.ht_away END, 0)
           = COALESCE(CASE WHEN ts.team_side = 'Home' THEN ht.ht_away ELSE ht.ht_home END, 0) THEN 'Level'
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
LEFT JOIN half_time                     ht ON ht.match_sk         = f.match_sk
WHERE r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
  AND d.season_mexico IS NOT NULL
ORDER BY d.season_mexico DESC, t.team_name, round_order
