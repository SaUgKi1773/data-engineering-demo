-- One row per (team, played match): the slice-and-dice base for every section
-- of League Intelligence. The page filters this on tournament, team, round,
-- phase, venue, result and opponent, then aggregates — so every measure here
-- has to survive being summed over an arbitrary subset.
--
-- Where the Danish model builds its measures by summing player appearances,
-- this one reads the team fact directly: Liga MX publishes no player-level
-- data at all. Two consequences run through the whole page:
--
--   * Measures with no team-level equivalent are simply absent — chances
--     created, duels, balls recovered, fouls drawn, errors leading to a goal,
--     times dribbled past. The page substitutes what exists rather than
--     leaving holes.
--   * The deep stats (xG, xA, big chances, key passes, crosses, dribbles,
--     tackles, interceptions, clearances, aerial duels, final-third and long
--     passes) start at **2024/25 Clausura**, when the Highlightly feed begins
--     publishing them. Eight of the thirteen tournaments here predate that.
--     They stay NULL, never 0 — a 0 would claim a team won no aerial duels.
--     The page renders them as an em dash.
--
-- Everything from possession, shots, passes, fouls, saves, corners, offsides
-- and cards is complete from 2020/21 Apertura.
WITH pen AS (
    -- Penalties come off the event stream; there is no team-level penalty
    -- measure. Scored is complete from 2020/21, but MISSED penalties only
    -- appear from 2024/25 Apertura, so `penalty_missed` is NULL before that
    -- rather than 0 — otherwise every early tournament would report a
    -- flawless 100% conversion rate, which is worse than reporting nothing.
    SELECT
        e.match_sk,
        e.team_sk,
        COUNT(*) FILTER (WHERE et.event_type_name = 'Penalty')    AS penalty_scored,
        COUNT(*) FILTER (WHERE et.event_group = 'Missed Penalty') AS penalty_missed
    FROM superligaen.gold.fct_match_events e
    JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = e.match_event_type_sk
    WHERE e.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
    GROUP BY e.match_sk, e.team_sk
)
SELECT
    d.date                                          AS match_date,
    d.season_mexico                                 AS tournament,
    d.is_current_season_mexico                      AS is_current_tournament,
    d.month_name,
    d.day_name,
    d.is_weekend,
    m.match_round_type,
    CASE m.match_round_type
        WHEN 'Regular Season'  THEN m.match_round_number
        WHEN 'Reclasificación' THEN 18
        WHEN 'Play-offs'       THEN 19
        WHEN 'Quarter-finals'  THEN 20
        WHEN 'Semi-finals'     THEN 21
        WHEN 'Final'           THEN 22
    END                                             AS round_order,
    CASE m.match_round_type
        WHEN 'Regular Season' THEN m.match_round_number::VARCHAR
        WHEN 'Play-offs'      THEN 'Play-in'
        ELSE m.match_round_type
    END                                             AS round_label,
    CASE m.match_round_type
        WHEN 'Regular Season' THEN 'Round ' || m.match_round_number::VARCHAR
        WHEN 'Play-offs'      THEN 'Play-in'
        ELSE m.match_round_type
    END                                             AS round_display,
    m.match_id,
    m.match_name,
    m.match_short_name,
    m.match_result                                  AS score,
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
    r.match_result                                  AS result,
    CASE WHEN ref.referee_common_name LIKE '%Unknown%' OR ref.referee_common_name LIKE '%Applicable%'
         THEN NULL ELSE ref.referee_common_name END AS referee_name,
    CASE WHEN st.stadium_name LIKE '%Unknown%' OR st.stadium_name LIKE '%Applicable%'
         THEN NULL ELSE st.stadium_name END         AS stadium_name,
    CASE WHEN st.stadium_city LIKE '%Unknown%' OR st.stadium_city LIKE '%Applicable%'
         THEN NULL ELSE st.stadium_city END         AS stadium_city,
    f.points_earned,
    f.goals_scored,
    f.goals_conceded,
    -- goals_ht_scored / goals_ht_conceded are deliberately absent: no page
    -- reads the interval score off this mart, and mart_team_game_state already
    -- serves the one section that needs it.
    -- complete from 2020/21 Apertura
    f.ball_possession_pct                           AS possession_pct,
    f.corner_kicks,
    f.yellow_cards,
    f.red_cards,
    f.offsides,
    f.fouls,
    f.goalkeeper_saves                              AS saves,
    f.shots_on_target                               AS shots_on_goal,
    f.shots_off_target                              AS shots_off_goal,
    f.shots_blocked                                 AS blocked_shots,
    f.shots_inside_box,
    f.shots_outside_box,
    CASE WHEN f.shots_on_target IS NULL
          AND f.shots_off_target IS NULL
          AND f.shots_blocked IS NULL THEN NULL
         ELSE COALESCE(f.shots_on_target,  0)
            + COALESCE(f.shots_off_target, 0)
            + COALESCE(f.shots_blocked,    0)
    END                                             AS total_shots,
    f.passes_total                                  AS total_passes,
    f.passes_successful                             AS passes_accurate,
    COALESCE(pen.penalty_scored, 0)                 AS penalty_scored,
    CASE WHEN d.season_mexico >= '2024/25 - Apertura'
         THEN COALESCE(pen.penalty_missed, 0) END   AS penalty_missed,
    -- deep-stat era only, from 2024/25 Clausura
    f.expected_goals,
    f.expected_assists,
    f.big_chances_created,
    f.key_passes,
    f.crosses                                       AS crosses_total,
    f.crosses_successful                            AS crosses_accurate,
    f.dribbles                                      AS dribbles_attempts,
    f.dribbles_successful                           AS dribbles_completed,
    f.tackles,
    f.tackles_successful                            AS tackles_won,
    f.interceptions,
    f.clearances,
    f.aerial_duels,
    f.aerial_duels_successful                       AS aerials_won,
    f.passes_final_third,
    f.long_passes,
    f.long_passes_successful,
    f.attacks,
    -- Liga MX never splits into championship and relegation groups the way the
    -- Danish season does, so this is a constant. Kept so the page's shared
    -- shape survives; the group legend and column simply never appear.
    'Regular Season'                                AS standings_type,
    -- Cumulative totals run over the regular rounds only, in round order.
    -- Liguilla ties award no points (points_earned is NULL there), so they
    -- would flatten the race rather than extend it.
    SUM(f.points_earned) OVER (
        PARTITION BY f.team_sk, d.season_mexico
        ORDER BY m.match_round_number
    )                                               AS cumulative_points,
    SUM(f.goals_scored - f.goals_conceded) OVER (
        PARTITION BY f.team_sk, d.season_mexico
        ORDER BY m.match_round_number
    )                                               AS cumulative_gd,
    SUM(f.goals_scored) OVER (
        PARTITION BY f.team_sk, d.season_mexico
        ORDER BY m.match_round_number
    )                                               AS cumulative_gf
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date           d   ON d.date_sk           = f.date_sk
JOIN superligaen.gold.dim_match          m   ON m.match_sk          = f.match_sk
JOIN superligaen.gold.dim_team           t   ON t.team_sk           = f.team_sk
JOIN superligaen.gold.dim_opponent_team  ot  ON ot.opponent_team_sk = f.opponent_team_sk
JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk   = f.match_result_sk
JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk     = f.team_side_sk
JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk      = f.referee_sk
JOIN superligaen.gold.dim_stadium        st  ON st.stadium_sk       = f.stadium_sk
JOIN superligaen.gold.dim_time           dt  ON dt.time_sk          = f.time_sk
LEFT JOIN pen                                ON pen.match_sk        = f.match_sk
                                            AND pen.team_sk         = f.team_sk
WHERE r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
  AND d.season_mexico IS NOT NULL
