{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

{% set cols %}
    id,
    (raw_json->>'league_id')::INTEGER        AS league_id,
    (raw_json->>'season_id')::INTEGER        AS season_id,
    (raw_json->>'stage_id')::INTEGER         AS stage_id,
    (raw_json->>'round_id')::INTEGER         AS round_id,
    (raw_json->>'group_id')::INTEGER         AS group_id,
    (raw_json->>'aggregate_id')::INTEGER     AS aggregate_id,
    (raw_json->>'venue_id')::INTEGER         AS venue_id,
    (raw_json->>'state_id')::INTEGER         AS state_id,
    raw_json->>'name'                        AS name,
    (raw_json->>'starting_at')::TIMESTAMP    AS starting_at,
    (raw_json->>'starting_at_timestamp')::BIGINT AS starting_at_timestamp,
    raw_json->>'result_info'                 AS result_info,
    raw_json->>'leg'                         AS leg,
    (raw_json->>'length')::INTEGER           AS length,
    (raw_json->>'placeholder')::BOOLEAN      AS placeholder,
    (raw_json->>'has_odds')::BOOLEAN         AS has_odds,
    raw_json->'venue'->>'name'               AS venue_name,
    raw_json->'venue'->>'city_name'          AS venue_city,
    raw_json->'venue'->>'surface'            AS venue_surface,
    (raw_json->'venue'->>'capacity')::INTEGER AS venue_capacity,
    raw_json->'state'->>'name'               AS state_name,
    raw_json->'state'->>'short_name'         AS state_short_name,
    raw_json->'state'->>'developer_name'     AS state_developer_name,
    raw_json->'round'->>'name'               AS round_name,
    (raw_json->'round'->>'finished')::BOOLEAN AS round_finished,
    (raw_json->'round'->>'is_current')::BOOLEAN AS round_is_current,
    _fixture_date,
    _ingested_at
{% endset %}

{% if is_incremental() %}

SELECT {{ cols }}
FROM {{ source('bronze', 'sportmonks__fixtures') }}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})

{% else %}

-- Initial full build: process one season at a time to stay within memory limits.
-- Each season has ~200 fixtures; UNION ALL lets DuckDB stream rather than
-- materialise all 3 000+ rows simultaneously.
{% if execute %}
    {% set season_ids = run_query(
        "SELECT DISTINCT _season_id FROM " ~ source('bronze', 'sportmonks__fixtures') ~
        " WHERE _season_id IS NOT NULL ORDER BY 1"
    ).columns[0].values() %}
{% else %}
    {% set season_ids = [] %}
{% endif %}

{% for sid in season_ids %}
SELECT {{ cols }}
FROM {{ source('bronze', 'sportmonks__fixtures') }}
WHERE _season_id = {{ sid }}
{% if not loop.last %} UNION ALL {% endif %}
{% endfor %}

{% endif %}
