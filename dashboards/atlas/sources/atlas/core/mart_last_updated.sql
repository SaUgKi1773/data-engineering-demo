-- Freshness stamp for the footer.
SELECT MAX(d.date) AS last_match, COUNT(DISTINCT f.match_sk) AS matches
FROM superligaen.gold.fct_team_matches f
JOIN superligaen.gold.dim_date d ON d.date_sk = f.date_sk
JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
WHERE r.match_result IN ('Win','Draw','Loss') AND d.year >= 2020
