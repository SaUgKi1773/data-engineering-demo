SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS player_sk,
    id                              AS player_id,
    display_name                    AS player_name,
    firstname                       AS player_firstname,
    lastname                        AS player_lastname,
    nationality_name                AS player_nationality,
    date_of_birth                   AS player_birth_date,
    city_name                       AS player_birth_place,
    country_name                    AS player_birth_country,
    height                          AS player_height,
    weight                          AS player_weight,
    image_path                      AS player_photo,
    position_name                   AS player_position,
    NULL::VARCHAR                   AS player_team_name
FROM {{ ref('players') }}
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Player',        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Player', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
