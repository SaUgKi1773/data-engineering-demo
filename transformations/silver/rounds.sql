-- Group 2 | refresh: season-scoped (league_id + season)
-- One row per round name.
SELECT
    season,
    league_id,
    UNNEST(raw_json::VARCHAR[]) AS round_name,
    ingested_at
FROM {db}.bronze.api_football__rounds
