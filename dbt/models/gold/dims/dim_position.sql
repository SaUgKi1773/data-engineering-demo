{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='position_id',
        merge_update_columns=['position_name', 'position_code'],
        post_hook=[
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown', NULL::VARCHAR)) t(position_sk, position_id, position_name, position_code) WHERE t.position_sk NOT IN (SELECT position_sk FROM {{ this }})"
        ]
    )
}}

WITH positions AS (
    SELECT DISTINCT position_id, position_name, position_code
    FROM {{ ref('fixture_lineups') }}
    WHERE position_id IS NOT NULL
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(position_sk), 0) FROM {{ this }} WHERE position_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY position_id) AS position_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY position_id) AS position_sk,
    {% endif %}
    position_id,
    position_name,
    position_code
FROM positions
