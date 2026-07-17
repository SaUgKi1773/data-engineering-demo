-- League-wide event timing: one row per season and 15-minute bucket.
-- Extra Time is excluded: league group-stage matches effectively never have it
-- and it would render as a permanently empty ninth bar.
WITH events AS (
    SELECT
        d.season_scotland AS season,
        mm.minute_bucket,
        mm.minute_bucket_sort,
        et.event_group,
        f.match_sk
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date             d  ON d.date_sk             = f.date_sk
    JOIN superligaen.gold.dim_match_minute     mm ON mm.match_minute_sk    = f.match_minute_sk
    JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = f.match_event_type_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
      AND mm.match_minute_sk > 0
      AND mm.minute_bucket != 'Extra Time'
),
season_matches AS (
    SELECT season, COUNT(DISTINCT match_sk) AS matches
    FROM events
    GROUP BY season
)
SELECT
    e.season,
    e.minute_bucket,
    e.minute_bucket_sort,
    COUNT(*) FILTER (WHERE e.event_group = 'Goal')         AS goals,
    COUNT(*) FILTER (WHERE e.event_group = 'Card')         AS cards,
    COUNT(*) FILTER (WHERE e.event_group = 'Substitution') AS substitutions,
    ROUND(COUNT(*) FILTER (WHERE e.event_group = 'Goal')::double         / sm.matches, 2) AS goals_per_match,
    ROUND(COUNT(*) FILTER (WHERE e.event_group = 'Card')::double         / sm.matches, 2) AS cards_per_match,
    ROUND(COUNT(*) FILTER (WHERE e.event_group = 'Substitution')::double / sm.matches, 2) AS subs_per_match
FROM events e
JOIN season_matches sm ON sm.season = e.season
GROUP BY e.season, e.minute_bucket, e.minute_bucket_sort, sm.matches
ORDER BY e.season DESC, e.minute_bucket_sort
