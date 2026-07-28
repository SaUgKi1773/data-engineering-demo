-- One row per league: identity + latest completed-or-running season KPIs.
-- Mirrors each site's mart_home_summary (latest season WITH results, leader =
-- top of the Championship Group first, then points / GD / GF), generalized
-- across leagues via the per-country dim_date season columns and the
-- conformed match_round_type vocabulary.
WITH matches AS (
    SELECT
        dl.league_id,
        CASE dl.league_id
            WHEN 271    THEN d.season_denmark
            WHEN 501    THEN d.season_scotland
            WHEN 223746 THEN d.season_mexico
            WHEN 173537 THEN d.season_turkey
            WHEN 119924 THEN d.season_spain
        END                                           AS season,
        CASE dl.league_id
            WHEN 271    THEN d.is_current_season_denmark
            WHEN 501    THEN d.is_current_season_scotland
            WHEN 223746 THEN d.is_current_season_mexico
            WHEN 173537 THEN d.is_current_season_turkey
            WHEN 119924 THEN d.is_current_season_spain
        END                                           AS season_is_live,
        d.date,
        m.match_id,
        f.team_sk,
        t.team_name,
        t.team_short_name,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        CASE
            WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END)
                 OVER (PARTITION BY dl.league_id, f.team_sk,
                       CASE dl.league_id WHEN 271 THEN d.season_denmark WHEN 501 THEN d.season_scotland WHEN 223746 THEN d.season_mexico WHEN 173537 THEN d.season_turkey WHEN 119924 THEN d.season_spain END) = 1
            THEN 1 ELSE 2
        END                                           AS group_rank,
        f.points_earned IS NOT NULL                   AS counts_towards_table
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_league        dl ON dl.league_sk       = f.league_sk
    JOIN superligaen.gold.dim_date          d  ON d.date_sk          = f.date_sk
    JOIN superligaen.gold.dim_match         m  ON m.match_sk         = f.match_sk
    JOIN superligaen.gold.dim_team          t  ON t.team_sk          = f.team_sk
    JOIN superligaen.gold.dim_match_result  r  ON r.match_result_sk  = f.match_result_sk
    -- Roster comes from the dimension, minus its two NULL-id sentinel rows.
    -- A league with no CASE arm above gets a NULL season and drops out at the
    -- `latest` join below, so it cannot reach the shelf as a broken card.
    WHERE dl.league_id IS NOT NULL
      AND r.match_result IN ('Win', 'Draw', 'Loss')
),
-- MAX(season) picks the latest one lexically, which is also the latest one
-- chronologically for every league here. Worth stating for Mexico, where a
-- season year holds two tournaments: 'Apertura' sorts before 'Clausura' and
-- also runs before it, so the ordering is right by luck of the alphabet.
latest AS (
    SELECT league_id, MAX(season) AS season
    FROM matches
    GROUP BY league_id
),
cur AS (
    SELECT m.*
    FROM matches m
    JOIN latest l ON l.league_id = m.league_id AND l.season = m.season
),
leader AS (
    SELECT
        league_id,
        team_name,
        team_short_name,
        SUM(points_earned) AS pts,
        ROW_NUMBER() OVER (
            PARTITION BY league_id
            ORDER BY MIN(group_rank),
                     SUM(points_earned)                    DESC,
                     SUM(goals_scored) - SUM(goals_conceded) DESC,
                     SUM(goals_scored)                     DESC
        ) AS rn
    FROM cur
    -- Only matches that put points on a table. Denmark's and Scotland's
    -- playoff rounds do; Mexico's liguilla does not, and its rows carry NULL
    -- points rather than zero. Without this the knockout goals would skew the
    -- goal-difference tiebreak in a table those matches never touched.
    WHERE counts_towards_table
    GROUP BY league_id, team_name, team_short_name
)
SELECT
    dl.league_id,
    dl.league_name,
    dl.league_logo,
    dl.league_country,
    dl.league_country_flag,
    c.season,
    BOOL_OR(c.season_is_live)         AS season_is_live,
    COUNT(DISTINCT c.match_id)        AS total_matches,
    SUM(c.goals_scored)               AS total_goals,
    COUNT(DISTINCT c.team_name)       AS total_teams,
    MAX(ld.team_name)                 AS leader_name,
    MAX(ld.pts)                       AS leader_pts
FROM cur c
JOIN superligaen.gold.dim_league dl ON dl.league_id = c.league_id
JOIN leader ld ON ld.league_id = c.league_id AND ld.rn = 1
GROUP BY dl.league_id, dl.league_name, dl.league_logo, dl.league_country, dl.league_country_flag, c.season
ORDER BY dl.league_id
