SELECT
    m.match_id,
    d.date          AS match_date,
    d.season,
    d.is_current_season,
    m.match_round_type,
    m.match_round_number,
    t.team_name,
    t.team_short_name,
    t.team_logo,
    r.match_result  AS result,
    f.goals_scored,
    f.goals_conceded,
    f.points_earned,
    CASE
        WHEN MAX(CASE WHEN m.match_round_type = 'Championship Round' THEN 1 ELSE 0 END)
             OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Championship Group'
        WHEN MAX(CASE WHEN m.match_round_type = 'Relegation Round'   THEN 1 ELSE 0 END)
             OVER (PARTITION BY f.team_sk, d.season) = 1 THEN 'Relegation Group'
        ELSE 'Regular Season'
    END             AS standings_type
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date           d  ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match          m  ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_team           t  ON t.team_sk         = f.team_sk
JOIN superligaen.gold.dim_match_result   r  ON r.match_result_sk = f.match_result_sk
WHERE d.season >= '2020/21'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
