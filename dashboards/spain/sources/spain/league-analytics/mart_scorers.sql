-- Goalscorers at (player, team, match) grain, carrying the same slice
-- dimensions as mart_match_facts so the page's whole filter bar applies before
-- the ranking is computed.
--
-- The Highlightly feed has no player-level fact table — no appearances, no
-- ratings, no minutes — so this is built from the event stream, which does name
-- the scorer on every goal and runs complete from 2020/21. It is enough for a
-- top-scorer award and nothing more: assists are not published at all, and
-- neither are the ratings the Danish page's other two awards rank on.
--
-- Own goals are excluded. The event stream credits an own goal to the team
-- that benefits from it, so counting them here would hand a striker goals
-- scored by the opposition's defender.
SELECT
    d.season_spain                     AS season,
    p.player_name,
    t.team_name,
    t.team_logo,
    ot.opponent_team_name,
    m.match_id,
    m.match_round_number                AS round_order,
    ts.team_side,
    r.match_result                      AS result,
    COUNT(*)                            AS goals_scored
FROM superligaen.gold.fct_match_events      e
JOIN superligaen.gold.dim_match_event_type  et ON et.match_event_type_sk = e.match_event_type_sk
JOIN superligaen.gold.fct_team_matches      f  ON f.match_sk             = e.match_sk
                                              AND f.team_sk              = e.team_sk
JOIN superligaen.gold.dim_date              d  ON d.date_sk              = e.date_sk
JOIN superligaen.gold.dim_player            p  ON p.player_sk            = e.player_sk
JOIN superligaen.gold.dim_team              t  ON t.team_sk              = f.team_sk
JOIN superligaen.gold.dim_opponent_team     ot ON ot.opponent_team_sk    = f.opponent_team_sk
JOIN superligaen.gold.dim_match             m  ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_team_side         ts ON ts.team_side_sk        = f.team_side_sk
JOIN superligaen.gold.dim_match_result      r  ON r.match_result_sk      = f.match_result_sk
WHERE e.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 119924)  -- La Liga only
  AND d.season_spain IS NOT NULL
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND et.event_group = 'Goal'
  AND et.event_type_name IN ('Goal', 'Penalty')
GROUP BY ALL
