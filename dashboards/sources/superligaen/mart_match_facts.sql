WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)       AS shots_on_goal,
        SUM(shots_off_target)      AS shots_off_goal,
        SUM(shots_total)           AS total_shots,
        SUM(shots_blocked)         AS blocked_shots,
        SUM(passes_total)          AS total_passes,
        SUM(passes_accurate)       AS passes_accurate,
        SUM(fouls_committed)       AS fouls,
        SUM(fouls_drawn)           AS fouls_drawn,
        SUM(saves)                 AS goalkeeper_saves,
        SUM(offsides)              AS offsides,
        SUM(tackles)               AS tackles,
        SUM(tackles_won)           AS tackles_won,
        SUM(interceptions)         AS interceptions,
        SUM(clearances)            AS clearances,
        SUM(aerials_won)           AS aerials_won,
        SUM(aerials_lost)          AS aerials_lost,
        SUM(blocks)                AS blocks,
        SUM(duels_total)           AS duels_total,
        SUM(duels_won)             AS duels_won,
        SUM(dribbles_attempts)     AS dribbles_attempts,
        SUM(dribbles_completed)    AS dribbles_completed,
        SUM(key_passes)            AS key_passes,
        SUM(big_chances_created)   AS big_chances_created,
        SUM(big_chances_missed)    AS big_chances_missed,
        SUM(woodwork_hits)         AS woodwork_hits,
        SUM(crosses_total)         AS crosses_total,
        SUM(crosses_accurate)      AS crosses_accurate,
        SUM(chances_created)       AS chances_created,
        SUM(penalty_scored)        AS penalty_scored,
        SUM(penalty_missed)        AS penalty_missed,
        SUM(errors_leading_to_goal) AS errors_leading_to_goal
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
)
SELECT
    d.date                                                                   AS match_date,
    d.season,
    d.is_current_season,
    m.match_round_name,
    m.match_round_type,
    m.match_round_number,
    m.match_id,
    m.match_name,
    m.match_short_name,
    m.match_result                                                           AS score,
    m.match_status,
    m.kick_off_time,
    t.team_name,
    t.team_short_name,
    t.team_code,
    t.team_logo,
    f.team_sk,
    ot.opponent_team_name,
    ot.opponent_team_short_name,
    ot.opponent_team_code,
    f.opponent_team_sk,
    ts.team_side,
    r.match_result                                                           AS result,
    ref.referee_common_name                                                  AS referee_name,
    dc.coach_name,
    st.stadium_name,
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
    COALESCE(pa.shots_on_goal,    0)                                        AS shots_on_goal,
    COALESCE(pa.shots_off_goal,   0)                                        AS shots_off_goal,
    COALESCE(pa.total_shots,      0)                                        AS total_shots,
    COALESCE(pa.blocked_shots,    0)                                        AS blocked_shots,
    COALESCE(pa.total_passes,     0)                                        AS total_passes,
    COALESCE(pa.passes_accurate,  0)                                        AS passes_accurate,
    COALESCE(pa.fouls,              0)                                      AS fouls,
    COALESCE(pa.fouls_drawn,       0)                                      AS fouls_drawn,
    COALESCE(pa.goalkeeper_saves,  0)                                      AS saves,
    COALESCE(pa.offsides,          0)                                      AS offsides,
    COALESCE(pa.tackles,           0)                                      AS tackles,
    COALESCE(pa.tackles_won,       0)                                      AS tackles_won,
    COALESCE(pa.interceptions,     0)                                      AS interceptions,
    COALESCE(pa.clearances,        0)                                      AS clearances,
    COALESCE(pa.aerials_won,       0)                                      AS aerials_won,
    COALESCE(pa.aerials_lost,      0)                                      AS aerials_lost,
    COALESCE(pa.blocks,            0)                                      AS blocks,
    COALESCE(pa.duels_total,       0)                                      AS duels_total,
    COALESCE(pa.duels_won,         0)                                      AS duels_won,
    COALESCE(pa.dribbles_attempts, 0)                                      AS dribbles_attempts,
    COALESCE(pa.dribbles_completed,0)                                      AS dribbles_completed,
    COALESCE(pa.key_passes,        0)                                      AS key_passes,
    COALESCE(pa.big_chances_created, 0)                                    AS big_chances_created,
    COALESCE(pa.big_chances_missed,  0)                                    AS big_chances_missed,
    COALESCE(pa.woodwork_hits,     0)                                      AS woodwork_hits,
    COALESCE(pa.crosses_total,          0)                                 AS crosses_total,
    COALESCE(pa.crosses_accurate,       0)                                 AS crosses_accurate,
    COALESCE(pa.chances_created,        0)                                 AS chances_created,
    COALESCE(pa.penalty_scored,         0)                                 AS penalty_scored,
    COALESCE(pa.penalty_missed,         0)                                 AS penalty_missed,
    COALESCE(pa.errors_leading_to_goal, 0)                                 AS errors_leading_to_goal,
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
LEFT JOIN superligaen.gold.dim_coach     dc  ON dc.coach_sk         = f.coach_sk
LEFT JOIN player_agg                         pa  ON pa.match_sk         = f.match_sk
                                                AND pa.team_sk          = f.team_sk
WHERE f.match_result_sk > 0
  AND m.match_round_number IS NOT NULL
  AND d.season >= '2020/21'
