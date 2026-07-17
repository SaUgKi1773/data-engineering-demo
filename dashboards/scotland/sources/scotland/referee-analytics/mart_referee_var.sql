-- VAR involvement per referee: one row per season and referee.
-- Reviews without a categorized outcome in the source stay in the total but
-- not in the breakdown columns, so the breakdown may sum to less than total.
WITH var_events AS (
    SELECT
        d.season_scotland AS season,
        ref.referee_common_name AS referee_name,
        et.event_type_name,
        et.event_sub_type_name
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date             d   ON d.date_sk              = f.date_sk
    JOIN superligaen.gold.dim_referee          ref ON ref.referee_sk         = f.referee_sk
    JOIN superligaen.gold.dim_match_event_type et  ON et.match_event_type_sk = f.match_event_type_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
      AND f.referee_sk > 0
      AND et.event_group = 'VAR'
),
referee_matches AS (
    SELECT d.season_scotland AS season, ref.referee_common_name AS referee_name, COUNT(DISTINCT f.match_sk) AS matches
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date    d   ON d.date_sk      = f.date_sk
    JOIN superligaen.gold.dim_referee ref ON ref.referee_sk = f.referee_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
      AND f.referee_sk > 0
    GROUP BY 1, 2
)
SELECT
    rm.season,
    rm.referee_name,
    rm.matches,
    COUNT(ve.event_type_name)                                                       AS var_reviews,
    COUNT(*) FILTER (WHERE ve.event_sub_type_name = 'Goal Disallowed')              AS goals_disallowed,
    COUNT(*) FILTER (WHERE ve.event_sub_type_name = 'Goal Awarded')                 AS goals_awarded,
    COUNT(*) FILTER (WHERE ve.event_sub_type_name = 'Penalty Confirmed')            AS penalties_confirmed,
    COUNT(*) FILTER (WHERE ve.event_sub_type_name = 'Penalty Cancelled')            AS penalties_cancelled,
    COUNT(*) FILTER (WHERE ve.event_type_name     = 'VAR Card Review')              AS card_reviews,
    ROUND(COUNT(ve.event_type_name)::double / rm.matches, 2)                        AS var_per_match
FROM referee_matches rm
LEFT JOIN var_events ve ON ve.season = rm.season AND ve.referee_name = rm.referee_name
GROUP BY rm.season, rm.referee_name, rm.matches
ORDER BY rm.season DESC, var_reviews DESC
