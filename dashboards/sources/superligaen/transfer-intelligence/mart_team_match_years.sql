-- Teams with a league-match record per calendar year. Drives the year-scoped
-- team filter: only clubs that actually played in the selected year(s) appear.
SELECT DISTINCT
    t.team_name,
    d.year AS match_year
FROM superligaen.gold.fct_team_matches f
JOIN superligaen.gold.dim_team t ON t.team_sk = f.team_sk
JOIN superligaen.gold.dim_date d ON d.date_sk = f.date_sk
WHERE f.team_sk > 0
  AND d.year >= 2020
