-- Event timing at team-match x 15-minute-bucket grain, carrying the same
-- slice dimensions as the page's filter bar. Every match contributes one row
-- per side and bucket: goals_for/cards/substitutions count the row's team,
-- goals_against counts the opponent. The page aggregates to buckets at query
-- time. Extra Time is excluded: league group-stage matches never reach it.
SELECT
    d.season,
    t.team_name,
    ot.opponent_team_name,
    m.match_round_number,
    m.match_round_type,
    ts.team_side,
    r.match_result                                          AS result,
    mm.minute_bucket,
    mm.minute_bucket_sort,
    COUNT(*) FILTER (WHERE et.event_group = 'Goal'         AND e.team_sk =  f.team_sk) AS goals_for,
    COUNT(*) FILTER (WHERE et.event_group = 'Goal'         AND e.team_sk != f.team_sk) AS goals_against,
    COUNT(*) FILTER (WHERE et.event_group = 'Card'         AND e.team_sk =  f.team_sk) AS cards,
    COUNT(*) FILTER (WHERE et.event_group = 'Substitution' AND e.team_sk =  f.team_sk) AS substitutions
FROM superligaen.gold.fct_team_matches f
JOIN superligaen.gold.fct_match_events e ON e.match_sk = f.match_sk
JOIN superligaen.gold.dim_date             d   ON d.date_sk              = f.date_sk
JOIN superligaen.gold.dim_team             t   ON t.team_sk              = f.team_sk
JOIN superligaen.gold.dim_opponent_team    ot  ON ot.opponent_team_sk    = f.opponent_team_sk
JOIN superligaen.gold.dim_match            m   ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_team_side        ts  ON ts.team_side_sk        = f.team_side_sk
JOIN superligaen.gold.dim_match_result     r   ON r.match_result_sk      = f.match_result_sk
JOIN superligaen.gold.dim_match_minute     mm  ON mm.match_minute_sk     = e.match_minute_sk
JOIN superligaen.gold.dim_match_event_type et  ON et.match_event_type_sk = e.match_event_type_sk
WHERE d.season >= '2020/21'
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND mm.match_minute_sk > 0
  AND mm.minute_bucket != 'Extra Time'
GROUP BY ALL
ORDER BY d.season DESC, t.team_name, m.match_round_number, mm.minute_bucket_sort
