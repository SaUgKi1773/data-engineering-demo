-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixtures (
    fixture_id       INTEGER,
    referee          VARCHAR,
    timezone         VARCHAR,
    kick_off         TIMESTAMPTZ,
    kick_off_ts      BIGINT,
    period_first     INTEGER,
    period_second    INTEGER,
    venue_id         INTEGER,
    venue_name       VARCHAR,
    venue_city       VARCHAR,
    status_long      VARCHAR,
    status_short     VARCHAR,
    status_elapsed   INTEGER,
    status_extra     INTEGER,
    league_id        INTEGER,
    league_name      VARCHAR,
    league_country   VARCHAR,
    league_logo      VARCHAR,
    league_flag      VARCHAR,
    season           INTEGER,
    league_round     VARCHAR,
    league_standings BOOLEAN,
    home_team_id     INTEGER,
    home_team_name   VARCHAR,
    home_team_logo   VARCHAR,
    home_team_winner BOOLEAN,
    away_team_id     INTEGER,
    away_team_name   VARCHAR,
    away_team_logo   VARCHAR,
    away_team_winner BOOLEAN,
    goals_home       INTEGER,
    goals_away       INTEGER,
    score_ht_home    INTEGER,
    score_ht_away    INTEGER,
    score_ft_home    INTEGER,
    score_ft_away    INTEGER,
    score_et_home    INTEGER,
    score_et_away    INTEGER,
    score_pen_home   INTEGER,
    score_pen_away   INTEGER,
    ingested_at      TIMESTAMPTZ
);

DELETE FROM {db}.silver.fixtures WHERE {delete_filter};

INSERT INTO {db}.silver.fixtures
WITH venue_lookup AS (
    -- Build a name -> id map from bronze venues to backfill nulls in fixture API responses
    SELECT
        (elem->>'$.name')::VARCHAR    AS venue_name,
        MIN((elem->>'$.id')::INTEGER) AS venue_id
    FROM {db}.bronze.api_football__venues v,
    UNNEST(v.raw_json::JSON[]) AS t(elem)
    WHERE elem->>'$.id' IS NOT NULL
    GROUP BY (elem->>'$.name')::VARCHAR
)
SELECT * FROM (
    SELECT
        (raw_json->>'$.fixture.id')::INTEGER          AS fixture_id,
        CASE TRIM(SPLIT_PART(raw_json->>'$.fixture.referee', ',', 1))
            WHEN 'A. Uslu'                THEN 'Aydin Uslu'
            WHEN 'C. Theouli'             THEN 'Chrysovalantis Theouli'
            WHEN 'F. Svendsen'            THEN 'Frederik Svendsen'
            WHEN 'J. A. Sundberg'         THEN 'Jacob A. Sundberg'
            WHEN 'J. Sundberg'            THEN 'Jacob A. Sundberg'
            WHEN 'J. Burchardt'           THEN 'Jorgen Daugbjerg Burchardt'
            WHEN 'J. Hansen'              THEN 'Jonas Hansen'
            WHEN 'J. Karlsen'             THEN 'Jacob Karlsen'
            WHEN 'J. Kehlet'              THEN 'Jakob Kehlet'
            WHEN 'J. Maae'                THEN 'Jens Maae'
            WHEN 'K. Athanasiou'          THEN 'Kyriakos Athanasiou'
            WHEN 'L. Graagaard'           THEN 'Lasse Laebel Graagaard'
            WHEN 'M. Antoniou'            THEN 'Menelaos Antoniou'
            WHEN 'M. Kristoffersen'       THEN 'Mads Kristoffer Kristoffersen'
            WHEN 'M. Krogh'               THEN 'Morten Krogh'
            WHEN 'M. Redder'              THEN 'Mikkel Redder'
            WHEN 'M. Tykgaard'            THEN 'Michael Tykgaard'
            WHEN 'P. Kjærsgaard-Andersen' THEN 'Peter Kjaersgaard-Andersen'
            WHEN 'S. Putros'              THEN 'Sandi Putros'
            WHEN 'S. Rasmussen'           THEN 'Simon Duerland Rasmussen'
            ELSE TRIM(SPLIT_PART(raw_json->>'$.fixture.referee', ',', 1))
        END                                           AS referee,
        raw_json->>'$.fixture.timezone'               AS timezone,
        (raw_json->>'$.fixture.date')::TIMESTAMPTZ    AS kick_off,
        (raw_json->>'$.fixture.timestamp')::BIGINT    AS kick_off_ts,
        (raw_json->>'$.fixture.periods.first')::INTEGER  AS period_first,
        (raw_json->>'$.fixture.periods.second')::INTEGER AS period_second,
        COALESCE(
            (raw_json->>'$.fixture.venue.id')::INTEGER,
            vl.venue_id
        )                                             AS venue_id,
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
    LEFT JOIN venue_lookup vl ON vl.venue_name = (raw_json->>'$.fixture.venue.name')::VARCHAR
) _src WHERE {insert_filter};
