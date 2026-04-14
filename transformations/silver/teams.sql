-- Group 2 | refresh: season-scoped
-- {delete_filter} / {insert_filter} examples:
--   season-scoped : league_id = 119 AND season = 2025
--   full reload   : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.teams (
    season         INTEGER,
    league_id      INTEGER,
    team_id        INTEGER,
    team_name      VARCHAR,
    team_code      VARCHAR,
    team_country   VARCHAR,
    team_founded   INTEGER,
    team_national  BOOLEAN,
    team_logo      VARCHAR,
    venue_id       INTEGER,
    venue_name     VARCHAR,
    venue_address  VARCHAR,
    venue_city     VARCHAR,
    venue_capacity INTEGER,
    venue_surface  VARCHAR,
    venue_image    VARCHAR,
    ingested_at    TIMESTAMPTZ
);

DELETE FROM {db}.silver.teams WHERE {delete_filter};

INSERT INTO {db}.silver.teams
SELECT * FROM (
    SELECT
        season,
        league_id,
        (elem->>'$.team.id')::INTEGER          AS team_id,
        elem->>'$.team.name'                   AS team_name,
        elem->>'$.team.code'                   AS team_code,
        elem->>'$.team.country'                AS team_country,
        (elem->>'$.team.founded')::INTEGER     AS team_founded,
        (elem->>'$.team.national')::BOOLEAN    AS team_national,
        elem->>'$.team.logo'                   AS team_logo,
        (elem->>'$.venue.id')::INTEGER         AS venue_id,
        elem->>'$.venue.name'                  AS venue_name,
        elem->>'$.venue.address'               AS venue_address,
        elem->>'$.venue.city'                  AS venue_city,
        (elem->>'$.venue.capacity')::INTEGER   AS venue_capacity,
        elem->>'$.venue.surface'               AS venue_surface,
        elem->>'$.venue.image'                 AS venue_image,
        ingested_at
    FROM {db}.bronze.api_football__teams,
    UNNEST(raw_json::JSON[]) AS t(elem)
) _src WHERE {insert_filter};
