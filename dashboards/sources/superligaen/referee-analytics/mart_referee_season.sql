WITH fouls_agg AS (
    SELECT match_sk, team_sk, SUM(fouls_committed) AS fouls
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
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
          / NULLIF(SUM(f.yellow_cards), 0), 1)                                             AS home_yc_pct
FROM superligaen.gold.fct_team_matches    f
JOIN superligaen.gold.dim_date            d   ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match           m   ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk = f.match_result_sk
JOIN superligaen.gold.dim_referee         ref ON ref.referee_sk    = f.referee_sk
JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk   = f.team_side_sk
LEFT JOIN fouls_agg                       fa  ON fa.match_sk       = f.match_sk
                                            AND fa.team_sk         = f.team_sk
WHERE d.season >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
GROUP BY d.season, ref.referee_common_name
ORDER BY d.season DESC, matches_managed DESC
