-- VAR involvement per match: total reviews plus the two 'against' outcomes
-- (goals ruled out, penalties scrubbed), so the referee match log can show what
-- the video team did game by game. One row per match. Sub-type casing is
-- inconsistent upstream, so match on lower().
SELECT
    d.season,
    m.match_id,
    COUNT(*)                                                                       AS var_reviews,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'goal disallowed')       AS goals_disallowed,
    COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'penalty cancelled')     AS penalties_cancelled
FROM superligaen.gold.fct_match_events      f
JOIN superligaen.gold.dim_date              d   ON d.date_sk              = f.date_sk
JOIN superligaen.gold.dim_match             m   ON m.match_sk             = f.match_sk
JOIN superligaen.gold.dim_match_event_type  et  ON et.match_event_type_sk = f.match_event_type_sk
WHERE d.season >= '2020/21'
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
  AND et.event_group = 'VAR'
GROUP BY d.season, m.match_id
