-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixture_players AS
SELECT * FROM (
    SELECT
        p.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ       AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER               AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER           AS season,
        (te->>'$.team.id')::INTEGER                         AS team_id,
        te->>'$.team.name'                                  AS team_name,
        te->>'$.team.logo'                                  AS team_logo,
        (pl->>'$.player.id')::INTEGER                       AS player_id,
        pl->>'$.player.name'                                AS player_name,
        pl->>'$.player.photo'                               AS player_photo,
        (st->>'$.games.minutes')::INTEGER                   AS minutes_played,
        (st->>'$.games.number')::INTEGER                    AS shirt_number,
        st->>'$.games.position'                             AS position,
        st->>'$.games.rating'                               AS rating,
        (st->>'$.games.captain')::BOOLEAN                   AS captain,
        (st->>'$.games.substitute')::BOOLEAN                AS substitute,
        (st->>'$.offsides')::INTEGER                        AS offsides,
        (st->>'$.shots.total')::INTEGER                     AS shots_total,
        (st->>'$.shots.on')::INTEGER                        AS shots_on,
        (st->>'$.goals.total')::INTEGER                     AS goals,
        (st->>'$.goals.conceded')::INTEGER                  AS goals_conceded,
        (st->>'$.goals.assists')::INTEGER                   AS assists,
        (st->>'$.goals.saves')::INTEGER                     AS saves,
        (st->>'$.passes.total')::INTEGER                    AS passes_total,
        (st->>'$.passes.key')::INTEGER                      AS passes_key,
        st->>'$.passes.accuracy'                            AS passes_accuracy,
        (st->>'$.tackles.total')::INTEGER                   AS tackles_total,
        (st->>'$.tackles.blocks')::INTEGER                  AS tackles_blocks,
        (st->>'$.tackles.interceptions')::INTEGER           AS interceptions,
        (st->>'$.duels.total')::INTEGER                     AS duels_total,
        (st->>'$.duels.won')::INTEGER                       AS duels_won,
        (st->>'$.dribbles.attempts')::INTEGER               AS dribbles_attempts,
        (st->>'$.dribbles.success')::INTEGER                AS dribbles_success,
        (st->>'$.dribbles.past')::INTEGER                   AS dribbles_past,
        (st->>'$.fouls.drawn')::INTEGER                     AS fouls_drawn,
        (st->>'$.fouls.committed')::INTEGER                 AS fouls_committed,
        (st->>'$.cards.yellow')::INTEGER                    AS yellow_cards,
        (st->>'$.cards.red')::INTEGER                       AS red_cards,
        (st->>'$.penalty.won')::INTEGER                     AS penalty_won,
        (st->>'$.penalty.committed')::INTEGER               AS penalty_committed,
        (st->>'$.penalty.scored')::INTEGER                  AS penalty_scored,
        (st->>'$.penalty.missed')::INTEGER                  AS penalty_missed,
        (st->>'$.penalty.saved')::INTEGER                   AS penalty_saved,
        p.ingested_at
    FROM {db}.bronze.api_football__fixture_players p
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(p.raw_json::JSON[]) AS t1(te),
    UNNEST((te->'$.players')::JSON[]) AS t2(pl),
    UNNEST((pl->'$.statistics')::JSON[]) AS t3(st)
) _src WHERE 1=0;

DELETE FROM {db}.silver.fixture_players WHERE {delete_filter};

INSERT INTO {db}.silver.fixture_players
SELECT * FROM (
    SELECT
        p.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ       AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER               AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER           AS season,
        (te->>'$.team.id')::INTEGER                         AS team_id,
        te->>'$.team.name'                                  AS team_name,
        te->>'$.team.logo'                                  AS team_logo,
        (pl->>'$.player.id')::INTEGER                       AS player_id,
        pl->>'$.player.name'                                AS player_name,
        pl->>'$.player.photo'                               AS player_photo,
        (st->>'$.games.minutes')::INTEGER                   AS minutes_played,
        (st->>'$.games.number')::INTEGER                    AS shirt_number,
        st->>'$.games.position'                             AS position,
        st->>'$.games.rating'                               AS rating,
        (st->>'$.games.captain')::BOOLEAN                   AS captain,
        (st->>'$.games.substitute')::BOOLEAN                AS substitute,
        (st->>'$.offsides')::INTEGER                        AS offsides,
        (st->>'$.shots.total')::INTEGER                     AS shots_total,
        (st->>'$.shots.on')::INTEGER                        AS shots_on,
        (st->>'$.goals.total')::INTEGER                     AS goals,
        (st->>'$.goals.conceded')::INTEGER                  AS goals_conceded,
        (st->>'$.goals.assists')::INTEGER                   AS assists,
        (st->>'$.goals.saves')::INTEGER                     AS saves,
        (st->>'$.passes.total')::INTEGER                    AS passes_total,
        (st->>'$.passes.key')::INTEGER                      AS passes_key,
        st->>'$.passes.accuracy'                            AS passes_accuracy,
        (st->>'$.tackles.total')::INTEGER                   AS tackles_total,
        (st->>'$.tackles.blocks')::INTEGER                  AS tackles_blocks,
        (st->>'$.tackles.interceptions')::INTEGER           AS interceptions,
        (st->>'$.duels.total')::INTEGER                     AS duels_total,
        (st->>'$.duels.won')::INTEGER                       AS duels_won,
        (st->>'$.dribbles.attempts')::INTEGER               AS dribbles_attempts,
        (st->>'$.dribbles.success')::INTEGER                AS dribbles_success,
        (st->>'$.dribbles.past')::INTEGER                   AS dribbles_past,
        (st->>'$.fouls.drawn')::INTEGER                     AS fouls_drawn,
        (st->>'$.fouls.committed')::INTEGER                 AS fouls_committed,
        (st->>'$.cards.yellow')::INTEGER                    AS yellow_cards,
        (st->>'$.cards.red')::INTEGER                       AS red_cards,
        (st->>'$.penalty.won')::INTEGER                     AS penalty_won,
        (st->>'$.penalty.committed')::INTEGER               AS penalty_committed,
        (st->>'$.penalty.scored')::INTEGER                  AS penalty_scored,
        (st->>'$.penalty.missed')::INTEGER                  AS penalty_missed,
        (st->>'$.penalty.saved')::INTEGER                   AS penalty_saved,
        p.ingested_at
    FROM {db}.bronze.api_football__fixture_players p
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(p.raw_json::JSON[]) AS t1(te),
    UNNEST((te->'$.players')::JSON[]) AS t2(pl),
    UNNEST((pl->'$.statistics')::JSON[]) AS t3(st)
) _src WHERE {insert_filter};
