-- One row per season and referee: cards, fouls and VAR involvement together, so
-- VAR reads as a first-class discipline measure everywhere on the page rather
-- than a bolt-on. Review counts are reliable back to 2020/21; the source only
-- began categorising outcomes (goal/penalty overturns) in 2023/24, so earlier
-- seasons carry reviews with zero-filled outcome columns. Sub-type casing is
-- inconsistent upstream ('Goal awarded' vs 'Goal Disallowed'), so match on lower().
WITH fouls_agg AS (
    SELECT match_sk, team_sk, SUM(fouls_committed) AS fouls
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
var_agg AS (
    SELECT
        d.season,
        ref.referee_common_name                                                     AS referee_name,
        COUNT(*)                                                                     AS var_reviews,
        COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'goal disallowed')    AS goals_disallowed,
        COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'goal awarded')       AS goals_awarded,
        COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'penalty confirmed')  AS penalties_confirmed,
        COUNT(*) FILTER (WHERE lower(et.event_sub_type_name) = 'penalty cancelled')  AS penalties_cancelled,
        COUNT(*) FILTER (WHERE et.event_type_name = 'VAR Card Review')               AS card_reviews
    FROM superligaen.gold.fct_match_events      ve
    JOIN superligaen.gold.dim_date              d   ON d.date_sk              = ve.date_sk
    JOIN superligaen.gold.dim_referee           ref ON ref.referee_sk         = ve.referee_sk
    JOIN superligaen.gold.dim_match_event_type  et  ON et.match_event_type_sk = ve.match_event_type_sk
    WHERE d.season >= '2020/21'
      AND ve.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
      AND ve.referee_sk > 0
      AND et.event_group = 'VAR'
    GROUP BY d.season, ref.referee_common_name
)
SELECT
    d.season,
    ref.referee_common_name                                                                AS referee_name,
    COUNT(DISTINCT m.match_id)::int                                                        AS matches_managed,
    SUM(f.yellow_cards)::int                                                               AS total_yellow_cards,
    SUM(f.red_cards)::int                                                                  AS total_red_cards,
    SUM(COALESCE(fa.fouls, 0))::int                                                        AS total_fouls,
    ROUND(SUM(f.yellow_cards)::double  / COUNT(DISTINCT m.match_id), 2)                    AS avg_yellows_per_match,
    ROUND(SUM(f.red_cards)::double     / COUNT(DISTINCT m.match_id), 3)                    AS avg_reds_per_match,
    ROUND(SUM(COALESCE(fa.fouls, 0))::double / COUNT(DISTINCT m.match_id), 1)              AS avg_fouls_per_match,
    ROUND((SUM(f.yellow_cards) + SUM(f.red_cards) * 3)::double / COUNT(DISTINCT m.match_id), 2) AS card_severity_index,
    ROUND(SUM(CASE WHEN ts.team_side = 'Home' THEN f.yellow_cards ELSE 0 END)::double
          / COUNT(DISTINCT m.match_id), 2)                                                 AS home_yc_per_match,
    ROUND(SUM(CASE WHEN ts.team_side = 'Away' THEN f.yellow_cards ELSE 0 END)::double
          / COUNT(DISTINCT m.match_id), 2)                                                 AS away_yc_per_match,
    ROUND(100.0 * SUM(CASE WHEN ts.team_side = 'Home' THEN f.yellow_cards ELSE 0 END)
          / NULLIF(SUM(f.yellow_cards), 0), 1)                                             AS home_yc_pct,
    ROUND(100.0 * SUM(CASE WHEN ts.team_side = 'Home' THEN f.yellow_cards + f.red_cards ELSE 0 END)
          / NULLIF(SUM(f.yellow_cards + f.red_cards), 0), 1)                               AS home_card_pct,
    SUM(f.yellow_cards + f.red_cards)::int                                                 AS total_cards,
    COALESCE(v.var_reviews, 0)::int                                                        AS var_reviews,
    COALESCE(v.goals_disallowed, 0)::int                                                   AS goals_disallowed,
    COALESCE(v.goals_awarded, 0)::int                                                      AS goals_awarded,
    COALESCE(v.penalties_confirmed, 0)::int                                                AS penalties_confirmed,
    COALESCE(v.penalties_cancelled, 0)::int                                                AS penalties_cancelled,
    COALESCE(v.card_reviews, 0)::int                                                       AS var_card_reviews,
    ROUND(COALESCE(v.var_reviews, 0)::double / COUNT(DISTINCT m.match_id), 2)              AS var_per_match
FROM superligaen.gold.fct_team_matches    f
JOIN superligaen.gold.dim_date            d   ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match           m   ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk = f.match_result_sk
JOIN superligaen.gold.dim_referee         ref ON ref.referee_sk    = f.referee_sk
JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk   = f.team_side_sk
LEFT JOIN fouls_agg                       fa  ON fa.match_sk       = f.match_sk
                                            AND fa.team_sk         = f.team_sk
LEFT JOIN var_agg                         v   ON v.season          = d.season
                                            AND v.referee_name     = ref.referee_common_name
WHERE d.season >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
  AND f.referee_sk > 0  -- exclude the "Unknown Referee" placeholder
GROUP BY d.season, ref.referee_common_name,
         v.var_reviews, v.goals_disallowed, v.goals_awarded,
         v.penalties_confirmed, v.penalties_cancelled, v.card_reviews
ORDER BY d.season DESC, matches_managed DESC
