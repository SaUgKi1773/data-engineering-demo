-- One row per (team, played match), feeding the form guide on the Match
-- Preview page. Liguilla ties are included on purpose: form going into a
-- fixture means the last five matches played, whatever competition phase
-- they belonged to.
SELECT
    m.match_id,
    d.date                                  AS match_date,
    d.season_mexico                         AS tournament,
    d.day_name,
    dt.period_of_day,
    m.match_round_type,
    CASE m.match_round_type
        WHEN 'Regular Season'  THEN m.match_round_number
        WHEN 'Reclasificación' THEN 18
        WHEN 'Play-offs'       THEN 19
        WHEN 'Quarter-finals'  THEN 20
        WHEN 'Semi-finals'     THEN 21
        WHEN 'Final'           THEN 22
    END                                     AS round_order,
    CASE m.match_round_type
        WHEN 'Regular Season' THEN m.match_round_number::VARCHAR
        WHEN 'Play-offs'      THEN 'Play-in'
        ELSE m.match_round_type
    END                                     AS round_label,
    m.match_short_name,
    m.match_result                          AS score,
    t.team_name,
    t.team_short_name,
    t.team_logo,
    ot.opponent_team_name,
    ot.opponent_team_short_name,
    ts.team_side,
    r.match_result                          AS result,
    f.goals_scored,
    f.goals_conceded,
    f.points_earned,
    f.ball_possession_pct                   AS possession_pct,
    f.yellow_cards,
    f.red_cards,
    f.shots_on_target                       AS shots_on_goal,
    f.passes_total                          AS total_passes,
    f.passes_successful                     AS passes_accurate
FROM superligaen.gold.fct_team_matches    f
JOIN superligaen.gold.dim_date            d   ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_match           m   ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team            t   ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team   ot  ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk   = f.match_result_sk
JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_time            dt  ON dt.time_sk          = f.time_sk
WHERE r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
  AND d.season_mexico IS NOT NULL
