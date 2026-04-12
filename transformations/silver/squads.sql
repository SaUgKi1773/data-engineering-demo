-- Group 4 | refresh: full replace
-- One row per (team, player) from current squad.
SELECT
    team_id,
    (squad->>'$.team.id')::INTEGER       AS team_id_json,
    squad->>'$.team.name'                AS team_name,
    squad->>'$.team.logo'                AS team_logo,
    (pl->>'$.id')::INTEGER               AS player_id,
    pl->>'$.name'                        AS player_name,
    (pl->>'$.age')::INTEGER              AS age,
    (pl->>'$.number')::INTEGER           AS shirt_number,
    pl->>'$.position'                    AS position,
    pl->>'$.photo'                       AS photo,
    ingested_at
FROM {db}.bronze.api_football__squads,
UNNEST(raw_json::JSON[]) AS t1(squad),
UNNEST((squad->'$.players')::JSON[]) AS t2(pl)
