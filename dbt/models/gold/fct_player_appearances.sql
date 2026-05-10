{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'player_sk', 'team_sk']
    )
}}

WITH src AS (
    SELECT
        fp.fixture_id,
        fp.team_id,
        fp.player_id,
        fp.league_id,
        (fp.kick_off AT TIME ZONE 'Europe/Copenhagen')::DATE                     AS match_date,
        EXTRACT(hour FROM fp.kick_off AT TIME ZONE 'Europe/Copenhagen')::INTEGER AS kick_off_hour,
        CASE WHEN fp.team_id = f.home_team_id THEN f.away_team_id
             ELSE f.home_team_id
        END                                                                       AS opponent_team_id,
        CASE WHEN fp.team_id = f.home_team_id THEN 1 ELSE 2 END                 AS team_side_sk,
        CASE
            WHEN f.status_short IN ('FT', 'AET', 'PEN')
                 AND CASE WHEN fp.team_id = f.home_team_id THEN f.goals_home ELSE f.goals_away END
                   > CASE WHEN fp.team_id = f.home_team_id THEN f.goals_away ELSE f.goals_home END THEN 1
            WHEN f.status_short IN ('FT', 'AET', 'PEN')
                 AND CASE WHEN fp.team_id = f.home_team_id THEN f.goals_home ELSE f.goals_away END
                   = CASE WHEN fp.team_id = f.home_team_id THEN f.goals_away ELSE f.goals_home END THEN 2
            WHEN f.status_short IN ('FT', 'AET', 'PEN')
                 AND CASE WHEN fp.team_id = f.home_team_id THEN f.goals_home ELSE f.goals_away END
                   < CASE WHEN fp.team_id = f.home_team_id THEN f.goals_away ELSE f.goals_home END THEN 3
            WHEN f.status_short IN ('NS', 'TBD', '1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE')   THEN 4
            WHEN f.status_short IN ('PST', 'CANC', 'ABD', 'AWD', 'WO', 'SUSP', 'INT')          THEN -2
            ELSE -1
        END                                                                       AS match_result_sk,
        CASE WHEN fp.substitute THEN 2 ELSE 1 END                               AS appearance_type_sk,
        f.venue_id,
        f.referee,
        fp.minutes_played,
        COALESCE(fp.goals,          0) AS goals,
        COALESCE(fp.assists,        0) AS assists,
        COALESCE(fp.shots_total,    0) AS shots_total,
        COALESCE(fp.shots_on,       0) AS shots_on,
        COALESCE(fp.passes_total,   0) AS passes_total,
        COALESCE(fp.passes_key,     0) AS passes_key,
        COALESCE(fp.tackles_total,  0) AS tackles_total,
        COALESCE(fp.interceptions,  0) AS interceptions,
        COALESCE(fp.duels_total,    0) AS duels_total,
        COALESCE(fp.duels_won,      0) AS duels_won,
        COALESCE(fp.yellow_cards,   0) AS yellow_cards,
        COALESCE(fp.red_cards,      0) AS red_cards,
        TRY_CAST(fp.rating AS DECIMAL) AS rating
    FROM {{ ref('fixture_players') }} fp
    JOIN {{ ref('fixtures') }} f ON f.fixture_id = fp.fixture_id
    WHERE fp.minutes_played > 0
),
joined AS (
    SELECT
        d.date_sk,
        COALESCE(t.time_sk,    -1) AS time_sk,
        COALESCE(m.match_sk,   -1) AS match_sk,
        COALESCE(p.player_sk,  -1) AS player_sk,
        COALESCE(tm.team_sk,   -1) AS team_sk,
        COALESCE(opp.team_sk,  -1) AS opponent_team_sk,
        COALESCE(l.league_sk,  -1) AS league_sk,
        COALESCE(st.stadium_sk,-1) AS stadium_sk,
        COALESCE(ref.referee_sk,-1) AS referee_sk,
        src.team_side_sk,
        src.match_result_sk,
        src.appearance_type_sk,
        src.minutes_played,
        src.goals,
        src.assists,
        src.shots_total,
        src.shots_on,
        src.passes_total,
        src.passes_key,
        src.tackles_total,
        src.interceptions,
        src.duels_total,
        src.duels_won,
        src.yellow_cards,
        src.red_cards,
        src.rating
    FROM src
    JOIN      {{ ref('dim_date')    }} d   ON d.date           = src.match_date
    LEFT JOIN {{ ref('dim_time')    }} t   ON t.time_sk        = src.kick_off_hour
    LEFT JOIN {{ ref('dim_match')   }} m   ON m.match_id       = src.fixture_id
    LEFT JOIN {{ ref('dim_player')  }} p   ON p.player_id      = src.player_id
    LEFT JOIN {{ ref('dim_team')    }} tm  ON tm.team_id       = src.team_id
    LEFT JOIN {{ ref('dim_team')    }} opp ON opp.team_id      = src.opponent_team_id
    LEFT JOIN {{ ref('dim_league')  }} l   ON l.league_id      = src.league_id
    LEFT JOIN {{ ref('dim_stadium') }} st  ON st.stadium_id    = src.venue_id
    LEFT JOIN {{ ref('dim_referee') }} ref ON ref.referee_name = src.referee
)
SELECT * FROM joined
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
