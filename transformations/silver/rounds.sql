-- Group 2 | refresh: season-scoped
-- {delete_filter} / {insert_filter} examples:
--   season-scoped : league_id = 119 AND season = 2025
--   full reload   : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.silver;

CREATE TABLE IF NOT EXISTS {db}.silver.rounds AS
SELECT * FROM (
    SELECT
        season,
        league_id,
        UNNEST(raw_json::VARCHAR[]) AS round_name,
        ingested_at
    FROM {db}.bronze.api_football__rounds
) _src WHERE 1=0;

DELETE FROM {db}.silver.rounds WHERE {delete_filter};

INSERT INTO {db}.silver.rounds
SELECT * FROM (
    SELECT
        season,
        league_id,
        UNNEST(raw_json::VARCHAR[]) AS round_name,
        ingested_at
    FROM {db}.bronze.api_football__rounds
) _src WHERE {insert_filter};
