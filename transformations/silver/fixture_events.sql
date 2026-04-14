-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixture_events (
    fixture_id         INTEGER,
    kick_off           TIMESTAMPTZ,
    league_id          INTEGER,
    season             INTEGER,
    time_elapsed       INTEGER,
    time_extra         INTEGER,
    team_id            INTEGER,
    team_name          VARCHAR,
    team_logo          VARCHAR,
    player_id          INTEGER,
    player_name        VARCHAR,
    assist_player_id   INTEGER,
    assist_player_name VARCHAR,
    event_type         VARCHAR,
    event_detail       VARCHAR,
    comments           VARCHAR,
    ingested_at        TIMESTAMPTZ
);

DELETE FROM {db}.silver.fixture_events WHERE {delete_filter};

INSERT INTO {db}.silver.fixture_events
SELECT * FROM (
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
) _src WHERE {insert_filter};
