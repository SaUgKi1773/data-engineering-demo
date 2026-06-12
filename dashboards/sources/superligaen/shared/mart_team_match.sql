WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target) AS shots_on_goal,
        SUM(shots_total)     AS total_shots,
        SUM(passes_total)    AS total_passes,
        SUM(passes_accurate) AS passes_accurate
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
per_match AS (
    SELECT
        m.match_id,
        d.date                                  AS match_date,
        d.season,
        d.day_name,
        dt.period_of_day,
        m.match_round_number,
        m.match_round_name,
        m.match_short_name,
        m.match_result                          AS score,
        t.team_name,
        t.team_short_name,
        t.team_logo,
        ot.opponent_team_name,
        ot.opponent_team_short_name,
        ts.team_side,
        df.formation,
        r.match_result                          AS result,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        f.ball_possession_pct                   AS possession_pct,
        f.yellow_cards,
        COALESCE(pa.shots_on_goal, 0)           AS shots_on_goal,
        COALESCE(pa.total_shots, 0)             AS total_shots,
        COALESCE(pa.total_passes, 0)            AS total_passes,
        COALESCE(pa.passes_accurate, 0)         AS passes_accurate,
        CASE
            WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Championship Group'
            WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Relegation Group'
            ELSE 'Regular Season'
        END                                     AS standings_type
    FROM superligaen.gold.fct_team_matches    f
    JOIN superligaen.gold.dim_date            d   ON d.date_sk           = f.date_sk
    JOIN superligaen.gold.dim_match           m   ON m.match_sk          = f.match_sk
    JOIN superligaen.gold.dim_team            t   ON t.team_sk           = f.team_sk
    JOIN superligaen.gold.dim_opponent_team   ot  ON ot.opponent_team_sk = f.opponent_team_sk
    JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk   = f.match_result_sk
    JOIN superligaen.gold.dim_team_side       ts  ON ts.team_side_sk     = f.team_side_sk
    JOIN superligaen.gold.dim_formation       df  ON df.formation_sk     = f.formation_sk
    JOIN superligaen.gold.dim_time            dt  ON dt.time_sk          = f.time_sk
    LEFT JOIN player_agg                      pa  ON pa.match_sk         = f.match_sk
                                               AND pa.team_sk            = f.team_sk
    WHERE d.season >= '2020/21'
)
SELECT * FROM per_match
