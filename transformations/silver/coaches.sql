-- Group 4 | refresh: full replace
-- One row per coach. Career history kept as JSON array column.
SELECT
    team_id,
    (elem->>'$.id')::INTEGER         AS coach_id,
    elem->>'$.name'                  AS coach_name,
    elem->>'$.firstname'             AS firstname,
    elem->>'$.lastname'              AS lastname,
    (elem->>'$.age')::INTEGER        AS age,
    elem->>'$.birth.date'            AS birth_date,
    elem->>'$.birth.place'           AS birth_place,
    elem->>'$.birth.country'         AS birth_country,
    elem->>'$.nationality'           AS nationality,
    elem->>'$.height'                AS height,
    elem->>'$.weight'                AS weight,
    elem->>'$.photo'                 AS photo,
    (elem->>'$.team.id')::INTEGER    AS current_team_id,
    elem->>'$.team.name'             AS current_team_name,
    elem->>'$.team.logo'             AS current_team_logo,
    (elem->'$.career')               AS career,
    ingested_at
FROM {db}.bronze.api_football__coaches,
UNNEST(raw_json::JSON[]) AS t(elem)
