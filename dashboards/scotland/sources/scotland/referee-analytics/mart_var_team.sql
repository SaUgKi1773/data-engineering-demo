-- VAR decisions by season and team: one row per season and team, counting the
-- high-stakes outcomes the video team produced in that team's matches. team_sk
-- is the team each incident is attributed to (not a benefit/harm judgement);
-- routine card reviews are excluded. Outcomes are categorised from 2023/24
-- onward, and sub-type casing is inconsistent upstream, so match on lower().
SELECT
    d.season_scotland                                                             AS season,
    t.team_name,
    COUNT(*)                                                                       AS var_reviews,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'goal disallowed')       AS goals_disallowed,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'goal awarded')          AS goals_awarded,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'penalty confirmed')     AS penalties_confirmed,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'penalty cancelled')     AS penalties_cancelled
FROM superligaen.gold.fct_match_events      f
JOIN superligaen.gold.dim_date              d   ON d.date_sk              = f.date_sk
JOIN superligaen.gold.dim_team              t   ON t.team_sk              = f.team_sk
JOIN superligaen.gold.dim_match_event_type  et  ON et.match_event_type_sk = f.match_event_type_sk
WHERE d.season_scotland >= '2020/21'
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
  AND et.event_group = 'VAR'
  AND f.team_sk > 0
GROUP BY d.season_scotland, t.team_name
ORDER BY d.season_scotland DESC, var_reviews DESC
