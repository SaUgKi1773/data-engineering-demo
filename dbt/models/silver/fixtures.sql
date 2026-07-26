{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['id', '_source']
) }}

-- Full-refresh memory workaround: DuckDB processes UNION ALL branches sequentially,
-- so splitting by season keeps peak memory to ~one season at a time instead of all 3317 rows.
{% if execute %}
    {% set season_result = run_query(
        "SELECT DISTINCT (raw_json->>'season_id')::INTEGER AS season_id
         FROM " ~ source('bronze', 'sportmonks__fixtures') ~
        " WHERE raw_json->>'season_id' IS NOT NULL
         ORDER BY 1"
    ) %}
    {% set season_ids = season_result.columns[0].values() %}
{% else %}
    {% set season_ids = [0] %}
{% endif %}

{% for season_id in season_ids %}
SELECT
    id,
    (raw_json->>'league_id')::INTEGER                   AS league_id,
    {{ season_id }}::INTEGER                             AS season_id,
    (raw_json->>'stage_id')::INTEGER                    AS stage_id,
    (raw_json->>'round_id')::INTEGER                    AS round_id,
    (raw_json->>'group_id')::INTEGER                    AS group_id,
    -- Split-phase group (e.g. Scottish Premiership 'Championship Group' /
    -- 'Relegation Group'); NULL for fixtures outside a grouped stage
    raw_json->'group'->>'name'                          AS group_name,
    (raw_json->>'aggregate_id')::INTEGER                AS aggregate_id,
    (raw_json->>'venue_id')::INTEGER                    AS venue_id,
    (raw_json->>'state_id')::INTEGER                    AS state_id,
    raw_json->>'name'                                   AS name,
    (raw_json->>'starting_at')::TIMESTAMP               AS starting_at,
    (raw_json->>'starting_at_timestamp')::BIGINT        AS starting_at_timestamp,
    raw_json->>'result_info'                            AS result_info,
    raw_json->>'leg'                                    AS leg,
    (raw_json->>'length')::INTEGER                      AS length,
    (raw_json->>'placeholder')::BOOLEAN                 AS placeholder,
    (raw_json->>'has_odds')::BOOLEAN                    AS has_odds,
    raw_json->'venue'->>'name'                          AS venue_name,
    raw_json->'venue'->>'city_name'                     AS venue_city,
    raw_json->'venue'->>'surface'                       AS venue_surface,
    (raw_json->'venue'->>'capacity')::INTEGER           AS venue_capacity,
    raw_json->'state'->>'name'                          AS state_name,
    raw_json->'state'->>'short_name'                    AS state_short_name,
    raw_json->'state'->>'developer_name'                AS state_developer_name,
    raw_json->'round'->>'name'                          AS round_name,
    (raw_json->'round'->>'finished')::BOOLEAN           AS round_finished,
    (raw_json->'round'->>'is_current')::BOOLEAN         AS round_is_current,
    _fixture_date,
    'sportmonks'                                        AS _source,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__fixtures') }}
WHERE (raw_json->>'season_id')::INTEGER = {{ season_id }}
{% if is_incremental() %}
  AND _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
{% endif %}
{% if not loop.last %} UNION ALL {% endif %}
{% endfor %}

UNION ALL

-- Highlightly branch (La Liga / Liga MX / Süper Lig). Kept OUTSIDE the
-- per-season loop above, which exists only as a Sportmonks memory workaround
-- and would otherwise duplicate this branch once per Sportmonks season.
-- Highlightly has no stage/round/group/venue entities: those ids stay NULL,
-- state_name and round_name carry the provider's raw text ("Finished",
-- "Apertura - 17"), and conformance happens in gold per league.
SELECT
    m.id,
    m._league_id                                        AS league_id,
    m._season_id                                        AS season_id,
    NULL::INTEGER                                       AS stage_id,
    NULL::INTEGER                                       AS round_id,
    NULL::INTEGER                                       AS group_id,
    NULL::VARCHAR                                       AS group_name,
    NULL::INTEGER                                       AS aggregate_id,
    NULL::INTEGER                                       AS venue_id,
    NULL::INTEGER                                       AS state_id,
    (m.raw_json->'homeTeam'->>'name') || ' vs ' || (m.raw_json->'awayTeam'->>'name') AS name,
    (m.raw_json->>'date')::TIMESTAMP                    AS starting_at,
    CAST(epoch((m.raw_json->>'date')::TIMESTAMP) AS BIGINT) AS starting_at_timestamp,
    NULL::VARCHAR                                       AS result_info,
    NULL::VARCHAR                                       AS leg,
    NULL::INTEGER                                       AS length,
    NULL::BOOLEAN                                       AS placeholder,
    NULL::BOOLEAN                                       AS has_odds,
    d.raw_json->'venue'->>'name'                        AS venue_name,
    d.raw_json->'venue'->>'city'                        AS venue_city,
    NULL::VARCHAR                                       AS venue_surface,
    TRY_CAST(d.raw_json->'venue'->>'capacity' AS INTEGER) AS venue_capacity,
    m.raw_json->'state'->>'description'                 AS state_name,
    NULL::VARCHAR                                       AS state_short_name,
    NULL::VARCHAR                                       AS state_developer_name,
    -- Corrected where the provider published a demonstrably wrong round; the
    -- seed carries the evidence per fixture. Explicit rows rather than a rule:
    -- Liga MX changes its post-season format often enough that any rule would
    -- eventually misfire on data we have not seen.
    COALESCE(ro.corrected_round_name, m.raw_json->>'round') AS round_name,
    NULL::BOOLEAN                                       AS round_finished,
    NULL::BOOLEAN                                       AS round_is_current,
    m._fixture_date,
    'highlightly'                                       AS _source,
    GREATEST(m._ingested_at, COALESCE(d._ingested_at, m._ingested_at)) AS _ingested_at
FROM {{ source('bronze', 'highlightly__matches') }} m
LEFT JOIN {{ source('bronze', 'highlightly__match_details') }} d ON d.id = m.id
LEFT JOIN {{ ref('highlightly_round_overrides') }} ro ON ro.fixture_id = m.id
{% if is_incremental() %}
WHERE GREATEST(m._ingested_at, COALESCE(d._ingested_at, m._ingested_at)) >
      COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
