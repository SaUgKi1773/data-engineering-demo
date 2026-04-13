-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
-- Starters and substitutes are unioned with an is_starter flag.
-- grid (tactical position) is NULL for substitutes.
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixture_lineups AS
SELECT * FROM (
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        p->>'$.player.grid'                           AS player_grid,
        true                                          AS is_starter,
        l.ingested_at
    FROM {db}.bronze.api_football__fixture_lineups l
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.startXI')::JSON[]) AS t2(p)
    UNION ALL
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        NULL                                          AS player_grid,
        false                                         AS is_starter,
        l.ingested_at
    FROM {db}.bronze.api_football__fixture_lineups l
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.substitutes')::JSON[]) AS t2(p)
) _src WHERE 1=0;

DELETE FROM {db}.silver.fixture_lineups WHERE {delete_filter};

INSERT INTO {db}.silver.fixture_lineups
SELECT * FROM (
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        p->>'$.player.grid'                           AS player_grid,
        true                                          AS is_starter,
        l.ingested_at
    FROM {db}.bronze.api_football__fixture_lineups l
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.startXI')::JSON[]) AS t2(p)
    UNION ALL
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        NULL                                          AS player_grid,
        false                                         AS is_starter,
        l.ingested_at
    FROM {db}.bronze.api_football__fixture_lineups l
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.substitutes')::JSON[]) AS t2(p)
) _src WHERE {insert_filter};
