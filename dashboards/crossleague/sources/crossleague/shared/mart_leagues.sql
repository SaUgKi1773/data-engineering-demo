-- League directory: identity, colour and the link out to each league's own site.
WITH played AS (
    SELECT f.league_sk, f.match_sk, f.goals_scored, d.date, d.year
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date         d ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match        m ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE r.match_result IN ('Win','Draw','Loss') AND m.match_type = 'Regular League' AND d.year >= 2020
)
SELECT
    l.league_name,
    l.league_country,
    CASE l.league_country
        WHEN 'Denmark' THEN 'DEN' WHEN 'Scotland' THEN 'SCO' WHEN 'Spain' THEN 'ESP'
        WHEN 'Turkey'  THEN 'TUR' WHEN 'Mexico'   THEN 'MEX' END          AS code,
    l.league_country_flag,
    l.league_logo,
    -- Fixed per league, assigned alphabetically, never by rank.
    CASE l.league_name
        WHEN 'La Liga' THEN '#2a78d6' WHEN 'Liga MX' THEN '#eb6834'
        WHEN 'Premiership' THEN '#1baf7a' WHEN 'Superliga' THEN '#eda100'
        WHEN 'Süper Lig' THEN '#e87ba4' END                          AS colour,
    CASE l.league_name
        WHEN 'Superliga'   THEN 'https://superligaanalytics.vercel.app'
        WHEN 'Premiership' THEN 'https://scottishpremiershipanalytics.vercel.app'
        WHEN 'La Liga'     THEN 'https://spanishlaligaanalytics.vercel.app'
        WHEN 'Süper Lig'   THEN 'https://turkishsuperliganalytics.vercel.app'
        WHEN 'Liga MX'     THEN 'https://mexicanligamxanalytics.vercel.app' END AS site_url,
    COUNT(DISTINCT p.match_sk)                                       AS matches,
    ROUND(1.0 * SUM(p.goals_scored) / NULLIF(COUNT(DISTINCT p.match_sk),0), 2)::DOUBLE AS goals_per_match,
    MIN(p.year)                                                      AS first_year,
    MAX(p.date)                                                      AS last_match
FROM played p JOIN superligaen.gold.dim_league l ON l.league_sk = p.league_sk
GROUP BY 1,2,3,4,5,6,7 ORDER BY matches DESC
