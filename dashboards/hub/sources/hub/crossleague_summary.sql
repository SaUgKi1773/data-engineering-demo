-- Headline figures for the cross-league platform card.
--
-- Deliberately NOT group_stats. That counts everything the warehouse holds,
-- all-time; the cross-league site covers 2020 onward and regular-league
-- fixtures only. Reusing it would print a match count on the hub that the site
-- itself contradicts the moment you click through, so this mirrors the site's
-- own scope instead — the same filters mart_club_day applies over there.
SELECT
    COUNT(DISTINCT dl.league_id)  AS leagues,
    COUNT(DISTINCT f.match_sk)    AS matches,
    SUM(f.goals_scored)           AS goals
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_league        dl ON dl.league_sk      = f.league_sk
JOIN superligaen.gold.dim_date          d  ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match         m  ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_match_result  r  ON r.match_result_sk = f.match_result_sk
WHERE dl.league_id IS NOT NULL
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND m.match_type = 'Regular League'
  AND d.year >= 2020
