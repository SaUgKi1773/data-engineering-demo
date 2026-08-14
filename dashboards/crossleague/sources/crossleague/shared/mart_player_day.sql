-- Goals and cards by player, club and match day.
--
-- Own goals are excluded: they are credited to the opposing team and belong to
-- nobody's scoring record. 'Penalty' sits inside the Goal event group, so
-- penalty_goals are penalties SCORED and are a subset of goals. Shootout kicks
-- are a separate group and are not goals at all.
--
-- Sending off is conformed as red + second yellow. Sportmonks raises a distinct
-- 'Second Yellow Card' where Highlightly folds it into 'Red Card'; verified that
-- no player-match carries both, so the two add without double counting.
--
-- Club is kept in the grain so a transfer is visible, but every leaderboard
-- built on this must total per player, never per player-club: split by club,
-- a striker's league-leading haul becomes three unremarkable rows.
SELECT
    p.player_name, t.team_name, l.league_name,
    d.date AS match_date, d.year AS calendar_year,
    COUNT(*) FILTER (WHERE et.event_group = 'Goal')                     AS goals,
    COUNT(*) FILTER (WHERE et.event_type_name = 'Penalty')              AS penalty_goals,
    COUNT(*) FILTER (WHERE et.event_type_name = 'Yellow Card')          AS yellow_cards,
    COUNT(*) FILTER (WHERE et.event_type_name IN ('Red Card', 'Second Yellow Card'))
                                                                        AS sent_off
FROM superligaen.gold.fct_match_events e
JOIN superligaen.gold.dim_player           p  ON p.player_sk            = e.player_sk
JOIN superligaen.gold.dim_team             t  ON t.team_sk              = e.team_sk
JOIN superligaen.gold.dim_league           l  ON l.league_sk            = e.league_sk
JOIN superligaen.gold.dim_date             d  ON d.date_sk              = e.date_sk
JOIN superligaen.gold.dim_match            m  ON m.match_sk             = e.match_sk
JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = e.match_event_type_sk
WHERE (
        (et.event_group = 'Goal' AND et.event_type_name <> 'Own Goal')
     OR  et.event_group = 'Card'
      )
  AND m.match_type = 'Regular League' AND d.year >= 2020
  -- dim_player carries the two NULL-id sentinels. 'Not Applicable Player' absorbs
  -- cards shown to benches and staff and would otherwise top every booking list;
  -- 'Unknown Player' holds goals the provider left unattributed.
  AND p.player_id IS NOT NULL
GROUP BY 1, 2, 3, 4, 5
