{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['team_id', '_source'],
        merge_update_columns=['team_name', 'team_code', 'team_short_name', 'team_country', 'team_founded_year', 'team_logo', 'team_venue_name', 'team_venue_city', 'team_venue_capacity'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE team_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Team', 'Unknown', 'Unknown Team', 'Unknown Team Country', NULL::INTEGER, NULL::VARCHAR, 'Unknown Team Venue', 'Unknown Team City', NULL::INTEGER, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Team', 'N/A', 'Not Applicable', 'Not Applicable Team Country', NULL::INTEGER, NULL::VARCHAR, 'Not Applicable Team Venue', 'Not Applicable Team City', NULL::INTEGER, NULL::VARCHAR)) t(team_sk, team_id, team_name, team_code, team_short_name, team_country, team_founded_year, team_logo, team_venue_name, team_venue_city, team_venue_capacity, _source)"
        ]
    )
}}

-- Composite natural key (team_id, _source): a provider-minted id identifies an
-- entity only within the provider that minted it. Two feeds happening not to
-- share a number today is a coincidence, not a guarantee, so the key and every
-- fact join into this dim carry the source alongside the id.

-- Clubs we ingest in detail (the league teams).
WITH latest AS (
    SELECT DISTINCT ON (id, _source)
        id, _source, name, short_code, country_name, founded, image_path,
        venue_name, venue_city, venue_capacity
    FROM {{ ref('teams') }}
    -- Highlightly teams stay out of gold until the #438 gold conformance PR
    -- admits their leagues; without this, dim_team gains memberless teams
    -- ahead of any fact rows.
    WHERE _source = 'sportmonks'
    ORDER BY id, _source, last_played_at DESC NULLS LAST
),
name_map AS (
    SELECT team_id, display_name, team_code, team_short_name
    FROM {{ ref('team_names') }}
),
detailed AS (
    SELECT
        l.id                                AS team_id,
        COALESCE(nm.display_name, l.name)   AS team_name,
        -- Fall back to API short_code, then a name prefix, for teams not yet
        -- curated in the team_names seed (e.g. newly backfilled leagues)
        COALESCE(nm.team_code, l.short_code,
                 UPPER(LEFT(l.name, 3)))    AS team_code,
        COALESCE(nm.team_short_name, l.name) AS team_short_name,
        l.country_name                      AS team_country,
        l.founded                           AS team_founded_year,
        l.image_path                        AS team_logo,
        l.venue_name                        AS team_venue_name,
        l.venue_city                        AS team_venue_city,
        l.venue_capacity                    AS team_venue_capacity,
        l._source                           AS _source
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
        NULL::INTEGER                               AS team_venue_capacity,
        -- transfers is a Sportmonks-only feed; these counterparty clubs can
        -- only have come from there
        'sportmonks'                                AS _source
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
        + ROW_NUMBER() OVER (ORDER BY team_id, _source) AS team_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY team_id, _source) AS team_sk,
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
    team_venue_capacity,
    _source
FROM combined
