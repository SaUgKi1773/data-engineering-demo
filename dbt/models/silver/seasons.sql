{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['league_id', 'name', '_source']
) }}

-- Keyed on (league_id, name, _source) rather than a provider season id:
-- Highlightly mints no season id, and inventing one would be a fabricated key.
-- `id` therefore stays NULL on that branch; nothing downstream reads it.

WITH highlightly_matches AS (
    SELECT
        _league_id                                  AS league_id,
        _season_id                                  AS season_id,
        (raw_json->>'date')::TIMESTAMP::DATE        AS match_date
    FROM {{ source('bronze', 'highlightly__matches') }}
),
highlightly_seasons AS (
    SELECT
        league_id,
        -- A Liga MX season year contains two SEPARATE competitions, each with
        -- its own table and champion, so each is its own season here rather
        -- than one season with a modifier. The split is by calendar half and
        -- holds for the liguilla too, which finishes in mid-December - the
        -- round labels cannot be used, since Apertura 2025's knockout rounds
        -- are labelled bare ("Final", "Semi-finals") with no tournament prefix.
        CASE
            WHEN league_id = 223746 AND month(match_date) >= 7
                THEN season_id::VARCHAR || '/' || RIGHT((season_id + 1)::VARCHAR, 2) || ' - Apertura'
            WHEN league_id = 223746
                THEN season_id::VARCHAR || '/' || RIGHT((season_id + 1)::VARCHAR, 2) || ' - Clausura'
            ELSE season_id::VARCHAR || '/' || RIGHT((season_id + 1)::VARCHAR, 2)
        END                                         AS name,
        MIN(match_date)                             AS starting_at,
        MAX(match_date)                             AS ending_at
    FROM highlightly_matches
    GROUP BY 1, 2
)

SELECT
    id,
    (raw_json->>'league_id')::INTEGER            AS league_id,
    (raw_json->>'tie_breaker_rule_id')::INTEGER  AS tie_breaker_rule_id,
    raw_json->>'name'                            AS name,
    (raw_json->>'finished')::BOOLEAN             AS finished,
    (raw_json->>'pending')::BOOLEAN              AS pending,
    (raw_json->>'is_current')::BOOLEAN           AS is_current,
    (raw_json->>'starting_at')::DATE             AS starting_at,
    (raw_json->>'ending_at')::DATE               AS ending_at,
    (raw_json->>'games_in_current_week')::BOOLEAN AS games_in_current_week,
    'sportmonks'                                 AS _source,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__seasons') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
{% endif %}

UNION ALL

SELECT
    NULL::INTEGER       AS id,
    league_id,
    NULL::INTEGER       AS tie_breaker_rule_id,
    name,
    ending_at < CURRENT_DATE                     AS finished,
    starting_at > CURRENT_DATE                   AS pending,
    CURRENT_DATE BETWEEN starting_at AND ending_at AS is_current,
    starting_at,
    ending_at,
    NULL::BOOLEAN       AS games_in_current_week,
    'highlightly'       AS _source,
    -- rebuilt wholesale each run: a season's boundaries move whenever a match
    -- is rescheduled, so an incremental watermark on this branch would freeze
    -- stale ranges
    CURRENT_TIMESTAMP   AS _ingested_at
FROM highlightly_seasons
