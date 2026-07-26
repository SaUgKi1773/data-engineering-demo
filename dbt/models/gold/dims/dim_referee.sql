{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['referee_key', '_source'],
        merge_update_columns=['referee_common_name', 'referee_firstname', 'referee_lastname', 'referee_display_name', 'referee_nationality', 'referee_image_path'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE referee_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Referee', 'Unknown', 'Unknown', 'Unknown Referee', 'Unknown Referee Nationality', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Referee', 'Not Applicable', 'Not Applicable', 'Not Applicable Referee', 'Not Applicable Referee Nationality', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(referee_sk, referee_id, referee_common_name, referee_firstname, referee_lastname, referee_display_name, referee_nationality, referee_image_path, _source, referee_key)"
        ]
    )
}}

WITH from_referees AS (
    SELECT DISTINCT ON (id)
        id           AS referee_id,
        common_name  AS referee_common_name,
        firstname    AS referee_firstname,
        lastname     AS referee_lastname,
        display_name AS referee_display_name,
        country_name AS referee_nationality,
        image_path   AS referee_image_path,
        _source
    FROM {{ ref('referees') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
),
from_fixtures AS (
    SELECT DISTINCT ON (referee_id)
        referee_id,
        referee_common_name,
        referee_firstname,
        referee_lastname,
        referee_display_name,
        NULL::VARCHAR AS referee_nationality,
        referee_image_path,
        _source
    FROM {{ ref('fixture_referees') }}
    WHERE referee_id IS NOT NULL
      AND referee_id NOT IN (SELECT referee_id FROM from_referees)
    ORDER BY referee_id, _ingested_at DESC
),
-- Highlightly names its officials but mints no referee id, so the name IS the
-- identity there. Spellings drift, so they are folded through an alias seed
-- first - otherwise one official becomes two dimension members.
from_highlightly AS (
    SELECT DISTINCT ON (canonical_name)
        NULL::INTEGER  AS referee_id,
        canonical_name AS referee_common_name,
        NULL::VARCHAR  AS referee_firstname,
        NULL::VARCHAR  AS referee_lastname,
        canonical_name AS referee_display_name,
        referee_nationality,
        NULL::VARCHAR  AS referee_image_path,
        _source
    FROM (
        SELECT
            COALESCE(a.canonical_name, fr.referee_name) AS canonical_name,
            fr.referee_nationality,
            fr._source,
            fr._ingested_at
        FROM {{ ref('fixture_referees') }} fr
        LEFT JOIN {{ ref('referee_name_aliases') }} a ON a.alias_name = fr.referee_name
        WHERE fr._source = 'highlightly'
          AND fr.referee_name IS NOT NULL
    )
    ORDER BY canonical_name, _ingested_at DESC
),
combined AS (
    SELECT * FROM from_referees
    UNION ALL
    SELECT * FROM from_fixtures
    UNION ALL
    SELECT * FROM from_highlightly
),
keyed AS (
    -- The durable key a merge can rely on: a provider id where one exists,
    -- the official's canonical name where the provider mints none.
    SELECT *, COALESCE(referee_id::VARCHAR, referee_common_name) AS referee_key
    FROM combined
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {{ this }} WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY referee_key, _source) AS referee_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY referee_key, _source) AS referee_sk,
    {% endif %}
    referee_id,
    referee_common_name,
    referee_firstname,
    referee_lastname,
    referee_display_name,
    referee_nationality,
    referee_image_path,
    _source,
    referee_key
FROM keyed
