{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='stadium_id',
        merge_update_columns=['stadium_name', 'stadium_address', 'stadium_city', 'stadium_country', 'stadium_capacity', 'stadium_surface'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Stadium Name', 'Unknown Stadium Address', 'Unknown Stadium City', 'Unknown Stadium Country', NULL::INTEGER, 'Unknown Stadium Surface'), (-2, NULL::INTEGER, 'Not Applicable Stadium Name', 'Not Applicable Stadium Address', 'Not Applicable Stadium City', 'Not Applicable Stadium Country', NULL::INTEGER, 'Not Applicable Stadium Surface')) t(stadium_sk, stadium_id, stadium_name, stadium_address, stadium_city, stadium_country, stadium_capacity, stadium_surface) WHERE t.stadium_sk NOT IN (SELECT stadium_sk FROM {{ this }})"
        ]
    )
}}

SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(stadium_sk), 0) FROM {{ this }} WHERE stadium_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY src.venue_id) AS stadium_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY src.venue_id) AS stadium_sk,
    {% endif %}
    src.venue_id    AS stadium_id,
    src.venue_name  AS stadium_name,
    src.address     AS stadium_address,
    src.city        AS stadium_city,
    src.country     AS stadium_country,
    src.capacity    AS stadium_capacity,
    src.surface     AS stadium_surface
FROM {{ ref('venues') }} src
WHERE src.venue_id IS NOT NULL
