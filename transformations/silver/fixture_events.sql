-- Group 3 | refresh: incremental date-window (kick_off)
-- One row per match event. kick_off joined from fixtures for windowed filtering.
SELECT
    e.fixture_id,
    (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ  AS kick_off,
    (f.raw_json->>'$.league.id')::INTEGER          AS league_id,
    (f.raw_json->>'$.league.season')::INTEGER      AS season,
    (ev->>'$.time.elapsed')::INTEGER               AS time_elapsed,
    (ev->>'$.time.extra')::INTEGER                 AS time_extra,
    (ev->>'$.team.id')::INTEGER                    AS team_id,
    ev->>'$.team.name'                             AS team_name,
    ev->>'$.team.logo'                             AS team_logo,
    (ev->>'$.player.id')::INTEGER                  AS player_id,
    ev->>'$.player.name'                           AS player_name,
    (ev->>'$.assist.id')::INTEGER                  AS assist_player_id,
    ev->>'$.assist.name'                           AS assist_player_name,
    ev->>'$.type'                                  AS event_type,
    ev->>'$.detail'                                AS event_detail,
    ev->>'$.comments'                              AS comments,
    e.ingested_at
FROM {db}.bronze.api_football__fixture_events e
JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
UNNEST(e.raw_json::JSON[]) AS t(ev)
