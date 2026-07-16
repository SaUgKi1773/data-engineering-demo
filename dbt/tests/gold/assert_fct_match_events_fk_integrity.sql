-- Every event must resolve to a real match, date, league and event type.
-- (team/player/referee/minute may legitimately be Unknown: VAR events have no
-- player, and contradictory source periods resolve to the Unknown minute.)
-- An unresolved event_type_sk means the provider introduced a brand-new event
-- type that dim_event_type must be extended with.
SELECT 'match_sk'      AS fk, event_type_sk, match_minute_sk FROM {{ ref('fct_match_events') }}
WHERE match_sk = -1
UNION ALL
SELECT 'date_sk',             event_type_sk, match_minute_sk FROM {{ ref('fct_match_events') }}
WHERE date_sk = -1
UNION ALL
SELECT 'league_sk',           event_type_sk, match_minute_sk FROM {{ ref('fct_match_events') }}
WHERE league_sk = -1
UNION ALL
SELECT 'event_type_sk',       event_type_sk, match_minute_sk FROM {{ ref('fct_match_events') }}
WHERE event_type_sk = -1
