-- One row per played match: the round-level totals the Match Results table
-- and its KPI cards read, plus the full home/away stat sheet behind the
-- head-to-head block on Match Analysis.
--
-- Where the Danish model builds its stat sheet by summing player appearances,
-- this one reads the team fact directly - Liga MX has no player-level data at
-- all, but its team-level feed is deeper than Denmark's. Two consequences:
--   * Woodwork hits have no team-level equivalent and are simply absent here.
--   * Expected goals are available and are carried, which Denmark cannot do.
--
-- NULL is never coerced to 0. The deep stats (xG, big chances, key passes,
-- crosses, tackles, interceptions, clearances) begin at 2024/25 Clausura,
-- when the Highlightly feed starts publishing them; before that they are
-- genuinely unrecorded, and a 0 would claim a team made no tackles. The
-- pages render those as an em dash.
WITH base AS (
    SELECT
        m.match_id,
        d.date                                              AS match_date,
        d.season_mexico                                     AS tournament,
        d.is_current_season_mexico                          AS is_current_tournament,
        CASE m.match_round_type
            WHEN 'Regular Season'  THEN m.match_round_number
            WHEN 'Reclasificación' THEN 18
            WHEN 'Play-offs'       THEN 19
            WHEN 'Quarter-finals'  THEN 20
            WHEN 'Semi-finals'     THEN 21
            WHEN 'Final'           THEN 22
        END                                                 AS round_order,
        CASE m.match_round_type
            WHEN 'Regular Season' THEN m.match_round_number::VARCHAR
            WHEN 'Play-offs'      THEN 'Play-in'
            ELSE m.match_round_type
        END                                                 AS round_label,
        CASE m.match_round_type
            WHEN 'Regular Season' THEN 'Round ' || m.match_round_number::VARCHAR
            WHEN 'Play-offs'      THEN 'Play-in'
            ELSE m.match_round_type
        END                                                 AS round_display,
        m.match_name,
        m.match_short_name,
        m.match_result                                      AS score,
        CASE WHEN ref.referee_common_name LIKE '%Unknown%' OR ref.referee_common_name LIKE '%Applicable%'
             THEN NULL ELSE ref.referee_common_name END     AS referee_name,
        t.team_name,
        t.team_short_name,
        t.team_logo,
        ts.team_side,
        f.goals_scored,
        f.expected_goals,
        f.ball_possession_pct                               AS possession_pct,
        f.corner_kicks,
        f.yellow_cards,
        f.red_cards,
        f.shots_on_target                                   AS shots_on_goal,
        -- Shots are published split three ways; the total only exists when at
        -- least one part does, so an unrecorded match stays NULL rather than 0.
        CASE WHEN f.shots_on_target IS NULL
              AND f.shots_off_target IS NULL
              AND f.shots_blocked IS NULL THEN NULL
             ELSE COALESCE(f.shots_on_target,  0)
                + COALESCE(f.shots_off_target, 0)
                + COALESCE(f.shots_blocked,    0)
        END                                                 AS total_shots,
        f.big_chances_created,
        f.key_passes,
        f.crosses                                           AS crosses_total,
        f.tackles,
        f.interceptions,
        f.clearances,
        f.goalkeeper_saves                                  AS saves,
        f.fouls,
        f.passes_total,
        f.passes_successful
    FROM superligaen.gold.fct_team_matches   f
    JOIN superligaen.gold.dim_date           d   ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match          m   ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_team           t   ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk   = f.team_side_sk
    JOIN superligaen.gold.dim_match_result   r   ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk    = f.referee_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
      AND d.season_mexico IS NOT NULL
)
SELECT
    match_id,
    max(match_date)                                                                                AS match_date,
    max(tournament)                                                                                AS tournament,
    max(is_current_tournament)                                                                     AS is_current_tournament,
    max(round_order)                                                                               AS round_order,
    max(round_label)                                                                               AS round_label,
    max(round_display)                                                                             AS round_display,
    max(match_name)                                                                                AS match_name,
    max(match_short_name)                                                                          AS match_short_name,
    max(score)                                                                                     AS score,
    max(referee_name)                                                                              AS referee_name,
    -- match totals (results table)
    sum(goals_scored)                                                                              AS total_goals,
    sum(expected_goals)::DOUBLE                                                                    AS total_xg,
    sum(shots_on_goal)                                                                             AS total_shots_on_goal,
    sum(total_shots)                                                                               AS total_shots,
    sum(big_chances_created)                                                                       AS total_big_chances,
    sum(yellow_cards)                                                                              AS total_yellow_cards,
    sum(red_cards)                                                                                 AS total_red_cards,
    -- home/away breakdown (match analysis)
    max(case when team_side = 'Home' then team_name       end)                                     AS home_team,
    max(case when team_side = 'Away' then team_name       end)                                     AS away_team,
    max(case when team_side = 'Home' then team_short_name end)                                     AS home_team_short,
    max(case when team_side = 'Away' then team_short_name end)                                     AS away_team_short,
    max(case when team_side = 'Home' then team_logo       end)                                     AS home_team_logo,
    max(case when team_side = 'Away' then team_logo       end)                                     AS away_team_logo,
    max(case when team_side = 'Home' then goals_scored    end)                                     AS home_goals,
    max(case when team_side = 'Away' then goals_scored    end)                                     AS away_goals,
    -- DOUBLE, not DECIMAL: the match analysis page does arithmetic on these to
    -- size the comparison bars, and a DECIMAL arrives in the browser as a string.
    max(case when team_side = 'Home' then expected_goals  end)::DOUBLE                             AS home_xg,
    max(case when team_side = 'Away' then expected_goals  end)::DOUBLE                             AS away_xg,
    max(case when team_side = 'Home' then total_shots     end)                                     AS home_total_shots,
    max(case when team_side = 'Away' then total_shots     end)                                     AS away_total_shots,
    max(case when team_side = 'Home' then shots_on_goal   end)                                     AS home_sog,
    max(case when team_side = 'Away' then shots_on_goal   end)                                     AS away_sog,
    max(case when team_side = 'Home' then big_chances_created end)                                 AS home_big_chances,
    max(case when team_side = 'Away' then big_chances_created end)                                 AS away_big_chances,
    max(case when team_side = 'Home' then possession_pct  end)                                     AS home_possession,
    max(case when team_side = 'Away' then possession_pct  end)                                     AS away_possession,
    round(max(case when team_side = 'Home' then passes_successful end)::double
        / nullif(max(case when team_side = 'Home' then passes_total end), 0) * 100, 1)             AS home_pass_accuracy,
    round(max(case when team_side = 'Away' then passes_successful end)::double
        / nullif(max(case when team_side = 'Away' then passes_total end), 0) * 100, 1)             AS away_pass_accuracy,
    max(case when team_side = 'Home' then key_passes      end)                                     AS home_key_passes,
    max(case when team_side = 'Away' then key_passes      end)                                     AS away_key_passes,
    max(case when team_side = 'Home' then crosses_total   end)                                     AS home_crosses,
    max(case when team_side = 'Away' then crosses_total   end)                                     AS away_crosses,
    max(case when team_side = 'Home' then corner_kicks    end)                                     AS home_corners,
    max(case when team_side = 'Away' then corner_kicks    end)                                     AS away_corners,
    max(case when team_side = 'Home' then tackles         end)                                     AS home_tackles,
    max(case when team_side = 'Away' then tackles         end)                                     AS away_tackles,
    max(case when team_side = 'Home' then interceptions   end)                                     AS home_interceptions,
    max(case when team_side = 'Away' then interceptions   end)                                     AS away_interceptions,
    max(case when team_side = 'Home' then clearances      end)                                     AS home_clearances,
    max(case when team_side = 'Away' then clearances      end)                                     AS away_clearances,
    max(case when team_side = 'Home' then saves           end)                                     AS home_saves,
    max(case when team_side = 'Away' then saves           end)                                     AS away_saves,
    max(case when team_side = 'Home' then fouls           end)                                     AS home_fouls,
    max(case when team_side = 'Away' then fouls           end)                                     AS away_fouls,
    max(case when team_side = 'Home' then yellow_cards    end)                                     AS home_yc,
    max(case when team_side = 'Away' then yellow_cards    end)                                     AS away_yc,
    max(case when team_side = 'Home' then red_cards       end)                                     AS home_rc,
    max(case when team_side = 'Away' then red_cards       end)                                     AS away_rc
FROM base
GROUP BY match_id
ORDER BY match_date DESC
