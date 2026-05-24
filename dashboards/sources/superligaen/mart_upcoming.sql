SELECT
    m.match_id,
    d.date                                                                                  AS match_date,
    d.season,
    m.match_round_number,
    m.match_round_name                                                                      AS round,
    m.kick_off_time,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name       END)                        AS home_team,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name       END)                        AS away_team,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name END)                        AS home_team_short,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name END)                        AS away_team_short,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name END) || ' - ' ||
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name END)                        AS match_short_name,
    CASE WHEN st.stadium_name LIKE '%Unknown%' OR st.stadium_name LIKE '%Applicable%'
         THEN 'TBD' ELSE st.stadium_name END                                               AS stadium,
    ref.referee_common_name                                                                 AS referee
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date          d   ON d.date_sk          = f.date_sk
JOIN superligaen.gold.dim_match         m   ON m.match_sk         = f.match_sk
JOIN superligaen.gold.dim_team          t   ON t.team_sk          = f.team_sk
JOIN superligaen.gold.dim_team_side     ts  ON ts.team_side_sk    = f.team_side_sk
JOIN superligaen.gold.dim_match_result  r   ON r.match_result_sk  = f.match_result_sk
JOIN superligaen.gold.dim_stadium       st  ON st.stadium_sk      = f.stadium_sk
JOIN superligaen.gold.dim_referee       ref ON ref.referee_sk     = f.referee_sk
WHERE m.match_type = 'Group Stage'
  AND r.match_result = 'Pending'
GROUP BY m.match_id, d.date, d.season, m.match_round_number, m.match_round_name,
         m.kick_off_time, st.stadium_name, ref.referee_common_name
ORDER BY d.date ASC, m.kick_off_time ASC
