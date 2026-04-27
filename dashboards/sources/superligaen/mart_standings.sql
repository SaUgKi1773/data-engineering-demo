WITH base AS (
    SELECT
        t.team_name,
        f.team_sk,
        m.season,
        m.match_round_type,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned
    FROM superligaen_dev.gold.fct_match_results f
    JOIN superligaen_dev.gold.dim_match        m  ON m.match_sk        = f.match_sk
    JOIN superligaen_dev.gold.dim_team         t  ON t.team_sk         = f.team_sk
    JOIN superligaen_dev.gold.dim_match_result r  ON r.match_result_sk = f.match_result_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.match_result_sk > 0
),
team_groups AS (
    SELECT
        team_sk,
        season,
        CASE
            WHEN MAX(CASE WHEN match_round_type = 'Championship' THEN 1 ELSE 0 END) = 1
                THEN 'Championship Group'
            WHEN MAX(CASE WHEN match_round_type = 'Relegation'   THEN 1 ELSE 0 END) = 1
                THEN 'Relegation Group'
            ELSE 'Regular Season'
        END AS standings_type
    FROM base
    GROUP BY team_sk, season
),
regular_stats AS (
    SELECT
        b.team_name, b.season,
        'Regular Season'                                       AS standings_type,
        COUNT(*)                                               AS gp,
        SUM(CASE WHEN b.points_earned = 3 THEN 1 ELSE 0 END) AS w,
        SUM(CASE WHEN b.points_earned = 1 THEN 1 ELSE 0 END) AS d,
        SUM(CASE WHEN b.points_earned = 0 THEN 1 ELSE 0 END) AS l,
        SUM(b.goals_scored)                                   AS gf,
        SUM(b.goals_conceded)                                 AS ga,
        SUM(b.goals_scored) - SUM(b.goals_conceded)          AS gd,
        SUM(b.points_earned)                                  AS pts
    FROM base b
    WHERE b.match_round_type = 'Regular Season'
    GROUP BY b.team_name, b.season
),
playoff_stats AS (
    SELECT
        b.team_name, b.season,
        tg.standings_type,
        COUNT(*)                                               AS gp,
        SUM(CASE WHEN b.points_earned = 3 THEN 1 ELSE 0 END) AS w,
        SUM(CASE WHEN b.points_earned = 1 THEN 1 ELSE 0 END) AS d,
        SUM(CASE WHEN b.points_earned = 0 THEN 1 ELSE 0 END) AS l,
        SUM(b.goals_scored)                                   AS gf,
        SUM(b.goals_conceded)                                 AS ga,
        SUM(b.goals_scored) - SUM(b.goals_conceded)          AS gd,
        SUM(b.points_earned)                                  AS pts
    FROM base b
    JOIN team_groups tg ON tg.team_sk = b.team_sk AND tg.season = b.season
    WHERE tg.standings_type IN ('Championship Group', 'Relegation Group')
    GROUP BY b.team_name, b.season, tg.standings_type
)
SELECT * FROM regular_stats
UNION ALL
SELECT * FROM playoff_stats
