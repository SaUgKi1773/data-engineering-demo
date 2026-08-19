{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', '_source']
) }}

-- unique_key is a delete SCOPE, not a row identity: Highlightly events carry
-- no ids, and every bronze row holds a fixture's complete event list, so
-- re-processing a fixture replaces its events wholesale for that source.

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
      AND _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
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

UNION ALL

-- Highlightly branch: events are strings mapped onto the Sportmonks type
-- vocabulary via the event_types_highlightly seed (the four VAR variants
-- land as type VAR with the detail in addition/info, matching the Sportmonks
-- lower()-matched sub-type convention). Substitutions: player = coming on,
-- substituted = going off (its id arrives in assistingPlayerId); goals:
-- assist -> related player. sort_order is the payload array ordinal - the
-- provider's ordering notion, like Sportmonks' family ordinal, not a global
-- timeline position.
SELECT
    NULL::INTEGER                                     AS id,
    h.fixture_id,
    NULL::INTEGER                                     AS period_id,
    (h.event->'team'->>'id')::INTEGER                 AS team_id,
    et.type_id                                        AS type_id,
    (h.event->>'playerId')::INTEGER                   AS player_id,
    (h.event->>'assistingPlayerId')::INTEGER          AS related_player_id,
    h.event->>'player'                                AS player_name,
    COALESCE(h.event->>'assist', h.event->>'substituted') AS related_player_name,
    NULL::VARCHAR                                     AS section,
    NULL::VARCHAR                                     AS result,
    et.info                                           AS info,
    et.addition                                       AS addition,
    TRY_CAST(split_part(h.event->>'time', '+', 1) AS INTEGER) AS minute,
    TRY_CAST(NULLIF(split_part(h.event->>'time', '+', 2), '') AS INTEGER) AS extra_minute,
    NULL::BOOLEAN                                     AS injured,
    NULL::BOOLEAN                                     AS on_bench,
    NULL::INTEGER                                     AS sub_type_id,
    h.ord::INTEGER                                    AS sort_order,
    NULL::BOOLEAN                                     AS rescinded,
    et.type_name                                      AS type_name,
    et.type_developer_name                            AS type_developer_name,
    h.event->'team'->>'name'                          AS team_name,
    'highlightly'                                     AS _source,
    h._ingested_at
FROM (
    SELECT
        d.id            AS fixture_id,
        d._ingested_at,
        d.events[g.ord] AS event,
        g.ord
    FROM (
        SELECT
            id,
            _ingested_at,
            json_transform(raw_json::VARCHAR, '{"events": ["JSON"]}').events AS events
        FROM {{ source('bronze', 'highlightly__match_details') }}
        WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.events')) > 0
        {% if is_incremental() %}
          AND _ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
        {% endif %}
    ) d,
    generate_series(1, len(d.events)) AS g(ord)
) h
LEFT JOIN {{ ref('event_types_highlightly') }} et
    ON et.highlightly_type = (h.event->>'type')
-- The provider occasionally publishes a fixture's events twice (52 fixtures,
-- 66 surplus rows). Identical rows differ only by their position in the array,
-- so the first occurrence is kept. A real match cannot contain two identical
-- events - the same player cannot score twice in the same minute - so this
-- removes duplication without risking a genuine event.
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY h.fixture_id,
                 (h.event->>'type'),
                 (h.event->>'playerId'),
                 (h.event->'team'->>'id'),
                 (h.event->>'time'),
                 (h.event->>'substituted'),
                 (h.event->>'assist')
    -- assist and substituted MUST stay in the key. A looser key merged two
    -- genuine goals: Fofana scored twice around minute 90 for Fatih
    -- Karagümrük and the provider stamps both as minute 90, so dropping the
    -- assist made them indistinguishable and cost the match a goal. Only rows
    -- identical in every published field are treated as duplicates.
    ORDER BY h.ord
) = 1
