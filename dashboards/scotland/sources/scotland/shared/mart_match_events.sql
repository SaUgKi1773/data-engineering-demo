-- Every on-pitch event for each match, one row per event, feeding the match
-- timeline: goals, cards, substitutions and VAR reviews, each with the minute,
-- the acting side and player, and the running score after the event. Ordered
-- chronologically (minute, then stoppage offset, then within-group sequence).
SELECT
    m.match_id,
    mm.minute_of_match,
    mm.minute_label,
    mm.stoppage_offset,
    mm.period_name,
    ts.team_side,
    et.event_group,
    et.event_type_name,
    et.event_sub_type_name,
    p.player_name,
    f.home_score_after_event                        AS home_score,
    f.away_score_after_event                        AS away_score,
    f.event_group_sequence
FROM superligaen.gold.fct_match_events      f
JOIN superligaen.gold.dim_date              d   ON d.date_sk              = f.date_sk
JOIN superligaen.gold.dim_match             m   ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_match_minute      mm  ON mm.match_minute_sk     = f.match_minute_sk
JOIN superligaen.gold.dim_match_event_type  et  ON et.match_event_type_sk = f.match_event_type_sk
JOIN superligaen.gold.dim_team_side         ts  ON ts.team_side_sk        = f.team_side_sk
LEFT JOIN superligaen.gold.dim_player       p   ON p.player_sk            = f.player_sk
WHERE d.season_scotland >= '2020/21'
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
  AND et.event_group IN ('Goal', 'Card', 'Substitution', 'VAR')
  AND mm.match_minute_sk > 0
ORDER BY m.match_id, mm.minute_of_match, mm.stoppage_offset, f.event_group_sequence
