WITH finished_fixtures AS (
    SELECT
        f.id       AS fixture_id,
        f.league_id,
        f.venue_id,
        f.starting_at,
        sg.type_developer_name AS stage_type
    FROM {{ ref('fixtures') }} f
    LEFT JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    WHERE f.state_developer_name IN ('FT', 'FT_PEN', 'AET')
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
match_teams AS (
    SELECT
        p.fixture_id,
        p.team_id,
        p.location,
        opp.team_id AS opponent_team_id
    FROM participants p
    JOIN participants opp
        ON opp.fixture_id = p.fixture_id
       AND opp.location  != p.location
),
scores AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN description = 'CURRENT'  THEN goals END) AS goals_scored,
        MAX(CASE WHEN description = '1ST_HALF' THEN goals END) AS goals_ht_scored
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, team_id
),
stats AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN type_id = 34 THEN value::INTEGER      END) AS corner_kicks,
        MAX(CASE WHEN type_id = 45 THEN value::DECIMAL(5,2) END) AS ball_possession_pct,
        MAX(CASE WHEN type_id = 83 THEN value::INTEGER      END) AS red_cards,
        MAX(CASE WHEN type_id = 84 THEN value::INTEGER      END) AS yellow_cards
    FROM {{ ref('fixture_statistics') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    SELECT DISTINCT ON (fixture_id)
        fixture_id,
        referee_id
    FROM {{ ref('fixture_referees') }}
    ORDER BY fixture_id, id
),
src AS (
    SELECT
        f.fixture_id,
        f.league_id,
        f.starting_at,
        f.venue_id,
        f.stage_type,
        mt.team_id,
        mt.location,
        mt.opponent_team_id,
        mr.referee_id,
        COALESCE(sc.goals_scored,     0)  AS goals_scored,
        COALESCE(osc.goals_scored,    0)  AS goals_conceded,
        COALESCE(sc.goals_ht_scored,  0)  AS goals_ht_scored,
        COALESCE(osc.goals_ht_scored, 0)  AS goals_ht_conceded,
        COALESCE(st.corner_kicks,     0)  AS corner_kicks,
        st.ball_possession_pct,
        COALESCE(st.yellow_cards,     0)  AS yellow_cards,
        COALESCE(st.red_cards,        0)  AS red_cards
    FROM finished_fixtures f
    JOIN  match_teams       mt   ON mt.fixture_id  = f.fixture_id
    LEFT JOIN scores        sc   ON sc.fixture_id  = f.fixture_id AND sc.team_id  = mt.team_id
    LEFT JOIN scores        osc  ON osc.fixture_id = f.fixture_id AND osc.team_id = mt.opponent_team_id
    LEFT JOIN stats         st   ON st.fixture_id  = f.fixture_id AND st.team_id  = mt.team_id
    LEFT JOIN main_referee  mr   ON mr.fixture_id  = f.fixture_id
)
SELECT
    COALESCE(dd.date_sk,           -1) AS date_sk,
    COALESCE(dt_time.time_sk,      -1) AS time_sk,
    COALESCE(dteam.team_sk,        -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk,-1) AS opponent_team_sk,
    COALESCE(dl.league_sk,         -1) AS league_sk,
    COALESCE(ds.stadium_sk,        -1) AS stadium_sk,
    COALESCE(dr.referee_sk,        -1) AS referee_sk,
    COALESCE(dm.match_sk,          -1) AS match_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                AS team_side_sk,
    CASE
        WHEN src.goals_scored > src.goals_conceded THEN 1
        WHEN src.goals_scored = src.goals_conceded THEN 2
        ELSE                                            3
    END                                AS match_result_sk,
    CASE
        WHEN src.stage_type = 'GROUP_STAGE' AND src.goals_scored > src.goals_conceded THEN 3
        WHEN src.stage_type = 'GROUP_STAGE' AND src.goals_scored = src.goals_conceded THEN 1
        WHEN src.stage_type = 'GROUP_STAGE'                                           THEN 0
        ELSE NULL
    END                                AS points_earned,
    src.goals_scored,
    src.goals_conceded,
    src.goals_ht_scored,
    src.goals_ht_conceded,
    NULL::INTEGER                      AS shots_on_goal,
    NULL::INTEGER                      AS shots_off_goal,
    NULL::INTEGER                      AS total_shots,
    NULL::INTEGER                      AS blocked_shots,
    NULL::INTEGER                      AS shots_insidebox,
    NULL::INTEGER                      AS shots_outsidebox,
    src.ball_possession_pct,
    NULL::INTEGER                      AS total_passes,
    NULL::INTEGER                      AS passes_accurate,
    NULL::INTEGER                      AS fouls,
    src.corner_kicks,
    NULL::INTEGER                      AS offsides,
    src.yellow_cards,
    src.red_cards,
    NULL::INTEGER                      AS goalkeeper_saves,
    NULL::DECIMAL(5,2)                 AS expected_goals
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk      = EXTRACT(hour FROM src.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::INTEGER
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id        = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id         = src.league_id
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_id        = src.venue_id
LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_id        = src.referee_id
LEFT JOIN {{ ref('dim_match') }}         dm      ON dm.match_id          = src.fixture_id
