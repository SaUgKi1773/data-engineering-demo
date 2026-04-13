-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixtures AS
SELECT * FROM (
    SELECT
        (raw_json->>'$.fixture.id')::INTEGER          AS fixture_id,
        raw_json->>'$.fixture.referee'                AS referee,
        raw_json->>'$.fixture.timezone'               AS timezone,
        (raw_json->>'$.fixture.date')::TIMESTAMPTZ    AS kick_off,
        (raw_json->>'$.fixture.timestamp')::BIGINT    AS kick_off_ts,
        (raw_json->>'$.fixture.periods.first')::INTEGER  AS period_first,
        (raw_json->>'$.fixture.periods.second')::INTEGER AS period_second,
        (raw_json->>'$.fixture.venue.id')::INTEGER    AS venue_id,
        raw_json->>'$.fixture.venue.name'             AS venue_name,
        raw_json->>'$.fixture.venue.city'             AS venue_city,
        raw_json->>'$.fixture.status.long'            AS status_long,
        raw_json->>'$.fixture.status.short'           AS status_short,
        (raw_json->>'$.fixture.status.elapsed')::INTEGER AS status_elapsed,
        (raw_json->>'$.fixture.status.extra')::INTEGER   AS status_extra,
        (raw_json->>'$.league.id')::INTEGER           AS league_id,
        raw_json->>'$.league.name'                    AS league_name,
        raw_json->>'$.league.country'                 AS league_country,
        raw_json->>'$.league.logo'                    AS league_logo,
        raw_json->>'$.league.flag'                    AS league_flag,
        (raw_json->>'$.league.season')::INTEGER       AS season,
        raw_json->>'$.league.round'                   AS league_round,
        (raw_json->>'$.league.standings')::BOOLEAN    AS league_standings,
        (raw_json->>'$.teams.home.id')::INTEGER       AS home_team_id,
        raw_json->>'$.teams.home.name'                AS home_team_name,
        raw_json->>'$.teams.home.logo'                AS home_team_logo,
        (raw_json->>'$.teams.home.winner')::BOOLEAN   AS home_team_winner,
        (raw_json->>'$.teams.away.id')::INTEGER       AS away_team_id,
        raw_json->>'$.teams.away.name'                AS away_team_name,
        raw_json->>'$.teams.away.logo'                AS away_team_logo,
        (raw_json->>'$.teams.away.winner')::BOOLEAN   AS away_team_winner,
        (raw_json->>'$.goals.home')::INTEGER          AS goals_home,
        (raw_json->>'$.goals.away')::INTEGER          AS goals_away,
        (raw_json->>'$.score.halftime.home')::INTEGER  AS score_ht_home,
        (raw_json->>'$.score.halftime.away')::INTEGER  AS score_ht_away,
        (raw_json->>'$.score.fulltime.home')::INTEGER  AS score_ft_home,
        (raw_json->>'$.score.fulltime.away')::INTEGER  AS score_ft_away,
        (raw_json->>'$.score.extratime.home')::INTEGER AS score_et_home,
        (raw_json->>'$.score.extratime.away')::INTEGER AS score_et_away,
        (raw_json->>'$.score.penalty.home')::INTEGER   AS score_pen_home,
        (raw_json->>'$.score.penalty.away')::INTEGER   AS score_pen_away,
        ingested_at
    FROM {db}.bronze.api_football__fixtures
) _src WHERE 1=0;

DELETE FROM {db}.silver.fixtures WHERE {delete_filter};

INSERT INTO {db}.silver.fixtures
SELECT * FROM (
    SELECT
        (raw_json->>'$.fixture.id')::INTEGER          AS fixture_id,
        raw_json->>'$.fixture.referee'                AS referee,
        raw_json->>'$.fixture.timezone'               AS timezone,
        (raw_json->>'$.fixture.date')::TIMESTAMPTZ    AS kick_off,
        (raw_json->>'$.fixture.timestamp')::BIGINT    AS kick_off_ts,
        (raw_json->>'$.fixture.periods.first')::INTEGER  AS period_first,
        (raw_json->>'$.fixture.periods.second')::INTEGER AS period_second,
        (raw_json->>'$.fixture.venue.id')::INTEGER    AS venue_id,
        raw_json->>'$.fixture.venue.name'             AS venue_name,
        raw_json->>'$.fixture.venue.city'             AS venue_city,
        raw_json->>'$.fixture.status.long'            AS status_long,
        raw_json->>'$.fixture.status.short'           AS status_short,
        (raw_json->>'$.fixture.status.elapsed')::INTEGER AS status_elapsed,
        (raw_json->>'$.fixture.status.extra')::INTEGER   AS status_extra,
        (raw_json->>'$.league.id')::INTEGER           AS league_id,
        raw_json->>'$.league.name'                    AS league_name,
        raw_json->>'$.league.country'                 AS league_country,
        raw_json->>'$.league.logo'                    AS league_logo,
        raw_json->>'$.league.flag'                    AS league_flag,
        (raw_json->>'$.league.season')::INTEGER       AS season,
        raw_json->>'$.league.round'                   AS league_round,
        (raw_json->>'$.league.standings')::BOOLEAN    AS league_standings,
        (raw_json->>'$.teams.home.id')::INTEGER       AS home_team_id,
        raw_json->>'$.teams.home.name'                AS home_team_name,
        raw_json->>'$.teams.home.logo'                AS home_team_logo,
        (raw_json->>'$.teams.home.winner')::BOOLEAN   AS home_team_winner,
        (raw_json->>'$.teams.away.id')::INTEGER       AS away_team_id,
        raw_json->>'$.teams.away.name'                AS away_team_name,
        raw_json->>'$.teams.away.logo'                AS away_team_logo,
        (raw_json->>'$.teams.away.winner')::BOOLEAN   AS away_team_winner,
        (raw_json->>'$.goals.home')::INTEGER          AS goals_home,
        (raw_json->>'$.goals.away')::INTEGER          AS goals_away,
        (raw_json->>'$.score.halftime.home')::INTEGER  AS score_ht_home,
        (raw_json->>'$.score.halftime.away')::INTEGER  AS score_ht_away,
        (raw_json->>'$.score.fulltime.home')::INTEGER  AS score_ft_home,
        (raw_json->>'$.score.fulltime.away')::INTEGER  AS score_ft_away,
        (raw_json->>'$.score.extratime.home')::INTEGER AS score_et_home,
        (raw_json->>'$.score.extratime.away')::INTEGER AS score_et_away,
        (raw_json->>'$.score.penalty.home')::INTEGER   AS score_pen_home,
        (raw_json->>'$.score.penalty.away')::INTEGER   AS score_pen_away,
        ingested_at
    FROM {db}.bronze.api_football__fixtures
) _src WHERE {insert_filter};
