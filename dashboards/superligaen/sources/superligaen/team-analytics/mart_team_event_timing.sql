-- Per-team event timing: one row per season, team and 15-minute bucket.
-- goals_for counts scoring events credited to the team (own goals are already
-- attributed to the awarded team in the warehouse); goals_against counts
-- scoring events credited to the opponent.
WITH events AS (
    SELECT
        d.season,
        mm.minute_bucket,
        mm.minute_bucket_sort,
        et.event_group,
        f.team_sk,
        f.opponent_team_sk,
        f.match_sk
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date             d  ON d.date_sk              = f.date_sk
    JOIN superligaen.gold.dim_match_minute     mm ON mm.match_minute_sk     = f.match_minute_sk
    JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = f.match_event_type_sk
    WHERE d.season >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
      AND mm.match_minute_sk > 0
      AND mm.minute_bucket != 'Extra Time'
),
team_matches AS (
    SELECT season, team_sk, COUNT(DISTINCT match_sk) AS matches
    FROM (
        SELECT season, team_sk, match_sk FROM events WHERE team_sk > 0
        UNION ALL
        SELECT season, opponent_team_sk, match_sk FROM events WHERE opponent_team_sk > 0
    )
    GROUP BY season, team_sk
),
buckets AS (
    SELECT DISTINCT season, minute_bucket, minute_bucket_sort FROM events
),
-- Cross join so every team shows every bucket, even ones where nothing happened
team_buckets AS (
    SELECT tm.season, tm.team_sk, tm.matches, b.minute_bucket, b.minute_bucket_sort
    FROM team_matches tm
    JOIN buckets b ON b.season = tm.season
)
SELECT
    tb.season,
    t.team_name,
    t.team_logo,
    tb.minute_bucket,
    tb.minute_bucket_sort,
    tb.matches,
    COUNT(*) FILTER (WHERE e.event_group = 'Goal'         AND e.team_sk          = tb.team_sk) AS goals_for,
    COUNT(*) FILTER (WHERE e.event_group = 'Goal'         AND e.opponent_team_sk = tb.team_sk) AS goals_against,
    COUNT(*) FILTER (WHERE e.event_group = 'Card'         AND e.team_sk          = tb.team_sk) AS cards,
    COUNT(*) FILTER (WHERE e.event_group = 'Substitution' AND e.team_sk          = tb.team_sk) AS substitutions
FROM team_buckets tb
JOIN superligaen.gold.dim_team t ON t.team_sk = tb.team_sk
LEFT JOIN events e
    ON  e.season           = tb.season
    AND e.minute_bucket    = tb.minute_bucket
    AND (e.team_sk = tb.team_sk OR e.opponent_team_sk = tb.team_sk)
GROUP BY tb.season, t.team_name, t.team_logo, tb.minute_bucket, tb.minute_bucket_sort, tb.matches
ORDER BY tb.season DESC, t.team_name, tb.minute_bucket_sort
