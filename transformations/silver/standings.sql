-- Group 2 | refresh: season-scoped
-- {delete_filter} / {insert_filter} examples:
--   season-scoped : league_id = 119 AND season = 2025
--   full reload   : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.standings (
    season              INTEGER,
    league_id           INTEGER,
    league_id_json      INTEGER,
    league_name         VARCHAR,
    season_json         INTEGER,
    rank                INTEGER,
    team_id             INTEGER,
    team_name           VARCHAR,
    team_logo           VARCHAR,
    points              INTEGER,
    goal_diff           INTEGER,
    standing_group      VARCHAR,
    form                VARCHAR,
    status              VARCHAR,
    description         VARCHAR,
    played              INTEGER,
    wins                INTEGER,
    draws               INTEGER,
    losses              INTEGER,
    goals_for           INTEGER,
    goals_against       INTEGER,
    home_played         INTEGER,
    home_wins           INTEGER,
    home_draws          INTEGER,
    home_losses         INTEGER,
    home_goals_for      INTEGER,
    home_goals_against  INTEGER,
    away_played         INTEGER,
    away_wins           INTEGER,
    away_draws          INTEGER,
    away_losses         INTEGER,
    away_goals_for      INTEGER,
    away_goals_against  INTEGER,
    updated_at          TIMESTAMPTZ,
    ingested_at         TIMESTAMPTZ
);

DELETE FROM {db}.silver.standings WHERE {delete_filter};

INSERT INTO {db}.silver.standings
SELECT * FROM (
    SELECT
        season,
        league_id,
        (row_elem->>'$.league.id')::INTEGER          AS league_id_json,
        row_elem->>'$.league.name'                   AS league_name,
        (row_elem->>'$.league.season')::INTEGER      AS season_json,
        (standing->>'$.rank')::INTEGER               AS rank,
        (standing->>'$.team.id')::INTEGER            AS team_id,
        standing->>'$.team.name'                     AS team_name,
        standing->>'$.team.logo'                     AS team_logo,
        (standing->>'$.points')::INTEGER             AS points,
        (standing->>'$.goalsDiff')::INTEGER          AS goal_diff,
        standing->>'$.group'                         AS standing_group,
        standing->>'$.form'                          AS form,
        standing->>'$.status'                        AS status,
        standing->>'$.description'                   AS description,
        (standing->>'$.all.played')::INTEGER         AS played,
        (standing->>'$.all.win')::INTEGER            AS wins,
        (standing->>'$.all.draw')::INTEGER           AS draws,
        (standing->>'$.all.lose')::INTEGER           AS losses,
        (standing->>'$.all.goals.for')::INTEGER      AS goals_for,
        (standing->>'$.all.goals.against')::INTEGER  AS goals_against,
        (standing->>'$.home.played')::INTEGER        AS home_played,
        (standing->>'$.home.win')::INTEGER           AS home_wins,
        (standing->>'$.home.draw')::INTEGER          AS home_draws,
        (standing->>'$.home.lose')::INTEGER          AS home_losses,
        (standing->>'$.home.goals.for')::INTEGER     AS home_goals_for,
        (standing->>'$.home.goals.against')::INTEGER AS home_goals_against,
        (standing->>'$.away.played')::INTEGER        AS away_played,
        (standing->>'$.away.win')::INTEGER           AS away_wins,
        (standing->>'$.away.draw')::INTEGER          AS away_draws,
        (standing->>'$.away.lose')::INTEGER          AS away_losses,
        (standing->>'$.away.goals.for')::INTEGER     AS away_goals_for,
        (standing->>'$.away.goals.against')::INTEGER AS away_goals_against,
        (standing->>'$.update')::TIMESTAMPTZ         AS updated_at,
        ingested_at
    FROM {db}.bronze.api_football__standings,
    UNNEST(raw_json::JSON[]) AS t1(row_elem),
    UNNEST((row_elem->'$.league.standings')::JSON[]) AS t2(standing_group_arr),
    UNNEST(standing_group_arr::JSON[]) AS t3(standing)
) _src WHERE {insert_filter};
