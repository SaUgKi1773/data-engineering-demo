SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS player_sk,
    id                 AS player_id,
    common_name,
    display_name,
    firstname,
    lastname,
    date_of_birth,
    EXTRACT(YEAR FROM date_of_birth)::INTEGER AS birth_year,
    height,
    weight,
    image_path,
    gender,
    country_id,
    nationality_id,
    nationality_name,
    position_name,
    position_code,
    position_developer_name,
    detailed_position_name
FROM {{ ref('players') }}
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Player',        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Player', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
