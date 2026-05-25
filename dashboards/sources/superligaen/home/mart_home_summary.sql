WITH matches AS (
    SELECT
        d.season,
        d.date,
        m.match_id,
        t.team_name,
        t.team_short_name,
        r.match_result,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        CASE
            WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Championship Group'
            WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END)
                 OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Relegation Group'
            ELSE 'Regular Season'
        END AS standings_type
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_date           d  ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match          m  ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_team           t  ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match_result   r  ON r.match_result_sk = f.match_result_sk
    WHERE m.match_type = 'Group Stage'
      AND r.match_result IN ('Win', 'Draw', 'Loss')
),
latest_season AS (
    SELECT MAX(season) AS season FROM matches
),
team_pts AS (
    SELECT
        m.team_name,
        m.team_short_name,
        SUM(m.points_earned)                          AS pts,
        SUM(m.goals_scored) - SUM(m.goals_conceded)  AS gd,
        SUM(m.goals_scored)                           AS gf
    FROM matches m
    JOIN latest_season ls ON m.season = ls.season
    GROUP BY m.team_name, m.team_short_name, m.standings_type
    ORDER BY
        CASE m.standings_type
            WHEN 'Championship Group' THEN 1
            WHEN 'Relegation Group'   THEN 2
            ELSE                           3
        END,
        pts DESC, gd DESC, gf DESC
    LIMIT 1
)
SELECT
    ls.season,
    MAX(m.date)::VARCHAR                             AS season_end,
    COUNT(DISTINCT m.match_id)                       AS total_matches,
    SUM(m.goals_scored)                              AS total_goals,
    COUNT(DISTINCT m.team_name)                      AS total_teams,
    MAX(tp.team_name)                                AS leader_name,
    MAX(tp.team_short_name)                          AS leader_short,
    MAX(tp.pts)                                      AS leader_pts
FROM matches m
JOIN latest_season ls ON m.season = ls.season
CROSS JOIN team_pts tp
GROUP BY ls.season
