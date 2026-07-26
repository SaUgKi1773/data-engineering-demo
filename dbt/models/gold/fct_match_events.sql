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
        f.venue_name,
        f.starting_at,
        f._source
    FROM {{ ref('fixtures') }} f
    -- LEFT, not INNER: Highlightly has no stage entity, so an inner join would
    -- drop its fixtures before the scope macro ever judged them.
    LEFT JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    LEFT JOIN (
        SELECT DISTINCT fixture_id, _source FROM {{ ref('fixture_scores') }}
        WHERE description = 'CURRENT'
    ) fr ON fr.fixture_id = f.id AND fr._source = f._source
    WHERE {{ is_match_finished('f._source', 'f.state_developer_name', 'f.state_name',
                               'fr.fixture_id IS NOT NULL') }}
      -- League matches only; what counts varies by league (see the macro)
      AND {{ is_league_match('f.league_id', 'sg.type_developer_name') }}
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
main_referee AS (
    -- type_id 6 is the Sportmonks code for the match referee; Highlightly
    -- reports one official and no type at all.
    SELECT
        fr.fixture_id,
        fr._source,
        fr.referee_id,
        COALESCE(a.canonical_name, fr.referee_name) AS referee_name
    FROM {{ ref('fixture_referees') }} fr
    LEFT JOIN {{ ref('referee_name_aliases') }} a ON a.alias_name = fr.referee_name
    WHERE (fr._source = 'sportmonks' AND fr.type_id = 6)
       OR (fr._source = 'highlightly' AND fr.referee_name IS NOT NULL)
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
      -- Sportmonks types its shootout events, so the list above removes them.
      -- Highlightly does not: a shootout penalty arrives as an ordinary
      -- PENALTY and would be counted as a goal, reading Toluca 11-9 Tigres for
      -- a match that finished 2-1. They are identifiable by the clock -
      -- minute 120 with an incrementing stoppage offset - and that marker is
      -- exact here: 83 such events exist and every one is in a match that
      -- finished on penalties, with none in any other match.
      -- The shootout result is not lost; it lives in fixture_scores as
      -- PENALTY_SHOOTOUT rows.
      AND NOT (fe._source = 'highlightly'
               AND fe.minute >= 120 AND COALESCE(fe.extra_minute, 0) > 0)
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
        e.type_developer_name,
        e.sub_type_developer_name,
        e.minute,
        e.extra_minute,
        e.sort_order,
        e.event_id,
        ff.league_id,
        ff.venue_id,
        ff.venue_name,
        ff.starting_at,
        ff._source,
        pt.location,
        opp.team_id AS opponent_team_id,
        -- Source period when present, else derived from the minute (8 rows league-wide)
        COALESCE(pd.period_name, CASE
            WHEN e.minute <= 45 THEN 'First Half'
            WHEN e.minute <= 90 THEN 'Second Half'
            ELSE                     'Extra Time'
        END) AS period_name,
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
-- Every dimension resolves here, in one place, each on its natural key.
resolved AS (
    SELECT
        COALESCE(dd.date_sk,            -1) AS date_sk,
        COALESCE(dt_time.time_sk,       -1) AS time_sk,
        COALESCE(dm.match_sk,           -1) AS match_sk,
        COALESCE(dl.league_sk,          -1) AS league_sk,
        COALESCE(dteam.team_sk,         -1) AS team_sk,
        COALESCE(dopp.opponent_team_sk, -1) AS opponent_team_sk,
        -- Card and VAR events can lack a player BY NATURE (bench/coach
        -- bookings, situational reviews) -> Not Applicable. A player-less
        -- goal or substitution always had an actor -> Unknown (data gap).
        CASE
            WHEN src.player_id IS NULL
                 AND det.event_group IN ('Card', 'VAR') THEN -2
            ELSE COALESCE(dp.player_sk, -1)
        END                                 AS player_sk,
        COALESCE(dr.referee_sk,         -1) AS referee_sk,
        COALESCE(ds.stadium_sk,         -1) AS stadium_sk,
        COALESCE(det.match_event_type_sk, -1) AS match_event_type_sk,
        COALESCE(dmm.match_minute_sk,   -1) AS match_minute_sk,
        det.event_group,
        src.location,
        src.fixture_id,
        src.period_sort,
        src.minute,
        src.extra_minute,
        src.sort_order,
        src.event_id,
        src._source,
        src.is_scoring,
        src.result_home_score,
        src.result_away_score
    FROM src
    LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date               = src.starting_at::DATE
    LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk       = EXTRACT(hour FROM (src.starting_at::TIMESTAMP AT TIME ZONE 'UTC') AT TIME ZONE {{ league_local_tz('src.league_id') }})::INTEGER
    LEFT JOIN {{ ref('dim_match') }}         dm      ON dm.match_id           = src.fixture_id       AND dm._source    = src._source
    LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id          = src.league_id        AND dl._source    = src._source
    LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id         = src.team_id          AND dteam._source = src._source
    LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id AND dopp._source  = src._source
    LEFT JOIN {{ ref('dim_player') }}        dp      ON dp.player_id          = src.player_id        AND dp._source    = src._source
    LEFT JOIN main_referee                   mr      ON mr.fixture_id         = src.fixture_id AND mr._source = src._source
    LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_key        = COALESCE(mr.referee_id::VARCHAR, mr.referee_name) AND dr._source = src._source
    LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_key        = COALESCE({{ canonical_venue_id('src.venue_id') }}::VARCHAR, src.venue_name) AND ds._source = src._source
    LEFT JOIN {{ ref('dim_match_event_type') }} det
        ON  det.event_type_code     = src.type_developer_name
        AND det.event_sub_type_code = COALESCE(src.sub_type_developer_name, 'UNSPECIFIED')
    -- Natural-key join on the match clock; the period condition is an anomaly
    -- guard so contradictory source combos (e.g. a first-half event at minute
    -- 60) resolve to the Unknown row rather than a silently wrong bucket
    LEFT JOIN {{ ref('dim_match_minute') }}  dmm
        ON  dmm.minute_label = src.minute::VARCHAR
                || CASE WHEN src.extra_minute > 0 THEN '+' || src.extra_minute::VARCHAR ELSE '' END
        AND dmm.period_name  = src.period_name
),
sequenced AS (
    SELECT
        *,
        -- Score immediately after this event: the latest result string at or
        -- before this row, 0-0 before the first goal. Non-scoring events
        -- sharing a goal's exact timestamp take the post-goal score by
        -- convention (scoring events order first within a timestamp).
        -- Sportmonks stamps a running score on each scoring event; Highlightly
        -- has no such field, so its score is COUNTED from the event stream
        -- instead. Reading the absent field would have shown 0-0 down every
        -- new-league timeline - present, plausible and wrong.
        --
        -- Counting is sound for own goals too: the provider attributes an
        -- OWNGOAL to the team AWARDED the goal (validated in #425), so the
        -- scoring side is always the event's own team.
        CASE WHEN _source = 'highlightly'
             THEN SUM(CASE WHEN is_scoring AND location = 'home' THEN 1 ELSE 0 END) OVER score_window
             ELSE COALESCE(LAST_VALUE(result_home_score IGNORE NULLS) OVER score_window, 0)
        END AS home_score_after_event,
        CASE WHEN _source = 'highlightly'
             THEN SUM(CASE WHEN is_scoring AND location = 'away' THEN 1 ELSE 0 END) OVER score_window
             ELSE COALESCE(LAST_VALUE(result_away_score IGNORE NULLS) OVER score_window, 0)
        END AS away_score_after_event,
        -- The match's Nth event of this event group ("3rd goal", "5th yellow").
        -- sort_order is the provider's per-family ordinal: valid as a final
        -- tiebreaker inside a group, meaningless across groups, never stored.
        --
        -- event_id makes the order TOTAL, and therefore the model
        -- reproducible. Without it, events tying on every preceding key
        -- ordered arbitrarily and two consecutive rebuilds of identical code
        -- differed by ~130 rows - which also meant no change to this model
        -- could ever be proven safe. The two feeds supply complementary
        -- identifiers: Sportmonks a unique event id, Highlightly a unique
        -- per-fixture sort_order (its id is always NULL), so together they
        -- give a total order for both.
        ROW_NUMBER() OVER (
            PARTITION BY fixture_id, event_group
            ORDER BY period_sort, minute, extra_minute, sort_order, event_id
        ) AS event_group_sequence
    FROM resolved
    WINDOW score_window AS (
        PARTITION BY fixture_id
        ORDER BY period_sort, minute, extra_minute,
                 CASE WHEN is_scoring THEN 0 ELSE 1 END, sort_order, event_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
)
SELECT
    date_sk,
    time_sk,
    match_sk,
    league_sk,
    team_sk,
    opponent_team_sk,
    player_sk,
    referee_sk,
    stadium_sk,
    CASE location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END AS team_side_sk,
    match_event_type_sk,
    match_minute_sk,
    event_group_sequence,
    home_score_after_event,
    away_score_after_event,
    1 AS event_count
FROM sequenced
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
