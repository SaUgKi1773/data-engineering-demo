-- Goals by player, club and match day. Own goals are excluded: they are
-- credited to the opposing team and belong to nobody's scoring record.
-- 'Penalty' sits inside the Goal event group, so penalties here are penalties
-- SCORED and are a subset of the goals column. Shootout kicks are a separate
-- group and are not goals at all.
SELECT
    p.player_name, t.team_name, l.league_name,
    d.date AS match_date, d.year AS calendar_year,
    COUNT(*)                                                AS goals,
    COUNT(*) FILTER (WHERE et.event_type_name = 'Penalty')  AS penalty_goals
FROM superligaen.gold.fct_match_events e
JOIN superligaen.gold.dim_player           p  ON p.player_sk            = e.player_sk
JOIN superligaen.gold.dim_team             t  ON t.team_sk              = e.team_sk
JOIN superligaen.gold.dim_league           l  ON l.league_sk            = e.league_sk
JOIN superligaen.gold.dim_date             d  ON d.date_sk              = e.date_sk
JOIN superligaen.gold.dim_match            m  ON m.match_sk             = e.match_sk
JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = e.match_event_type_sk
WHERE et.event_group = 'Goal' AND et.event_type_name <> 'Own Goal'
  AND m.match_type = 'Regular League' AND d.year >= 2020 AND p.player_name IS NOT NULL
GROUP BY 1,2,3,4,5
