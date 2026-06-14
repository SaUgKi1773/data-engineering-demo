{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='team_id',
        merge_update_columns=['team_name', 'team_code', 'team_short_name', 'team_country', 'team_founded_year', 'team_logo', 'team_venue_name', 'team_venue_city', 'team_venue_capacity'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE team_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Team', 'Unknown', 'Unknown Team', 'Unknown Team Country', NULL::INTEGER, NULL::VARCHAR, 'Unknown Team Venue', 'Unknown Team City', NULL::INTEGER), (-2, NULL::INTEGER, 'Not Applicable Team', 'N/A', 'Not Applicable', 'Not Applicable Team Country', NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Team Venue', 'Not Applicable Team City', NULL::INTEGER)) t(team_sk, team_id, team_name, team_code, team_short_name, team_country, team_founded_year, team_logo, team_venue_name, team_venue_city, team_venue_capacity)"
        ]
    )
}}

-- Clubs we ingest in detail (the league teams).
WITH latest AS (
    SELECT DISTINCT ON (id)
        id, name, short_code, country_name, founded, image_path,
        venue_name, venue_city, venue_capacity
    FROM {{ ref('teams') }}
    ORDER BY id, last_played_at DESC NULLS LAST
),
name_map AS (
    SELECT team_id, display_name, team_code, team_short_name
    FROM {{ ref('team_names') }}
),
detailed AS (
    SELECT
        l.id                                AS team_id,
        COALESCE(nm.display_name, l.name)   AS team_name,
        nm.team_code                        AS team_code,
        nm.team_short_name                  AS team_short_name,
        l.country_name                      AS team_country,
        l.founded                           AS team_founded_year,
        l.image_path                        AS team_logo,
        l.venue_name                        AS team_venue_name,
        l.venue_city                        AS team_venue_city,
        l.venue_capacity                    AS team_venue_capacity
    FROM latest l
    LEFT JOIN name_map nm ON nm.team_id = l.id
    WHERE l.id IS NOT NULL
),
-- Clubs referenced only by transfers (counterparties we do not ingest in detail).
-- Name / logo / country come from the embedded transfer payload; placeholders
-- ("TBC", "Retired") are excluded and resolve to -1 / -2 downstream.
transfer_clubs AS (
    SELECT from_team_id AS id, from_team_name AS name, from_team_country_id AS country_id,
           from_team_image_path AS image_path, from_team_placeholder AS placeholder, transfer_date
    FROM {{ ref('transfers') }}
    WHERE from_team_id IS NOT NULL
    UNION ALL
    SELECT to_team_id, to_team_name, to_team_country_id,
           to_team_image_path, to_team_placeholder, transfer_date
    FROM {{ ref('transfers') }}
    WHERE to_team_id IS NOT NULL
),
external AS (
    SELECT DISTINCT ON (tc.id)
        tc.id                                       AS team_id,
        COALESCE(tc.name, 'Unknown Team')           AS team_name,
        'Not Applicable'                            AS team_code,
        'Not Applicable'                            AS team_short_name,
        COALESCE(c.name, 'Not Applicable Team Country') AS team_country,
        NULL::INTEGER                               AS team_founded_year,
        tc.image_path                               AS team_logo,
        'Not Applicable Team Venue'                 AS team_venue_name,
        'Not Applicable Team City'                  AS team_venue_city,
        NULL::INTEGER                               AS team_venue_capacity
    FROM transfer_clubs tc
    LEFT JOIN {{ ref('core_countries') }} c ON c.id = tc.country_id
    WHERE NOT tc.placeholder
      AND tc.id NOT IN (SELECT team_id FROM detailed)
    ORDER BY tc.id, tc.transfer_date DESC NULLS LAST
),
combined AS (
    SELECT * FROM detailed
    UNION ALL
    SELECT * FROM external
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(team_sk), 0) FROM {{ this }} WHERE team_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY team_id) AS team_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY team_id) AS team_sk,
    {% endif %}
    team_id,
    team_name,
    team_code,
    team_short_name,
    team_country,
    team_founded_year,
    team_logo,
    team_venue_name,
    team_venue_city,
    team_venue_capacity
FROM combined
