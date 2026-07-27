-- Event timing at team-match x 15-minute-bucket grain, carrying the same slice
-- dimensions as mart_match_facts so the page's full filter bar applies. Each
-- event counts once, on its acting team's row; the page aggregates to buckets
-- at query time.
--
-- Extra Time is excluded. Unlike the Danish league it is not hypothetical here
-- — a Liga MX final level after two legs goes to extra time — but the chart
-- reads the rhythm of a normal 90 minutes, and a handful of final-only extra
-- time buckets would sit at the right edge of every tournament's chart on a
-- sample of one or two matches.
SELECT
    d.season_mexico                                         AS tournament,
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
    END                                                     AS round_order,
    ts.team_side,
    r.match_result                                          AS result,
    mm.minute_bucket,
    mm.minute_bucket_sort,
    COUNT(*) FILTER (WHERE et.event_group = 'Goal')         AS goals,
    COUNT(*) FILTER (WHERE et.event_group = 'Card')         AS cards,
    COUNT(*) FILTER (WHERE et.event_group = 'Substitution') AS substitutions
FROM superligaen.gold.fct_match_events e
JOIN superligaen.gold.fct_team_matches f
    ON  f.match_sk = e.match_sk
    AND f.team_sk  = e.team_sk
JOIN superligaen.gold.dim_date             d   ON d.date_sk              = e.date_sk
JOIN superligaen.gold.dim_team             t   ON t.team_sk              = f.team_sk
JOIN superligaen.gold.dim_opponent_team    ot  ON ot.opponent_team_sk    = f.opponent_team_sk
JOIN superligaen.gold.dim_match            m   ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_team_side        ts  ON ts.team_side_sk        = f.team_side_sk
JOIN superligaen.gold.dim_match_result     r   ON r.match_result_sk      = f.match_result_sk
JOIN superligaen.gold.dim_match_minute     mm  ON mm.match_minute_sk     = e.match_minute_sk
JOIN superligaen.gold.dim_match_event_type et  ON et.match_event_type_sk = e.match_event_type_sk
WHERE e.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
  AND d.season_mexico IS NOT NULL
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND mm.match_minute_sk > 0
  AND mm.minute_bucket != 'Extra Time'
GROUP BY ALL
ORDER BY d.season_mexico DESC, t.team_name, round_order, mm.minute_bucket_sort
