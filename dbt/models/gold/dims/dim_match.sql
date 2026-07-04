{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='match_id',
        merge_update_columns=['match_round_type', 'match_round_number', 'match_round_name', 'match_type', 'match_name', 'match_short_name', 'match_result', 'kick_off_time', 'match_status'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE match_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, NULL::INTEGER, 'Unknown Match Round Type', NULL::INTEGER, 'Unknown Match Round Name', 'Unknown Match Type', 'Unknown Match', 'Unknown Match', 'Unknown Match Result', 'Unknown', 'Unknown Match Status'), (-2, NULL::INTEGER, 'Not Applicable Match Round Type', NULL::INTEGER, 'Not Applicable Match Round Name', 'Not Applicable Match Type', 'Not Applicable Match', 'Not Applicable Match', 'Not Applicable Match Result', 'Not Applicable', 'Not Applicable Match Status')) t(match_sk, match_id, match_round_type, match_round_number, match_round_name, match_type, match_name, match_short_name, match_result, kick_off_time, match_status)"
        ]
    )
}}

WITH regular_season_max AS (
    SELECT
        f.season_id,
        MAX(TRY_CAST(f.round_name AS INTEGER)) AS max_round
    FROM {{ ref('fixtures') }} f
    JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    WHERE sg.name = 'Regular Season'
      AND TRY_CAST(f.round_name AS INTEGER) IS NOT NULL
    GROUP BY f.season_id
),
participants_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN location = 'home' THEN team_id        END) AS home_team_id,
        MAX(CASE WHEN location = 'home' THEN team_name       END) AS home_team_name,
        MAX(CASE WHEN location = 'home' THEN team_short_code END) AS home_team_code,
        MAX(CASE WHEN location = 'away' THEN team_id        END) AS away_team_id,
        MAX(CASE WHEN location = 'away' THEN team_name       END) AS away_team_name,
        MAX(CASE WHEN location = 'away' THEN team_short_code END) AS away_team_code
    FROM {{ ref('fixture_participants') }}
    GROUP BY fixture_id
),
name_map AS (
    SELECT team_id, display_name, team_short_name AS short_name
    FROM {{ ref('team_names') }}
),
scores_pivot AS (
    SELECT
        fixture_id,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'home' THEN goals END) AS goals_home,
        MAX(CASE WHEN description = 'CURRENT' AND side = 'away' THEN goals END) AS goals_away
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id
),
src AS (
    SELECT
        f.id                                                                     AS match_id,
        -- Conformed round type: one vocabulary across leagues.
        -- Scottish Premiership (501) models its post-split phase as fixture
        -- GROUPS (stage '2nd Phase' + groups 'Championship Group'/'Relegation
        -- Group') and names its pre-split stage inconsistently across seasons
        -- ('Regular Season' in 2025/26, '1st Phase' in 2026/27); map both onto
        -- the round types the Danish stage names already carry.
        CASE
            WHEN f.league_id = 501 AND f.group_name = 'Championship Group' THEN 'Championship Round'
            WHEN f.league_id = 501 AND f.group_name = 'Relegation Group'   THEN 'Relegation Round'
            WHEN f.league_id = 501 AND sg.name      = '1st Phase'          THEN 'Regular Season'
            ELSE sg.name
        END                                                                      AS match_round_type,
        CASE
            WHEN sg.name != 'Regular Season'
                 AND TRY_CAST(f.round_name AS INTEGER) IS NOT NULL
                 AND TRY_CAST(f.round_name AS INTEGER) <= rsm.max_round
            THEN TRY_CAST(f.round_name AS INTEGER) + rsm.max_round
            ELSE TRY_CAST(f.round_name AS INTEGER)
        END                                                                      AS match_round_number,
        CASE sg.type_developer_name
            WHEN 'GROUP_STAGE' THEN 'Group Stage'
            WHEN 'KNOCK_OUT'   THEN 'Knockout'
        END                                                                      AS match_type,
        COALESCE(nm_h.display_name, pp.home_team_name, '') || ' - ' || COALESCE(nm_a.display_name, pp.away_team_name, '') AS match_name,
        COALESCE(nm_h.short_name, pp.home_team_code, pp.home_team_name, '')
            || ' - ' || COALESCE(nm_a.short_name, pp.away_team_code, pp.away_team_name, '')      AS match_short_name,
        CASE WHEN f.state_developer_name IN ('FT', 'FT_PEN', 'AET')
             THEN sp.goals_home::VARCHAR || ' - ' || sp.goals_away::VARCHAR
        END                                                                      AS match_result,
        -- Kick-off in the league's local time: Scottish Premiership (501) is
        -- Europe/London; Danish Superliga (and default) Europe/Copenhagen
        lpad(EXTRACT(hour   FROM (f.starting_at::TIMESTAMP AT TIME ZONE 'UTC')
             AT TIME ZONE (CASE WHEN f.league_id = 501 THEN 'Europe/London' ELSE 'Europe/Copenhagen' END))::VARCHAR, 2, '0')
            || ':'
            || lpad(EXTRACT(minute FROM (f.starting_at::TIMESTAMP AT TIME ZONE 'UTC')
             AT TIME ZONE (CASE WHEN f.league_id = 501 THEN 'Europe/London' ELSE 'Europe/Copenhagen' END))::VARCHAR, 2, '0')
                                                                                 AS kick_off_time,
        f.state_name                                                             AS match_status
    FROM {{ ref('fixtures') }} f
    JOIN {{ ref('stages') }}           sg  ON sg.id          = f.stage_id
    LEFT JOIN regular_season_max       rsm ON rsm.season_id  = f.season_id
    LEFT JOIN participants_pivot       pp  ON pp.fixture_id  = f.id
    LEFT JOIN scores_pivot             sp  ON sp.fixture_id  = f.id
    LEFT JOIN name_map                 nm_h ON nm_h.team_id = pp.home_team_id
    LEFT JOIN name_map                 nm_a ON nm_a.team_id = pp.away_team_id
    -- League matches only: Regular Season, Championship Round, Relegation Round.
    -- Excludes KNOCK_OUT stages (European cup play-offs, relegation play-offs).
    WHERE sg.type_developer_name = 'GROUP_STAGE'
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(match_sk), 0) FROM {{ this }} WHERE match_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY match_id) AS match_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY match_id) AS match_sk,
    {% endif %}
    match_id,
    match_round_type,
    match_round_number,
    match_round_type || ' - ' || match_round_number::VARCHAR AS match_round_name,
    match_type,
    match_name,
    match_short_name,
    match_result,
    kick_off_time,
    match_status
FROM src
