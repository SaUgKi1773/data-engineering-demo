{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', 'team_id', 'description', '_source']
) }}

-- unique_key is the natural grain, not the Sportmonks score-row id:
-- Highlightly has no score ids (its rows carry id NULL), and
-- (fixture_id, team_id, description) is verified unique for both sources.

WITH src AS MATERIALIZED (
    SELECT *
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    {% if is_incremental() %}
    WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
    {% endif %}
)

SELECT
    (score->>'id')::INTEGER             AS id,
    f.id                                AS fixture_id,
    (score->>'type_id')::INTEGER        AS type_id,
    (score->>'participant_id')::INTEGER AS team_id,
    (score->'score'->>'goals')::INTEGER AS goals,
    score->'score'->>'participant'      AS side,
    score->>'description'               AS description,
    'sportmonks'                        AS _source,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"scores": ["JSON"]}').scores) AS t(score)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.scores')) > 0

UNION ALL

-- Highlightly branch: the provider exposes only a fulltime score string
-- ("2 - 2") plus a penalties string when a shootout happened, so each match
-- with a result yields a CURRENT row per team and, for shootouts, a
-- PENALTY_SHOOTOUT row per team (matching the Sportmonks description
-- vocabulary).
--
-- A score row exists iff the provider recorded a score - deliberately NOT
-- keyed on state. Awarded results (a walkover recorded as Cancelled but
-- carrying "0 - 3") are real results that put points on the table, so they
-- belong in the fact; unplayed fixtures carry no score object at all and
-- produce nothing. Keying on state would silently drop the awarded ones.
SELECT
    NULL::INTEGER   AS id,
    s.fixture_id,
    NULL::INTEGER   AS type_id,
    s.team_id,
    s.goals,
    s.side,
    s.description,
    'highlightly'   AS _source,
    s._ingested_at
FROM (
    SELECT
        id                                                                        AS fixture_id,
        (raw_json->'homeTeam'->>'id')::INTEGER                                    AS team_id,
        TRY_CAST(split_part(raw_json->'state'->'score'->>'current', ' - ', 1) AS INTEGER) AS goals,
        'home'                                                                    AS side,
        'CURRENT'                                                                 AS description,
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
    WHERE json_extract_string(raw_json, '$.state.score.current') IS NOT NULL
    UNION ALL
    SELECT
        id,
        (raw_json->'awayTeam'->>'id')::INTEGER,
        TRY_CAST(split_part(raw_json->'state'->'score'->>'current', ' - ', 2) AS INTEGER),
        'away',
        'CURRENT',
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
    WHERE json_extract_string(raw_json, '$.state.score.current') IS NOT NULL
    UNION ALL
    SELECT
        id,
        (raw_json->'homeTeam'->>'id')::INTEGER,
        TRY_CAST(split_part(raw_json->'state'->'score'->>'penalties', ' - ', 1) AS INTEGER),
        'home',
        'PENALTY_SHOOTOUT',
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
    -- json_extract_string, not arrow chains: two arrow-path predicates on the
    -- same column in one WHERE trip a DuckDB rewrite bug (casts raw_json to
    -- numerical) as of 1.x
    WHERE json_extract_string(raw_json, '$.state.score.penalties') IS NOT NULL
      AND json_extract_string(raw_json, '$.state.description') LIKE 'Finished%'
    UNION ALL
    SELECT
        id,
        (raw_json->'awayTeam'->>'id')::INTEGER,
        TRY_CAST(split_part(raw_json->'state'->'score'->>'penalties', ' - ', 2) AS INTEGER),
        'away',
        'PENALTY_SHOOTOUT',
        _ingested_at
    FROM {{ source('bronze', 'highlightly__matches') }}
    WHERE json_extract_string(raw_json, '$.state.score.penalties') IS NOT NULL
      AND json_extract_string(raw_json, '$.state.description') LIKE 'Finished%'
) s
{% if is_incremental() %}
WHERE s._ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
