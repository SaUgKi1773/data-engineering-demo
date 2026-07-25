{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['id', '_source']
) }}

-- Pre-filter to the incremental window BEFORE unnesting.
-- Without this, DuckDB unnests all 3000+ historical fixture rows before applying
-- the _ingested_at filter, blowing past MotherDuck Pulse's 953 MB memory cap.
-- Project only the events array here: carrying full raw_json through the unnest
-- multiplies it per event row and OOMs a full refresh.
WITH src AS MATERIALIZED (
    SELECT
        id,
        _ingested_at,
        json_transform(raw_json::VARCHAR, '{"events": ["JSON"]}').events AS events
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.events')) > 0
    {% if is_incremental() %}
      AND _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
    {% endif %}
)

SELECT
    (event->>'id')::INTEGER              AS id,
    f.id                                 AS fixture_id,
    (event->>'period_id')::INTEGER       AS period_id,
    (event->>'participant_id')::INTEGER  AS team_id,
    (event->>'type_id')::INTEGER         AS type_id,
    (event->>'player_id')::INTEGER       AS player_id,
    (event->>'related_player_id')::INTEGER AS related_player_id,
    event->>'player_name'                AS player_name,
    event->>'related_player_name'        AS related_player_name,
    event->>'section'                    AS section,
    event->>'result'                     AS result,
    event->>'info'                       AS info,
    event->>'addition'                   AS addition,
    (event->>'minute')::INTEGER          AS minute,
    (event->>'extra_minute')::INTEGER    AS extra_minute,
    (event->>'injured')::BOOLEAN         AS injured,
    (event->>'on_bench')::BOOLEAN        AS on_bench,
    (event->>'sub_type_id')::INTEGER     AS sub_type_id,
    (event->>'sort_order')::INTEGER      AS sort_order,
    (event->>'rescinded')::BOOLEAN       AS rescinded,
    event->'type'->>'name'               AS type_name,
    event->'type'->>'developer_name'     AS type_developer_name,
    event->'participant'->>'name'        AS team_name,
    'sportmonks'                         AS _source,
    f._ingested_at
FROM src AS f,
unnest(f.events) AS t(event)
