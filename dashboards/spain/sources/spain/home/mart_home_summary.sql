-- Headline numbers for the latest La Liga season, on the same column
-- contract as the Danish and Scottish mart_home_summary so the home page
-- stays a twin of theirs.
--
-- La Liga is a plain double round-robin: one table, no split, no
-- play-off, so the club top of the table is the leader while the season runs
-- and the champion once it has ended. That is the whole of the phase logic
-- here, and the reason this model is a fraction of the Mexican one.
WITH matches AS (
    SELECT
        d.season_spain            AS season,
        d.is_current_season_spain AS season_is_live,
        d.date,
        m.match_id,
        t.team_name,
        t.team_short_name,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_date          d ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match         m ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_team          t ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match_result  r ON r.match_result_sk = f.match_result_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 119924)
      AND d.season_spain IS NOT NULL
),
-- The most recent season by match date rather than by name: a new season's
-- fixtures are published months before its first match, and the site should
-- keep showing the completed one until it actually kicks off.
latest_season AS (
    SELECT season
    FROM matches
    GROUP BY season
    ORDER BY MAX(date) DESC
    LIMIT 1
),
current_matches AS (
    SELECT m.* FROM matches m JOIN latest_season ls ON m.season = ls.season
),
leader AS (
    SELECT
        team_name,
        team_short_name,
        SUM(points_earned)                      AS pts,
        SUM(goals_scored) - SUM(goals_conceded) AS gd,
        SUM(goals_scored)                       AS gf
    FROM current_matches
    GROUP BY team_name, team_short_name
    ORDER BY pts DESC, gd DESC, gf DESC
    LIMIT 1
)
SELECT
    ls.season,
    BOOL_OR(m.season_is_live)  AS season_is_live,
    COUNT(DISTINCT m.match_id) AS total_matches,
    SUM(m.goals_scored)        AS total_goals,
    COUNT(DISTINCT m.team_name) AS total_teams,
    MAX(l.team_name)           AS leader_name,
    MAX(l.team_short_name)     AS leader_short,
    MAX(l.pts)                 AS leader_pts
FROM current_matches m
CROSS JOIN latest_season ls
CROSS JOIN leader l
GROUP BY ls.season
