{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', '_source']
) }}

-- unique_key is a delete SCOPE, not a row identity: Highlightly stat rows
-- have no ids, and every bronze row carries a fixture's complete stat set,
-- so re-processing a fixture replaces its stats wholesale for that source.
-- measure_code is the cross-provider vocabulary (seeded per source);
-- type_id stays Sportmonks-only until gold migrates off it (#438).

-- Pre-filter and project only the statistics array BEFORE unnesting, like
-- fixture_events: full raw_json carried through the unnest OOMs a full refresh.
WITH src AS MATERIALIZED (
    SELECT
        id,
        _ingested_at,
        json_transform(raw_json::VARCHAR, '{"statistics": ["JSON"]}').statistics AS statistics
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.statistics')) > 0
    {% if is_incremental() %}
      AND _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
    {% endif %}
)

SELECT
    (stat->>'id')::INTEGER              AS id,
    f.id                                AS fixture_id,
    (stat->>'type_id')::INTEGER         AS type_id,
    sm.measure_code                     AS measure_code,
    (stat->>'participant_id')::INTEGER  AS team_id,
    (stat->'data'->>'value')::DOUBLE    AS value,
    stat->>'location'                   AS location,
    'sportmonks'                        AS _source,
    f._ingested_at
FROM src AS f,
unnest(f.statistics) AS t(stat)
LEFT JOIN {{ ref('stat_measure_codes_sportmonks') }} sm
    ON sm.type_id = (stat->>'type_id')::INTEGER

UNION ALL

-- Highlightly branch: statistics arrive as {displayName, value} pairs nested
-- per team; the measure set varies by season (14-16 measures pre-2024, up to
-- 40 from 2025, xG from 2024). An absent measure yields NO row - never zero.
-- location is derived by matching the stat block's team id to the payload's
-- homeTeam. Narrow projection first: details raw_json also carries events,
-- shots and predictions, and dragging it through the unnest OOMs full builds.
SELECT
    NULL::INTEGER            AS id,
    hs.fixture_id,
    NULL::INTEGER            AS type_id,
    hm.measure_code          AS measure_code,
    hs.team_id,
    -- value_scale lifts Highlightly's 0-1 percentage fractions to the 0-100
    -- convention Sportmonks uses, so one measure_code means one unit
    hs.value * COALESCE(hm.value_scale, 1) AS value,
    hs.location,
    'highlightly'            AS _source,
    hs._ingested_at
FROM (
    SELECT
        d.id                                             AS fixture_id,
        (team_stats->'team'->>'id')::INTEGER             AS team_id,
        (stat->>'value')::DOUBLE                         AS value,
        CASE WHEN (team_stats->'team'->>'id') = (d.home_team_id)
             THEN 'home' ELSE 'away' END                 AS location,
        stat->>'displayName'                             AS display_name,
        d._ingested_at
    FROM (
        SELECT
            id,
            _ingested_at,
            json_extract_string(raw_json, '$.homeTeam.id')                          AS home_team_id,
            json_transform(raw_json::VARCHAR, '{"statistics": ["JSON"]}').statistics AS statistics
        FROM {{ source('bronze', 'highlightly__match_details') }}
        WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.statistics')) > 0
        {% if is_incremental() %}
          AND _ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
        {% endif %}
    ) d,
    unnest(d.statistics) AS ts(team_stats),
    unnest(json_transform(team_stats::VARCHAR, '{"statistics": ["JSON"]}').statistics) AS st(stat)
) hs
LEFT JOIN {{ ref('stat_measure_codes_highlightly') }} hm
    ON hm.display_name = hs.display_name
