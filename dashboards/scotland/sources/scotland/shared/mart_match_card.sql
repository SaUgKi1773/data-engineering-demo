WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)     AS shots_on_goal,
        SUM(shots_total)         AS total_shots,
        SUM(fouls_committed)     AS fouls,
        SUM(saves)               AS saves,
        SUM(tackles)             AS tackles,
        SUM(interceptions)       AS interceptions,
        SUM(clearances)          AS clearances,
        SUM(passes_total)        AS total_passes,
        SUM(passes_accurate)     AS passes_accurate,
        SUM(key_passes)          AS key_passes,
        SUM(big_chances_created) AS big_chances_created,
        SUM(woodwork_hits)       AS woodwork_hits,
        SUM(crosses_total)       AS crosses_total
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
base AS (
    SELECT
        m.match_id,
        d.date                                              AS match_date,
        d.season_scotland AS season,
        m.match_round_number,
        m.match_round_name,
        m.match_name,
        m.match_result                                      AS score,
        ref.referee_common_name                             AS referee_name,
        t.team_name,
        t.team_short_name,
        ts.team_side,
        f.goals_scored,
        f.ball_possession_pct                               AS possession_pct,
        f.corner_kicks,
        f.yellow_cards,
        f.red_cards,
        COALESCE(pa.shots_on_goal,        0)                AS shots_on_goal,
        COALESCE(pa.total_shots,          0)                AS total_shots,
        COALESCE(pa.fouls,                0)                AS fouls,
        COALESCE(pa.saves,                0)                AS saves,
        COALESCE(pa.tackles,              0)                AS tackles,
        COALESCE(pa.interceptions,        0)                AS interceptions,
        COALESCE(pa.clearances,           0)                AS clearances,
        COALESCE(pa.total_passes,         0)                AS total_passes,
        COALESCE(pa.passes_accurate,      0)                AS passes_accurate,
        COALESCE(pa.key_passes,           0)                AS key_passes,
        COALESCE(pa.big_chances_created,  0)                AS big_chances_created,
        COALESCE(pa.woodwork_hits,        0)                AS woodwork_hits,
        COALESCE(pa.crosses_total,        0)                AS crosses_total
    FROM superligaen.gold.fct_team_matches   f
    JOIN superligaen.gold.dim_date           d   ON d.date_sk       = f.date_sk
    JOIN superligaen.gold.dim_match          m   ON m.match_sk      = f.match_sk
    JOIN superligaen.gold.dim_team           t   ON t.team_sk       = f.team_sk
    JOIN superligaen.gold.dim_team_side      ts  ON ts.team_side_sk = f.team_side_sk
    JOIN superligaen.gold.dim_referee        ref ON ref.referee_sk  = f.referee_sk
    LEFT JOIN player_agg                     pa  ON pa.match_sk     = f.match_sk
                                               AND pa.team_sk       = f.team_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
)
SELECT
    match_id,
    max(match_date)                                                                                AS match_date,
    max(season)                                                                                    AS season,
    max(match_round_number)                                                                        AS match_round_number,
    max(match_round_name)                                                                          AS match_round_name,
    max(match_name)                                                                                AS match_name,
    max(score)                                                                                     AS score,
    max(referee_name)                                                                              AS referee_name,
    max(case when team_side = 'Home' then team_name       end)                                    AS home_team,
    max(case when team_side = 'Away' then team_name       end)                                    AS away_team,
    max(case when team_side = 'Home' then team_short_name end)                                    AS home_team_short,
    max(case when team_side = 'Away' then team_short_name end)                                    AS away_team_short,
    max(case when team_side = 'Home' then goals_scored    end)                                    AS home_goals,
    max(case when team_side = 'Away' then goals_scored    end)                                    AS away_goals,
    max(case when team_side = 'Home' then total_shots     end)                                    AS home_total_shots,
    max(case when team_side = 'Away' then total_shots     end)                                    AS away_total_shots,
    max(case when team_side = 'Home' then shots_on_goal   end)                                    AS home_sog,
    max(case when team_side = 'Away' then shots_on_goal   end)                                    AS away_sog,
    max(case when team_side = 'Home' then big_chances_created end)                                AS home_big_chances,
    max(case when team_side = 'Away' then big_chances_created end)                                AS away_big_chances,
    max(case when team_side = 'Home' then woodwork_hits   end)                                    AS home_woodwork,
    max(case when team_side = 'Away' then woodwork_hits   end)                                    AS away_woodwork,
    max(case when team_side = 'Home' then possession_pct  end)                                    AS home_possession,
    max(case when team_side = 'Away' then possession_pct  end)                                    AS away_possession,
    round(max(case when team_side = 'Home' then passes_accurate end)::double
        / nullif(max(case when team_side = 'Home' then total_passes end), 0) * 100, 1)            AS home_pass_accuracy,
    round(max(case when team_side = 'Away' then passes_accurate end)::double
        / nullif(max(case when team_side = 'Away' then total_passes end), 0) * 100, 1)            AS away_pass_accuracy,
    max(case when team_side = 'Home' then key_passes      end)                                    AS home_key_passes,
    max(case when team_side = 'Away' then key_passes      end)                                    AS away_key_passes,
    max(case when team_side = 'Home' then crosses_total   end)                                    AS home_crosses,
    max(case when team_side = 'Away' then crosses_total   end)                                    AS away_crosses,
    max(case when team_side = 'Home' then corner_kicks    end)                                    AS home_corners,
    max(case when team_side = 'Away' then corner_kicks    end)                                    AS away_corners,
    max(case when team_side = 'Home' then tackles         end)                                    AS home_tackles,
    max(case when team_side = 'Away' then tackles         end)                                    AS away_tackles,
    max(case when team_side = 'Home' then interceptions   end)                                    AS home_interceptions,
    max(case when team_side = 'Away' then interceptions   end)                                    AS away_interceptions,
    max(case when team_side = 'Home' then clearances      end)                                    AS home_clearances,
    max(case when team_side = 'Away' then clearances      end)                                    AS away_clearances,
    max(case when team_side = 'Home' then saves           end)                                    AS home_saves,
    max(case when team_side = 'Away' then saves           end)                                    AS away_saves,
    max(case when team_side = 'Home' then fouls           end)                                    AS home_fouls,
    max(case when team_side = 'Away' then fouls           end)                                    AS away_fouls,
    max(case when team_side = 'Home' then yellow_cards    end)                                    AS home_yc,
    max(case when team_side = 'Away' then yellow_cards    end)                                    AS away_yc,
    max(case when team_side = 'Home' then red_cards       end)                                    AS home_rc,
    max(case when team_side = 'Away' then red_cards       end)                                    AS away_rc
FROM base
GROUP BY match_id
