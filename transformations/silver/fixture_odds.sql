-- Group 3 | refresh: incremental date-window (kick_off) or season-scoped
-- {delete_filter} / {insert_filter} examples:
--   incremental  : kick_off >= '2026-04-10' AND kick_off < '2026-04-12'
--   season-scoped: league_id = 119 AND season = 2025
--   full reload  : TRUE
-- One row per (fixture, bookmaker, bet, value) — fully normalised.
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.fixture_odds AS
SELECT * FROM (
    SELECT
        o.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ  AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER          AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER      AS season,
        (bm->>'$.id')::INTEGER                         AS bookmaker_id,
        bm->>'$.name'                                  AS bookmaker_name,
        (bet->>'$.id')::INTEGER                        AS bet_id,
        bet->>'$.name'                                 AS bet_name,
        val->>'$.value'                                AS bet_value,
        val->>'$.odd'                                  AS odd,
        o.ingested_at
    FROM {db}.bronze.api_football__fixture_odds o
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(o.raw_json::JSON[]) AS t1(wrap),
    UNNEST((wrap->'$.bookmakers')::JSON[]) AS t2(bm),
    UNNEST((bm->'$.bets')::JSON[]) AS t3(bet),
    UNNEST((bet->'$.values')::JSON[]) AS t4(val)
) _src WHERE 1=0;

DELETE FROM {db}.silver.fixture_odds WHERE {delete_filter};

INSERT INTO {db}.silver.fixture_odds
SELECT * FROM (
    SELECT
        o.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ  AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER          AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER      AS season,
        (bm->>'$.id')::INTEGER                         AS bookmaker_id,
        bm->>'$.name'                                  AS bookmaker_name,
        (bet->>'$.id')::INTEGER                        AS bet_id,
        bet->>'$.name'                                 AS bet_name,
        val->>'$.value'                                AS bet_value,
        val->>'$.odd'                                  AS odd,
        o.ingested_at
    FROM {db}.bronze.api_football__fixture_odds o
    JOIN {db}.bronze.api_football__fixtures f USING (fixture_id),
    UNNEST(o.raw_json::JSON[]) AS t1(wrap),
    UNNEST((wrap->'$.bookmakers')::JSON[]) AS t2(bm),
    UNNEST((bm->'$.bets')::JSON[]) AS t3(bet),
    UNNEST((bet->'$.values')::JSON[]) AS t4(val)
) _src WHERE {insert_filter};
