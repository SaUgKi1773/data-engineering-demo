-- Group 4 | refresh: full replace
-- One row per individual transfer record.
SELECT
    team_id,
    (elem->>'$.player.id')::INTEGER        AS player_id,
    elem->>'$.player.name'                 AS player_name,
    (elem->>'$.update')::TIMESTAMPTZ       AS updated_at,
    tr->>'$.date'                          AS transfer_date,
    tr->>'$.type'                          AS transfer_type,
    (tr->>'$.teams.in.id')::INTEGER        AS team_in_id,
    tr->>'$.teams.in.name'                 AS team_in_name,
    tr->>'$.teams.in.logo'                 AS team_in_logo,
    (tr->>'$.teams.out.id')::INTEGER       AS team_out_id,
    tr->>'$.teams.out.name'                AS team_out_name,
    tr->>'$.teams.out.logo'                AS team_out_logo,
    ingested_at
FROM {db}.bronze.api_football__transfers,
UNNEST(raw_json::JSON[]) AS t1(elem),
UNNEST((elem->'$.transfers')::JSON[]) AS t2(tr)
