WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)        AS shots_on_goal,
        SUM(shots_off_target)       AS shots_off_goal,
        SUM(shots_total)            AS total_shots,
        SUM(shots_blocked)          AS blocked_shots,
        SUM(passes_total)           AS total_passes,
        SUM(passes_accurate)        AS passes_accurate,
        SUM(passes_final_third)     AS passes_final_third,
        SUM(passes_backward)        AS passes_backward,
        SUM(long_balls)             AS long_balls,
        SUM(long_balls_won)         AS long_balls_won,
        SUM(fouls_committed)        AS fouls,
        SUM(fouls_drawn)            AS fouls_drawn,
        SUM(saves)                  AS goalkeeper_saves,
        SUM(saves_inside_box)       AS saves_inside_box,
        SUM(goalkeeper_punches)     AS goalkeeper_punches,
        SUM(high_ball_claims)       AS high_ball_claims,
        SUM(offsides)               AS offsides,
        SUM(tackles)                AS tackles,
        SUM(tackles_won)            AS tackles_won,
        SUM(interceptions)          AS interceptions,
        SUM(clearances)             AS clearances,
        SUM(clearances_off_line)    AS clearances_off_line,
        SUM(last_man_tackle)        AS last_man_tackle,
        SUM(aerials_won)            AS aerials_won,
        SUM(aerials_lost)           AS aerials_lost,
        SUM(blocks)                 AS blocks,
        SUM(balls_recovered)        AS balls_recovered,
        SUM(duels_total)            AS duels_total,
        SUM(duels_won)              AS duels_won,
        SUM(duels_lost)             AS duels_lost,
        SUM(dribbles_attempts)      AS dribbles_attempts,
        SUM(dribbles_completed)     AS dribbles_completed,
        SUM(times_dribbled_past)    AS times_dribbled_past,
        SUM(dispossessed)           AS dispossessed,
        SUM(possession_losses)      AS possession_losses,
        SUM(key_passes)             AS key_passes,
        SUM(big_chances_created)    AS big_chances_created,
        SUM(big_chances_missed)     AS big_chances_missed,
        SUM(woodwork_hits)          AS woodwork_hits,
        SUM(crosses_total)          AS crosses_total,
        SUM(crosses_accurate)       AS crosses_accurate,
        SUM(chances_created)        AS chances_created,
        SUM(penalty_won)            AS penalty_won,
        SUM(penalty_committed)      AS penalty_committed,
        SUM(penalty_scored)         AS penalty_scored,
        SUM(penalty_missed)         AS penalty_missed,
        SUM(penalty_saved)          AS penalty_saved,
        SUM(errors_leading_to_goal) AS errors_leading_to_goal,
        SUM(errors_leading_to_shot) AS errors_leading_to_shot
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
)
SELECT
    d.date                                                                   AS match_date,
    d.season,
    d.is_current_season,
    d.month_name,
    d.day_name,
    d.is_weekend,
    m.match_round_name,
    m.match_round_type,
    m.match_round_number,
    m.match_id,
    m.match_name,
    m.match_short_name,
    m.match_result                                                           AS score,
    m.match_status,
    m.kick_off_time,
    dt.period_of_day,
    t.team_name,
    t.team_short_name,
    t.team_code,
    t.team_logo,
    f.team_sk,
    ot.opponent_team_name,
    ot.opponent_team_short_name,
    ot.opponent_team_code,
    ot.opponent_team_logo,
    f.opponent_team_sk,
    ts.team_side,
    r.match_result                                                           AS result,
    ref.referee_common_name                                                  AS referee_name,
    ref.referee_display_name,
    ref.referee_nationality,
    dc.coach_name,
    df.formation,
    st.stadium_name,
    st.stadium_city,
    st.stadium_surface,
    st.stadium_capacity,
    st.stadium_latitude,
    st.stadium_longitude,
    f.points_earned,
    f.goals_scored,
    f.goals_conceded,
    f.goals_ht_scored,
    f.goals_ht_conceded,
    f.ball_possession_pct                                                    AS possession_pct,
    f.corner_kicks,
    f.yellow_cards,
    f.red_cards,
    COALESCE(pa.shots_on_goal,          0)                                  AS shots_on_goal,
    COALESCE(pa.shots_off_goal,         0)                                  AS shots_off_goal,
    COALESCE(pa.total_shots,            0)                                  AS total_shots,
    COALESCE(pa.blocked_shots,          0)                                  AS blocked_shots,
    COALESCE(pa.total_passes,           0)                                  AS total_passes,
    COALESCE(pa.passes_accurate,        0)                                  AS passes_accurate,
    COALESCE(pa.passes_final_third,     0)                                  AS passes_final_third,
    COALESCE(pa.passes_backward,        0)                                  AS passes_backward,
    COALESCE(pa.long_balls,             0)                                  AS long_balls,
    COALESCE(pa.long_balls_won,         0)                                  AS long_balls_won,
    COALESCE(pa.fouls,                  0)                                  AS fouls,
    COALESCE(pa.fouls_drawn,            0)                                  AS fouls_drawn,
    COALESCE(pa.goalkeeper_saves,       0)                                  AS saves,
    COALESCE(pa.saves_inside_box,       0)                                  AS saves_inside_box,
    COALESCE(pa.goalkeeper_punches,     0)                                  AS goalkeeper_punches,
    COALESCE(pa.high_ball_claims,       0)                                  AS high_ball_claims,
    COALESCE(pa.offsides,               0)                                  AS offsides,
    COALESCE(pa.tackles,                0)                                  AS tackles,
    COALESCE(pa.tackles_won,            0)                                  AS tackles_won,
    COALESCE(pa.interceptions,          0)                                  AS interceptions,
    COALESCE(pa.clearances,             0)                                  AS clearances,
    COALESCE(pa.clearances_off_line,    0)                                  AS clearances_off_line,
    COALESCE(pa.last_man_tackle,        0)                                  AS last_man_tackle,
    COALESCE(pa.aerials_won,            0)                                  AS aerials_won,
    COALESCE(pa.aerials_lost,           0)                                  AS aerials_lost,
    COALESCE(pa.blocks,                 0)                                  AS blocks,
    COALESCE(pa.balls_recovered,        0)                                  AS balls_recovered,
    COALESCE(pa.duels_total,            0)                                  AS duels_total,
    COALESCE(pa.duels_won,              0)                                  AS duels_won,
    COALESCE(pa.duels_lost,             0)                                  AS duels_lost,
    COALESCE(pa.dribbles_attempts,      0)                                  AS dribbles_attempts,
    COALESCE(pa.dribbles_completed,     0)                                  AS dribbles_completed,
    COALESCE(pa.times_dribbled_past,    0)                                  AS times_dribbled_past,
    COALESCE(pa.dispossessed,           0)                                  AS dispossessed,
    COALESCE(pa.possession_losses,      0)                                  AS possession_losses,
    COALESCE(pa.key_passes,             0)                                  AS key_passes,
    COALESCE(pa.big_chances_created,    0)                                  AS big_chances_created,
    COALESCE(pa.big_chances_missed,     0)                                  AS big_chances_missed,
    COALESCE(pa.woodwork_hits,          0)                                  AS woodwork_hits,
    COALESCE(pa.crosses_total,          0)                                  AS crosses_total,
    COALESCE(pa.crosses_accurate,       0)                                  AS crosses_accurate,
    COALESCE(pa.chances_created,        0)                                  AS chances_created,
    COALESCE(pa.penalty_won,            0)                                  AS penalty_won,
    COALESCE(pa.penalty_committed,      0)                                  AS penalty_committed,
    COALESCE(pa.penalty_scored,         0)                                  AS penalty_scored,
    COALESCE(pa.penalty_missed,         0)                                  AS penalty_missed,
    COALESCE(pa.penalty_saved,          0)                                  AS penalty_saved,
    COALESCE(pa.errors_leading_to_goal, 0)                                  AS errors_leading_to_goal,
    COALESCE(pa.errors_leading_to_shot, 0)                                  AS errors_leading_to_shot,
    CASE
        WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, d.season) = 1
            THEN 'Championship Group'
        WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END) OVER (PARTITION BY f.team_sk, d.season) = 1
            THEN 'Relegation Group'
        ELSE 'Regular Season'
    END                                                                      AS standings_type,
    SUM(f.points_earned) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_points,
    SUM(f.goals_scored - f.goals_conceded) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gd,
    SUM(f.goals_scored) OVER (
        PARTITION BY f.team_sk, d.season
        ORDER BY m.match_round_number
    )                                                                        AS cumulative_gf
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date           d   ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_match          m   ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team           t   ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team  ot  ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk   = f.match_result_sk
JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk      = f.referee_sk
JOIN superligaen.gold.dim_stadium        st  ON st.stadium_sk       = f.stadium_sk
JOIN superligaen.gold.dim_coach          dc  ON dc.coach_sk         = f.coach_sk
JOIN superligaen.gold.dim_formation      df  ON df.formation_sk     = f.formation_sk
JOIN superligaen.gold.dim_time           dt  ON dt.time_sk          = f.time_sk
LEFT JOIN player_agg                     pa  ON pa.match_sk         = f.match_sk
                                           AND pa.team_sk           = f.team_sk
WHERE d.season >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
