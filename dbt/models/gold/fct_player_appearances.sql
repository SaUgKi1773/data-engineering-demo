{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'player_sk', 'team_sk']
    )
}}

WITH finished_fixtures AS (
    SELECT
        id        AS fixture_id,
        league_id,
        venue_id,
        starting_at
    FROM {{ ref('fixtures') }}
    WHERE state_developer_name IN ('FT', 'FT_PEN', 'AET')
),
participants AS (
    SELECT fixture_id, team_id, location
    FROM {{ ref('fixture_participants') }}
),
team_context AS (
    SELECT
        p.fixture_id,
        p.team_id,
        CASE p.location WHEN 'home' THEN 1 ELSE 2 END AS team_side_sk,
        opp.team_id AS opponent_team_id
    FROM participants p
    JOIN participants opp
        ON opp.fixture_id = p.fixture_id
       AND opp.location  != p.location
),
team_scores AS (
    SELECT
        fixture_id,
        team_id,
        MAX(CASE WHEN description = 'CURRENT' THEN goals END) AS goals
    FROM {{ ref('fixture_scores') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    SELECT DISTINCT ON (fixture_id)
        fixture_id, referee_id
    FROM {{ ref('fixture_referees') }}
    ORDER BY fixture_id, id
),
minutes AS (
    SELECT fixture_id, player_id, value::INTEGER AS minutes_played
    FROM {{ ref('fixture_lineup_details') }}
    WHERE type_id = 119
),
lineup_base AS (
    SELECT
        lu.fixture_id,
        lu.player_id,
        lu.team_id,
        lu.type_id AS lineup_type_id,
        COALESCE(m.minutes_played, 0) AS minutes_played
    FROM {{ ref('fixture_lineups') }} lu
    INNER JOIN finished_fixtures f ON f.fixture_id = lu.fixture_id
    LEFT JOIN minutes m ON m.fixture_id = lu.fixture_id AND m.player_id = lu.player_id
    WHERE lu.player_id IS NOT NULL
      AND lu.team_id   IS NOT NULL
      AND (lu.type_id = 11 OR COALESCE(m.minutes_played, 0) > 0)
),
stats AS (
    SELECT
        fixture_id, player_id,
        MAX(CASE WHEN type_id =  52 THEN value ELSE 0 END)::INTEGER AS goals_scored,
        MAX(CASE WHEN type_id =  88 THEN value ELSE 0 END)::INTEGER AS goals_conceded,
        MAX(CASE WHEN type_id =  79 THEN value ELSE 0 END)::INTEGER AS assists,
        MAX(CASE WHEN type_id =  57 THEN value ELSE 0 END)::INTEGER AS saves,
        MAX(CASE WHEN type_id =  42 THEN value ELSE 0 END)::INTEGER AS total_shots,
        MAX(CASE WHEN type_id =  86 THEN value ELSE 0 END)::INTEGER AS shots_on_goal,
        MAX(CASE WHEN type_id =  80 THEN value ELSE 0 END)::INTEGER AS total_passes,
        MAX(CASE WHEN type_id = 117 THEN value ELSE 0 END)::INTEGER AS passes_key,
        MAX(CASE WHEN type_id = 116 THEN value ELSE 0 END)::INTEGER AS passes_accurate,
        MAX(CASE WHEN type_id =  78 THEN value ELSE 0 END)::INTEGER AS tackles_total,
        MAX(CASE WHEN type_id = 100 THEN value ELSE 0 END)::INTEGER AS interceptions,
        MAX(CASE WHEN type_id = 105 THEN value ELSE 0 END)::INTEGER AS duels_total,
        MAX(CASE WHEN type_id = 106 THEN value ELSE 0 END)::INTEGER AS duels_won,
        MAX(CASE WHEN type_id = 108 THEN value ELSE 0 END)::INTEGER AS dribbles_attempts,
        MAX(CASE WHEN type_id = 109 THEN value ELSE 0 END)::INTEGER AS dribbles_success,
        MAX(CASE WHEN type_id = 110 THEN value ELSE 0 END)::INTEGER AS dribbles_past,
        MAX(CASE WHEN type_id =  56 THEN value ELSE 0 END)::INTEGER AS fouls_committed,
        MAX(CASE WHEN type_id =  96 THEN value ELSE 0 END)::INTEGER AS fouls_drawn,
        MAX(CASE WHEN type_id =  51 THEN value ELSE 0 END)::INTEGER AS offsides,
        MAX(CASE WHEN type_id = 118 THEN value ELSE NULL END)        AS rating
    FROM {{ ref('fixture_lineup_details') }}
    GROUP BY fixture_id, player_id
),
events AS (
    SELECT
        e.fixture_id, e.player_id,
        SUM(CASE WHEN e.type_id = 19 THEN 1 ELSE 0 END)::INTEGER AS yellow_cards,
        SUM(CASE WHEN e.type_id = 20 THEN 1 ELSE 0 END)::INTEGER AS red_cards,
        SUM(CASE WHEN e.type_id = 16 THEN 1 ELSE 0 END)::INTEGER AS penalty_scored,
        SUM(CASE WHEN e.type_id = 17 THEN 1 ELSE 0 END)::INTEGER AS penalty_missed
    FROM {{ ref('fixture_events') }} e
    INNER JOIN finished_fixtures f ON f.fixture_id = e.fixture_id
    WHERE e.player_id IS NOT NULL AND e.rescinded IS NOT TRUE
    GROUP BY e.fixture_id, e.player_id
),
src AS (
    SELECT
        lb.fixture_id,
        lb.player_id,
        lb.team_id,
        lb.minutes_played,
        ff.starting_at,
        ff.league_id,
        ff.venue_id,
        CASE lb.lineup_type_id WHEN 11 THEN 1 ELSE 2 END AS appearance_type_sk,
        COALESCE(tc.team_side_sk, -1)  AS team_side_sk,
        tc.opponent_team_id,
        CASE
            WHEN tc.opponent_team_id IS NULL THEN -1
            WHEN COALESCE(ts_own.goals, 0) > COALESCE(ts_opp.goals, 0) THEN 1
            WHEN COALESCE(ts_own.goals, 0) = COALESCE(ts_opp.goals, 0) THEN 2
            ELSE 3
        END                            AS match_result_sk,
        COALESCE(s.goals_scored,      0) AS goals_scored,
        COALESCE(s.goals_conceded,    0) AS goals_conceded,
        COALESCE(s.assists,           0) AS assists,
        COALESCE(s.saves,             0) AS saves,
        COALESCE(s.total_shots,       0) AS total_shots,
        COALESCE(s.shots_on_goal,     0) AS shots_on_goal,
        COALESCE(s.total_passes,      0) AS total_passes,
        COALESCE(s.passes_key,        0) AS passes_key,
        COALESCE(s.passes_accurate,   0) AS passes_accurate,
        COALESCE(s.tackles_total,     0) AS tackles_total,
        0::INTEGER                        AS tackles_blocks,
        COALESCE(s.interceptions,     0) AS interceptions,
        COALESCE(s.duels_total,       0) AS duels_total,
        COALESCE(s.duels_won,         0) AS duels_won,
        COALESCE(s.dribbles_attempts, 0) AS dribbles_attempts,
        COALESCE(s.dribbles_success,  0) AS dribbles_success,
        COALESCE(s.dribbles_past,     0) AS dribbles_past,
        COALESCE(s.fouls_drawn,       0) AS fouls_drawn,
        COALESCE(s.fouls_committed,   0) AS fouls_committed,
        COALESCE(s.offsides,          0) AS offsides,
        COALESCE(ev.yellow_cards,     0) AS yellow_cards,
        COALESCE(ev.red_cards,        0) AS red_cards,
        0::INTEGER                        AS penalty_won,
        0::INTEGER                        AS penalty_committed,
        COALESCE(ev.penalty_scored,   0) AS penalty_scored,
        COALESCE(ev.penalty_missed,   0) AS penalty_missed,
        0::INTEGER                        AS penalty_saved,
        s.rating
    FROM lineup_base lb
    INNER JOIN finished_fixtures ff  ON ff.fixture_id  = lb.fixture_id
    LEFT JOIN team_context  tc       ON tc.fixture_id  = lb.fixture_id AND tc.team_id = lb.team_id
    LEFT JOIN team_scores   ts_own   ON ts_own.fixture_id = lb.fixture_id AND ts_own.team_id = lb.team_id
    LEFT JOIN team_scores   ts_opp   ON ts_opp.fixture_id = lb.fixture_id AND ts_opp.team_id = tc.opponent_team_id
    LEFT JOIN stats         s        ON s.fixture_id   = lb.fixture_id AND s.player_id = lb.player_id
    LEFT JOIN events        ev       ON ev.fixture_id  = lb.fixture_id AND ev.player_id = lb.player_id
)
SELECT
    COALESCE(dd.date_sk,           -1) AS date_sk,
    COALESCE(dt_time.time_sk,      -1) AS time_sk,
    COALESCE(dm.match_sk,          -1) AS match_sk,
    COALESCE(dp.player_sk,         -1) AS player_sk,
    COALESCE(dteam.team_sk,        -1) AS team_sk,
    COALESCE(dopp.opponent_team_sk,-1) AS opponent_team_sk,
    COALESCE(dl.league_sk,         -1) AS league_sk,
    COALESCE(ds.stadium_sk,        -1) AS stadium_sk,
    COALESCE(dr.referee_sk,        -1) AS referee_sk,
    src.team_side_sk,
    src.match_result_sk,
    src.appearance_type_sk,
    src.minutes_played,
    src.goals_scored,
    src.goals_conceded,
    src.assists,
    src.saves,
    src.total_shots,
    src.shots_on_goal,
    src.total_passes,
    src.passes_key,
    src.passes_accurate,
    src.tackles_total,
    src.tackles_blocks,
    src.interceptions,
    src.duels_total,
    src.duels_won,
    src.dribbles_attempts,
    src.dribbles_success,
    src.dribbles_past,
    src.fouls_drawn,
    src.fouls_committed,
    src.offsides,
    src.yellow_cards,
    src.red_cards,
    src.penalty_won,
    src.penalty_committed,
    src.penalty_scored,
    src.penalty_missed,
    src.penalty_saved,
    src.rating
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk      = EXTRACT(hour FROM src.starting_at::TIMESTAMPTZ AT TIME ZONE 'Europe/Copenhagen')::INTEGER
LEFT JOIN {{ ref('dim_match') }}         dm      ON dm.match_id          = src.fixture_id
LEFT JOIN {{ ref('dim_player') }}        dp      ON dp.player_id         = src.player_id
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id        = src.team_id
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id         = src.league_id
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_id        = src.venue_id
LEFT JOIN main_referee                   mr      ON mr.fixture_id        = src.fixture_id
LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_id        = mr.referee_id
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
