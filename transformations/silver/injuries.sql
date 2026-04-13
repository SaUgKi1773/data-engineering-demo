-- Group 2 | refresh: season-scoped
-- {delete_filter} / {insert_filter} examples:
--   season-scoped : league_id = 119 AND season = 2025
--   full reload   : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.injuries AS
SELECT * FROM (
    SELECT
        season,
        league_id,
        (elem->>'$.player.id')::INTEGER          AS player_id,
        elem->>'$.player.name'                   AS player_name,
        elem->>'$.player.photo'                  AS player_photo,
        elem->>'$.player.type'                   AS injury_type,
        elem->>'$.player.reason'                 AS injury_reason,
        (elem->>'$.team.id')::INTEGER            AS team_id,
        elem->>'$.team.name'                     AS team_name,
        elem->>'$.team.logo'                     AS team_logo,
        (elem->>'$.fixture.id')::INTEGER         AS fixture_id,
        elem->>'$.fixture.timezone'              AS fixture_timezone,
        (elem->>'$.fixture.date')::TIMESTAMPTZ   AS fixture_date,
        (elem->>'$.fixture.timestamp')::BIGINT   AS fixture_timestamp,
        (elem->>'$.league.id')::INTEGER          AS league_id_json,
        (elem->>'$.league.season')::INTEGER      AS season_json,
        elem->>'$.league.name'                   AS league_name,
        elem->>'$.league.country'                AS league_country,
        elem->>'$.league.logo'                   AS league_logo,
        elem->>'$.league.flag'                   AS league_flag,
        ingested_at
    FROM {db}.bronze.api_football__injuries,
    UNNEST(raw_json::JSON[]) AS t(elem)
) _src WHERE 1=0;

DELETE FROM {db}.silver.injuries WHERE {delete_filter};

INSERT INTO {db}.silver.injuries
SELECT * FROM (
    SELECT
        season,
        league_id,
        (elem->>'$.player.id')::INTEGER          AS player_id,
        elem->>'$.player.name'                   AS player_name,
        elem->>'$.player.photo'                  AS player_photo,
        elem->>'$.player.type'                   AS injury_type,
        elem->>'$.player.reason'                 AS injury_reason,
        (elem->>'$.team.id')::INTEGER            AS team_id,
        elem->>'$.team.name'                     AS team_name,
        elem->>'$.team.logo'                     AS team_logo,
        (elem->>'$.fixture.id')::INTEGER         AS fixture_id,
        elem->>'$.fixture.timezone'              AS fixture_timezone,
        (elem->>'$.fixture.date')::TIMESTAMPTZ   AS fixture_date,
        (elem->>'$.fixture.timestamp')::BIGINT   AS fixture_timestamp,
        (elem->>'$.league.id')::INTEGER          AS league_id_json,
        (elem->>'$.league.season')::INTEGER      AS season_json,
        elem->>'$.league.name'                   AS league_name,
        elem->>'$.league.country'                AS league_country,
        elem->>'$.league.logo'                   AS league_logo,
        elem->>'$.league.flag'                   AS league_flag,
        ingested_at
    FROM {db}.bronze.api_football__injuries,
    UNNEST(raw_json::JSON[]) AS t(elem)
) _src WHERE {insert_filter};
