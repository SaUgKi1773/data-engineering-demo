{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='referee_id',
        merge_update_columns=['referee_common_name', 'referee_firstname', 'referee_lastname', 'referee_display_name', 'referee_image_path'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Referee', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR), (-2, NULL::INTEGER, 'Not Applicable Referee', NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR)) t(referee_sk, referee_id, referee_common_name, referee_firstname, referee_lastname, referee_display_name, referee_image_path) WHERE t.referee_sk NOT IN (SELECT referee_sk FROM {{ this }})"
        ]
    )
}}

WITH latest AS (
    SELECT DISTINCT ON (id)
        id, common_name, firstname, lastname, display_name, image_path
    FROM {{ ref('referees') }}
    WHERE id IS NOT NULL
    ORDER BY id, _ingested_at DESC
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(referee_sk), 0) FROM {{ this }} WHERE referee_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY id) AS referee_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY id) AS referee_sk,
    {% endif %}
    id           AS referee_id,
    common_name  AS referee_common_name,
    firstname    AS referee_firstname,
    lastname     AS referee_lastname,
    display_name AS referee_display_name,
    image_path   AS referee_image_path
FROM latest
