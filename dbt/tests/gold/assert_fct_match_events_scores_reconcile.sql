-- Cross-fact conformance: the final running score derived from the event
-- stream must equal the goals fct_team_matches reports for the same match.
-- A mismatch means missing/unattributed goal events or a broken carry-forward.
-- Fixtures with manual score corrections are excluded: their official score
-- deliberately disagrees with the raw event stream.
-- Fixtures whose event stream is known-broken AT SOURCE are excluded by seed,
-- each with a reason, so a NEW discrepancy still fails loudly rather than the
-- whole test being downgraded to a warning.
WITH source_defects AS (
    SELECT dm.match_sk
    FROM {{ ref('event_stream_exceptions') }} x
    JOIN {{ ref('dim_match') }} dm ON dm.match_id = x.fixture_id AND dm._source = x.source
),
corrected_matches AS (
    SELECT DISTINCT dm.match_sk
    FROM {{ ref('fixture_score_corrections') }} c
    JOIN {{ ref('dim_match') }} dm ON dm.match_id = c.fixture_id
),
event_scores AS (
    SELECT
        match_sk,
        MAX(home_score_after_event) AS home_goals,
        MAX(away_score_after_event) AS away_goals
    FROM {{ ref('fct_match_events') }}
    WHERE match_sk > 0
    GROUP BY match_sk
),
reported_scores AS (
    SELECT
        match_sk,
        MAX(CASE WHEN team_side_sk = 1 THEN goals_scored END) AS home_goals,
        MAX(CASE WHEN team_side_sk = 2 THEN goals_scored END) AS away_goals
    FROM {{ ref('fct_team_matches') }}
    WHERE match_sk > 0
    GROUP BY match_sk
)
SELECT
    es.match_sk,
    es.home_goals AS event_home_goals,
    rs.home_goals AS reported_home_goals,
    es.away_goals AS event_away_goals,
    rs.away_goals AS reported_away_goals
FROM event_scores es
JOIN reported_scores rs ON rs.match_sk = es.match_sk
WHERE es.match_sk NOT IN (SELECT match_sk FROM corrected_matches)
  AND es.match_sk NOT IN (SELECT match_sk FROM source_defects)
  AND (es.home_goals != rs.home_goals OR es.away_goals != rs.away_goals)
