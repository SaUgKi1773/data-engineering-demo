-- One row per match: the raw material for "biggest win", "most goals" and
-- "comeback" lists. Half-time goals are NULL where a provider published
-- neither a half-time score nor a timeline, so a comeback is only counted
-- where the half-time state is actually known.
WITH sides AS (
    SELECT
        f.match_sk, l.league_name, d.date AS match_date, d.year AS calendar_year,
        ts.team_side, t.team_name, f.goals_scored, f.goals_ht_scored, r.match_result
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_league       l  ON l.league_sk       = f.league_sk
    JOIN superligaen.gold.dim_date         d  ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_team         t  ON t.team_sk         = f.team_sk
    JOIN superligaen.gold.dim_match        m  ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result r  ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_team_side    ts ON ts.team_side_sk   = f.team_side_sk
    WHERE r.match_result IN ('Win','Draw','Loss') AND m.match_type = 'Regular League'
      AND d.year >= 2020 AND ts.team_side IN ('Home','Away')
)
SELECT
    match_sk,
    league_name, match_date, calendar_year,
    MAX(team_name)    FILTER (WHERE team_side = 'Home')     AS home_team,
    MAX(team_name)    FILTER (WHERE team_side = 'Away')     AS away_team,
    MAX(goals_scored) FILTER (WHERE team_side = 'Home')     AS home_goals,
    MAX(goals_scored) FILTER (WHERE team_side = 'Away')     AS away_goals,
    SUM(goals_scored)                                       AS total_goals,
    ABS(MAX(goals_scored) FILTER (WHERE team_side = 'Home')
      - MAX(goals_scored) FILTER (WHERE team_side = 'Away')) AS winning_margin,
    MAX(goals_ht_scored) FILTER (WHERE team_side = 'Home')  AS home_goals_ht,
    MAX(goals_ht_scored) FILTER (WHERE team_side = 'Away')  AS away_goals_ht,
    -- A side trailing at the break that finished in front.
    CASE
        WHEN MAX(goals_ht_scored) FILTER (WHERE team_side='Home') IS NULL
          OR MAX(goals_ht_scored) FILTER (WHERE team_side='Away') IS NULL THEN NULL
        WHEN MAX(goals_ht_scored) FILTER (WHERE team_side='Home') < MAX(goals_ht_scored) FILTER (WHERE team_side='Away')
         AND MAX(goals_scored)    FILTER (WHERE team_side='Home') > MAX(goals_scored)    FILTER (WHERE team_side='Away')
            THEN MAX(team_name) FILTER (WHERE team_side='Home')
        WHEN MAX(goals_ht_scored) FILTER (WHERE team_side='Away') < MAX(goals_ht_scored) FILTER (WHERE team_side='Home')
         AND MAX(goals_scored)    FILTER (WHERE team_side='Away') > MAX(goals_scored)    FILTER (WHERE team_side='Home')
            THEN MAX(team_name) FILTER (WHERE team_side='Away')
    END                                                     AS comeback_by
FROM sides
GROUP BY 1,2,3,4
