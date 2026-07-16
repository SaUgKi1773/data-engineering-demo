{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='match_sk'
    )
}}

-- One row per match event (goal, card, substitution, VAR decision, ...).
-- unique_key is the match, not the event: the provider rewrites a fixture's
-- whole event list when VAR overturns something, so the fixture is the only
-- reload unit that self-heals removed events.
WITH finished_fixtures AS (
    SELECT
        f.id        AS fixture_id,
        f.league_id,
        f.venue_id,
        f.starting_at
    FROM {{ ref('fixtures') }} f
    JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    WHERE f.state_developer_name IN ('FT', 'FT_PEN', 'AET')
      -- League matches only: excludes KNOCK_OUT stages (European cup / relegation play-offs)
      AND sg.type_developer_name = 'GROUP_STAGE'
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
main_referee AS (
    SELECT fixture_id, referee_id
    FROM {{ ref('fixture_referees') }}
    WHERE type_id = 6
),
events AS (
    -- Corners are excluded on coverage grounds (only two partially covered
    -- seasons); shootout events never occur in GROUP_STAGE fixtures.
    SELECT
        fe.id AS event_id,
        fe.fixture_id,
        fe.period_id,
        fe.team_id,
        fe.player_id,
        fe.type_developer_name,
        st.developer_name AS sub_type_developer_name,
        fe.result,
        fe.minute,
        COALESCE(fe.extra_minute, 0) AS extra_minute,
        fe.sort_order
    FROM {{ ref('fixture_events') }} fe
    LEFT JOIN {{ ref('types') }} st ON st.id = fe.sub_type_id
    WHERE fe.type_developer_name NOT IN
          ('CORNER', 'PENALTY_SHOOTOUT_GOAL', 'PENALTY_SHOOTOUT_MISS')
),
periods AS (
    SELECT
        p.id,
        CASE t.developer_name
            WHEN '1ST_HALF' THEN 'First Half'
            WHEN '2ND_HALF' THEN 'Second Half'
            WHEN 'ET'       THEN 'Extra Time'
        END AS period_name
    FROM {{ ref('fixture_periods') }} p
    LEFT JOIN {{ ref('types') }} t ON t.id = p.type_id
),
enriched AS (
    SELECT
        e.fixture_id,
        e.team_id,
        e.player_id,
        e.minute,
        e.extra_minute,
        e.sort_order,
        ff.league_id,
        ff.venue_id,
        ff.starting_at,
        pt.location,
        opp.team_id AS opponent_team_id,
        -- Source period when present, else derived from the minute (8 rows league-wide)
        COALESCE(pd.period_name, CASE
            WHEN e.minute <= 45 THEN 'First Half'
            WHEN e.minute <= 90 THEN 'Second Half'
            ELSE                     'Extra Time'
        END) AS period_name,
        COALESCE(det.event_type_sk, det_fb.event_type_sk, -1) AS event_type_sk,
        COALESCE(det.event_group,   det_fb.event_group)       AS event_group,
        e.type_developer_name IN ('GOAL', 'OWNGOAL', 'PENALTY') AS is_scoring,
        -- The provider's result string ("2-1" after the event) is the
        -- authoritative score source: it stays correct even in the handful of
        -- matches where a goal event's team attribution is wrong. Note the
        -- provider attributes OWNGOAL events to the team AWARDED the goal, so
        -- an own goal's player belongs to the opposing team by design.
        CASE
            WHEN e.type_developer_name IN ('GOAL', 'OWNGOAL', 'PENALTY')
            THEN TRY_CAST(SPLIT_PART(e.result, '-', 1) AS INTEGER)
        END AS result_home_score,
        CASE
            WHEN e.type_developer_name IN ('GOAL', 'OWNGOAL', 'PENALTY')
            THEN TRY_CAST(SPLIT_PART(e.result, '-', 2) AS INTEGER)
        END AS result_away_score
    FROM events e
    INNER JOIN finished_fixtures ff ON ff.fixture_id = e.fixture_id
    LEFT JOIN periods       pd  ON pd.id          = e.period_id
    LEFT JOIN participants  pt  ON pt.fixture_id  = e.fixture_id AND pt.team_id  = e.team_id
    LEFT JOIN participants  opp ON opp.fixture_id = e.fixture_id AND opp.location != pt.location
    LEFT JOIN {{ ref('dim_event_type') }} det
        ON  det.event_type_code     = e.type_developer_name
        AND det.event_sub_type_code = COALESCE(e.sub_type_developer_name, 'UNSPECIFIED')
    -- Unseen future sub-types degrade gracefully to the type's Unspecified row
    LEFT JOIN {{ ref('dim_event_type') }} det_fb
        ON  det_fb.event_type_code     = e.type_developer_name
        AND det_fb.event_sub_type_code = 'UNSPECIFIED'
),
src AS (
    SELECT
        *,
        CASE period_name
            WHEN 'First Half'  THEN 1
            WHEN 'Second Half' THEN 2
            ELSE                    3
        END AS period_sort
    FROM enriched
),
sequenced AS (
    SELECT
        *,
        -- Score immediately after this event: the latest result string at or
        -- before this row, 0-0 before the first goal. Non-scoring events
        -- sharing a goal's exact timestamp take the post-goal score by
        -- convention (scoring events order first within a timestamp).
        COALESCE(LAST_VALUE(result_home_score IGNORE NULLS) OVER score_window, 0) AS home_score_after_event,
        COALESCE(LAST_VALUE(result_away_score IGNORE NULLS) OVER score_window, 0) AS away_score_after_event,
        -- The match's Nth event of this event group ("3rd goal", "5th yellow").
        -- sort_order is the provider's per-family ordinal: valid as a final
        -- tiebreaker inside a group, meaningless across groups, never stored.
        ROW_NUMBER() OVER (
            PARTITION BY fixture_id, event_group
            ORDER BY period_sort, minute, extra_minute, sort_order
        ) AS event_group_sequence
    FROM src
    WINDOW score_window AS (
        PARTITION BY fixture_id
        ORDER BY period_sort, minute, extra_minute,
                 CASE WHEN is_scoring THEN 0 ELSE 1 END, sort_order
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
)
SELECT
    COALESCE(dd.date_sk,            -1) AS date_sk,
    COALESCE(dt_time.time_sk,       -1) AS time_sk,
    COALESCE(dm.match_sk,           -1) AS match_sk,
    COALESCE(dl.league_sk,          -1) AS league_sk,
    COALESCE(dteam.team_sk,         -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk, -1) AS opponent_team_sk,
    COALESCE(dp.player_sk,          -1) AS player_sk,
    COALESCE(dr.referee_sk,         -1) AS referee_sk,
    COALESCE(ds.stadium_sk,         -1) AS stadium_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                 AS team_side_sk,
    src.event_type_sk,
    COALESCE(dmm.match_minute_sk,   -1) AS match_minute_sk,
    src.event_group_sequence,
    src.home_score_after_event,
    src.away_score_after_event,
    1                                   AS event_count
FROM sequenced src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date               = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk       = EXTRACT(hour FROM (src.starting_at::TIMESTAMP AT TIME ZONE 'UTC') AT TIME ZONE {{ league_local_tz('src.league_id') }})::INTEGER
LEFT JOIN {{ ref('dim_match') }}         dm      ON dm.match_id           = src.fixture_id
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id          = src.league_id
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id         = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_player') }}        dp      ON dp.player_id          = src.player_id
LEFT JOIN main_referee                   mr      ON mr.fixture_id         = src.fixture_id
LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_id         = mr.referee_id
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_id         = src.venue_id
-- Contradictory source combos (e.g. a first-half event at minute 60) resolve
-- to the Unknown row rather than a silently wrong bucket
LEFT JOIN {{ ref('dim_match_minute') }}  dmm
    ON  dmm.period_name     = src.period_name
    AND dmm.minute_of_match = src.minute
    AND dmm.minute_type     = CASE WHEN src.extra_minute > 0 THEN 'Stoppage' ELSE 'Regulation' END
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
