{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['match_sk', 'team_side_sk']
    )
}}

WITH fixtures_with_result AS (
    -- Whether the provider recorded a scoreline at all; only the awarded-result
    -- branch of is_match_finished consults it.
    SELECT DISTINCT fixture_id, _source
    FROM {{ ref('fixture_scores') }}
    WHERE description = 'CURRENT'
),
all_fixtures AS (
    SELECT
        f.id       AS fixture_id,
        f.league_id,
        f.venue_id,
        f.venue_name,
        f.starting_at,
        f._source,
        sg.type_developer_name AS stage_type,
        sg.name                AS stage_name,
        f.group_name,
        f.round_name,
        {{ is_match_finished('f._source', 'f.state_developer_name', 'f.state_name',
                             'fr.fixture_id IS NOT NULL') }} AS is_finished
    FROM {{ ref('fixtures') }} f
    -- LEFT, not INNER: Highlightly has no stage entity, so an inner join would
    -- drop its fixtures before the scope macro below ever got to judge them.
    -- Scope is the macro's job, not a join's side effect.
    LEFT JOIN {{ ref('stages') }} sg ON sg.id = f.stage_id
    LEFT JOIN fixtures_with_result fr
        ON fr.fixture_id = f.id AND fr._source = f._source
    -- League matches only; what counts varies by league (see the macro)
    WHERE {{ is_league_match('f.league_id', 'sg.type_developer_name') }}
),
coaches AS (
    SELECT fixture_id, team_id, coach_id
    FROM {{ ref('fixture_coaches') }}
),
formations AS (
    SELECT fixture_id, team_id, formation
    FROM {{ ref('fixture_formations') }}
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
score_corrections AS (
    SELECT fixture_id, team_id, goals_scored_corrected
    FROM {{ ref('fixture_score_corrections') }}
),
shootout_scores AS (
    -- Kicks converted in a penalty shootout. Distinct from a penalty scored in
    -- open play, which is an ordinary goal and already inside goals_scored.
    SELECT fixture_id, team_id, _source, goals AS shootout_goals
    FROM {{ ref('fixture_scores') }}
    WHERE description = 'PENALTY_SHOOTOUT'
),
extra_time_goals AS (
    -- Goals scored in extra time (minutes 91-120), counted from the event
    -- stream because only Sportmonks publishes an ET score line and only for
    -- three fixtures - the clock is the one signal both feeds carry.
    --
    -- Shootout kicks are excluded: Highlightly reports them as ordinary
    -- penalties at minute 120 with a stoppage offset.
    --
    -- Counting by the event's own team is right for own goals too: the
    -- provider attributes an OWNGOAL to the team AWARDED the goal (#425).
    SELECT
        fixture_id,
        team_id,
        _source,
        COUNT(*) AS et_goals
    FROM {{ ref('fixture_events') }}
    WHERE type_developer_name IN ('GOAL', 'OWNGOAL', 'PENALTY')
      AND minute BETWEEN 91 AND 120
      AND NOT (minute >= 120 AND COALESCE(extra_minute, 0) > 0)
    GROUP BY fixture_id, team_id, _source
),
stats AS (
    SELECT
        fixture_id,
        team_id,
        -- measure_code, not Sportmonks type_id: it is the one measure
        -- vocabulary both providers speak (seeded per source in silver).
        -- Highlightly stat rows carry no type_id at all, so a type_id
        -- predicate would silently read zero rows for the new leagues.
        MAX(CASE WHEN measure_code = 'corners'        THEN value::INTEGER      END) AS corner_kicks,
        MAX(CASE WHEN measure_code = 'possession_pct' THEN value::DECIMAL(5,2) END) AS ball_possession_pct,
        MAX(CASE WHEN measure_code = 'red_cards'      THEN value::INTEGER      END) AS red_cards,
        MAX(CASE WHEN measure_code = 'yellow_cards'   THEN value::INTEGER      END) AS yellow_cards,
        -- Measures below exist only in the Highlightly feed. They are NULL for
        -- Denmark and Scotland permanently, and NULL for the Highlightly
        -- leagues before 2024 (the provider recorded 14-16 measures then, and
        -- no xG at all). NULL means "not recorded" and must never be read as
        -- zero: a mart that sums these across eras would report real absence
        -- as real nothing.
        -- Shooting
        MAX(CASE WHEN measure_code = 'shots_on_target'        THEN value::INTEGER      END) AS shots_on_target,
        MAX(CASE WHEN measure_code = 'shots_off_target'       THEN value::INTEGER      END) AS shots_off_target,
        MAX(CASE WHEN measure_code = 'shots_blocked'          THEN value::INTEGER      END) AS shots_blocked,
        MAX(CASE WHEN measure_code = 'shots_inside_box'       THEN value::INTEGER      END) AS shots_inside_box,
        MAX(CASE WHEN measure_code = 'shots_outside_box'      THEN value::INTEGER      END) AS shots_outside_box,
        -- shot accuracy is deliberately NOT stored: it is a non-additive ratio
        -- derivable from the shot counts above, so reports compute it and no
        -- one can mistakenly SUM() it. It remains available in silver.
        -- Expected values (2024 onwards only)
        MAX(CASE WHEN measure_code = 'expected_goals'         THEN value::DECIMAL(5,2) END) AS expected_goals,
        MAX(CASE WHEN measure_code = 'expected_assists'       THEN value::DECIMAL(5,2) END) AS expected_assists,
        MAX(CASE WHEN measure_code = 'big_chances_created'    THEN value::INTEGER      END) AS big_chances_created,
        MAX(CASE WHEN measure_code = 'key_passes'             THEN value::INTEGER      END) AS key_passes,
        -- Passing
        MAX(CASE WHEN measure_code = 'passes_total'           THEN value::INTEGER      END) AS passes_total,
        MAX(CASE WHEN measure_code = 'passes_successful'      THEN value::INTEGER      END) AS passes_successful,
        MAX(CASE WHEN measure_code = 'passes_failed'          THEN value::INTEGER      END) AS passes_failed,
        MAX(CASE WHEN measure_code = 'passes_final_third'     THEN value::INTEGER      END) AS passes_final_third,
        MAX(CASE WHEN measure_code = 'passes_opposition_half' THEN value::INTEGER      END) AS passes_opposition_half,
        MAX(CASE WHEN measure_code = 'passes_own_half'        THEN value::INTEGER      END) AS passes_own_half,
        MAX(CASE WHEN measure_code = 'passes_backward'        THEN value::INTEGER      END) AS passes_backward,
        MAX(CASE WHEN measure_code = 'long_passes'            THEN value::INTEGER      END) AS long_passes,
        MAX(CASE WHEN measure_code = 'long_passes_successful' THEN value::INTEGER      END) AS long_passes_successful,
        MAX(CASE WHEN measure_code = 'crosses'                THEN value::INTEGER      END) AS crosses,
        MAX(CASE WHEN measure_code = 'crosses_successful'     THEN value::INTEGER      END) AS crosses_successful,
        -- Duels and defending
        MAX(CASE WHEN measure_code = 'dribbles'               THEN value::INTEGER      END) AS dribbles,
        MAX(CASE WHEN measure_code = 'dribbles_successful'    THEN value::INTEGER      END) AS dribbles_successful,
        MAX(CASE WHEN measure_code = 'tackles'                THEN value::INTEGER      END) AS tackles,
        MAX(CASE WHEN measure_code = 'tackles_successful'     THEN value::INTEGER      END) AS tackles_successful,
        MAX(CASE WHEN measure_code = 'interceptions'          THEN value::INTEGER      END) AS interceptions,
        MAX(CASE WHEN measure_code = 'clearances'             THEN value::INTEGER      END) AS clearances,
        MAX(CASE WHEN measure_code = 'aerial_duels'           THEN value::INTEGER      END) AS aerial_duels,
        MAX(CASE WHEN measure_code = 'aerial_duels_successful' THEN value::INTEGER     END) AS aerial_duels_successful,
        MAX(CASE WHEN measure_code = 'goalkeeper_saves'       THEN value::INTEGER      END) AS goalkeeper_saves,
        -- Match flow and set pieces
        MAX(CASE WHEN measure_code = 'fouls'                  THEN value::INTEGER      END) AS fouls,
        MAX(CASE WHEN measure_code = 'offsides'               THEN value::INTEGER      END) AS offsides,
        MAX(CASE WHEN measure_code = 'attacks'                THEN value::INTEGER      END) AS attacks,
        MAX(CASE WHEN measure_code = 'free_kicks'             THEN value::INTEGER      END) AS free_kicks,
        MAX(CASE WHEN measure_code = 'goal_kicks'             THEN value::INTEGER      END) AS goal_kicks,
        MAX(CASE WHEN measure_code = 'throw_ins'              THEN value::INTEGER      END) AS throw_ins
    FROM {{ ref('fixture_statistics') }}
    GROUP BY fixture_id, team_id
),
main_referee AS (
    -- type_id 6 is the Sportmonks code for the match referee. Highlightly
    -- reports exactly one official per match and no type at all, so gating on
    -- the code alone would silently leave every new-league match refereeless.
    SELECT
        fr.fixture_id,
        fr._source,
        fr.referee_id,
        -- folded through the same alias seed dim_referee uses, or a drifted
        -- spelling would fail to find its own dimension member
        COALESCE(a.canonical_name, fr.referee_name) AS referee_name
    FROM {{ ref('fixture_referees') }} fr
    LEFT JOIN {{ ref('referee_name_aliases') }} a ON a.alias_name = fr.referee_name
    WHERE (fr._source = 'sportmonks' AND fr.type_id = 6)
       OR (fr._source = 'highlightly' AND fr.referee_name IS NOT NULL)
),
src AS (
    SELECT
        f.fixture_id,
        f.league_id,
        f.starting_at,
        f.venue_id,
        f.venue_name,
        f.stage_type,
        f.stage_name,
        f.group_name,
        f.round_name,
        -- carried only to resolve the dimension joins below; the surrogate
        -- keys already encode provenance, so it never reaches the fact
        f._source,
        mt.team_id,
        mt.location,
        mt.opponent_team_id,
        mr.referee_id,
        mr.referee_name,
        f.is_finished,
        co.coach_id,
        fo.formation,
        CASE WHEN f.is_finished THEN COALESCE(scf.goals_scored_corrected, sc.goals_scored,  0) END AS goals_scored,
        CASE WHEN f.is_finished THEN COALESCE(oscf.goals_scored_corrected, osc.goals_scored, 0) END AS goals_conceded,
        CASE WHEN f.is_finished THEN COALESCE(sc.goals_ht_scored,  0) END AS goals_ht_scored,
        -- "of which" measures: both are already inside goals_scored, so they
        -- must never be added to it.
        CASE WHEN f.is_finished THEN COALESCE(etg.et_goals,  0) END AS goals_scored_extra_time,
        CASE WHEN f.is_finished THEN COALESCE(oetg.et_goals, 0) END AS goals_conceded_extra_time,
        -- A shootout is not part of the score: NULL when there wasn't one.
        ss.shootout_goals  AS goals_scored_penalty_shootout,
        oss.shootout_goals AS goals_conceded_penalty_shootout,
        CASE WHEN f.is_finished THEN COALESCE(osc.goals_ht_scored, 0) END AS goals_ht_conceded,
        CASE WHEN f.is_finished THEN COALESCE(st.corner_kicks,     0) END AS corner_kicks,
        CASE WHEN f.is_finished THEN st.ball_possession_pct          END AS ball_possession_pct,
        CASE WHEN f.is_finished THEN COALESCE(st.yellow_cards,     0) END AS yellow_cards,
        CASE WHEN f.is_finished THEN COALESCE(st.red_cards,        0) END AS red_cards,
        -- Deliberately no COALESCE to 0, unlike the four measures above: for
        -- these an absent stat row means the provider never recorded the
        -- measure, not that the value was zero.
        CASE WHEN f.is_finished THEN st.shots_on_target         END AS shots_on_target,
        CASE WHEN f.is_finished THEN st.shots_off_target        END AS shots_off_target,
        CASE WHEN f.is_finished THEN st.shots_blocked           END AS shots_blocked,
        CASE WHEN f.is_finished THEN st.shots_inside_box        END AS shots_inside_box,
        CASE WHEN f.is_finished THEN st.shots_outside_box       END AS shots_outside_box,
        CASE WHEN f.is_finished THEN st.expected_goals          END AS expected_goals,
        CASE WHEN f.is_finished THEN st.expected_assists        END AS expected_assists,
        CASE WHEN f.is_finished THEN st.big_chances_created     END AS big_chances_created,
        CASE WHEN f.is_finished THEN st.key_passes              END AS key_passes,
        CASE WHEN f.is_finished THEN st.passes_total            END AS passes_total,
        CASE WHEN f.is_finished THEN st.passes_successful       END AS passes_successful,
        CASE WHEN f.is_finished THEN st.passes_failed           END AS passes_failed,
        CASE WHEN f.is_finished THEN st.passes_final_third      END AS passes_final_third,
        CASE WHEN f.is_finished THEN st.passes_opposition_half  END AS passes_opposition_half,
        CASE WHEN f.is_finished THEN st.passes_own_half         END AS passes_own_half,
        CASE WHEN f.is_finished THEN st.passes_backward         END AS passes_backward,
        CASE WHEN f.is_finished THEN st.long_passes             END AS long_passes,
        CASE WHEN f.is_finished THEN st.long_passes_successful  END AS long_passes_successful,
        CASE WHEN f.is_finished THEN st.crosses                 END AS crosses,
        CASE WHEN f.is_finished THEN st.crosses_successful      END AS crosses_successful,
        CASE WHEN f.is_finished THEN st.dribbles                END AS dribbles,
        CASE WHEN f.is_finished THEN st.dribbles_successful     END AS dribbles_successful,
        CASE WHEN f.is_finished THEN st.tackles                 END AS tackles,
        CASE WHEN f.is_finished THEN st.tackles_successful      END AS tackles_successful,
        CASE WHEN f.is_finished THEN st.interceptions           END AS interceptions,
        CASE WHEN f.is_finished THEN st.clearances              END AS clearances,
        CASE WHEN f.is_finished THEN st.aerial_duels            END AS aerial_duels,
        CASE WHEN f.is_finished THEN st.aerial_duels_successful END AS aerial_duels_successful,
        CASE WHEN f.is_finished THEN st.goalkeeper_saves        END AS goalkeeper_saves,
        CASE WHEN f.is_finished THEN st.fouls                   END AS fouls,
        CASE WHEN f.is_finished THEN st.offsides                END AS offsides,
        CASE WHEN f.is_finished THEN st.attacks                 END AS attacks,
        CASE WHEN f.is_finished THEN st.free_kicks              END AS free_kicks,
        CASE WHEN f.is_finished THEN st.goal_kicks              END AS goal_kicks,
        CASE WHEN f.is_finished THEN st.throw_ins               END AS throw_ins
    FROM all_fixtures f
    JOIN  match_teams       mt   ON mt.fixture_id  = f.fixture_id
    LEFT JOIN scores              sc   ON sc.fixture_id  = f.fixture_id AND sc.team_id  = mt.team_id
    LEFT JOIN scores              osc  ON osc.fixture_id = f.fixture_id AND osc.team_id = mt.opponent_team_id
    LEFT JOIN score_corrections   scf  ON scf.fixture_id = f.fixture_id AND scf.team_id = mt.team_id
    LEFT JOIN score_corrections   oscf ON oscf.fixture_id = f.fixture_id AND oscf.team_id = mt.opponent_team_id
    LEFT JOIN stats         st   ON st.fixture_id  = f.fixture_id AND st.team_id  = mt.team_id
    LEFT JOIN shootout_scores   ss   ON ss.fixture_id  = f.fixture_id AND ss.team_id  = mt.team_id          AND ss._source  = f._source
    LEFT JOIN shootout_scores   oss  ON oss.fixture_id = f.fixture_id AND oss.team_id = mt.opponent_team_id AND oss._source = f._source
    LEFT JOIN extra_time_goals  etg  ON etg.fixture_id = f.fixture_id AND etg.team_id = mt.team_id          AND etg._source = f._source
    LEFT JOIN extra_time_goals  oetg ON oetg.fixture_id = f.fixture_id AND oetg.team_id = mt.opponent_team_id AND oetg._source = f._source
    LEFT JOIN main_referee  mr   ON mr.fixture_id  = f.fixture_id AND mr._source = f._source
    LEFT JOIN coaches       co   ON co.fixture_id  = f.fixture_id AND co.team_id = mt.team_id
    LEFT JOIN formations    fo   ON fo.fixture_id  = f.fixture_id AND fo.team_id = mt.team_id
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
    COALESCE(dc.coach_sk,          -1) AS coach_sk,
    COALESCE(df.formation_sk,      -1) AS formation_sk,
    CASE src.location
        WHEN 'home' THEN 1
        WHEN 'away' THEN 2
        ELSE -1
    END                                AS team_side_sk,
    CASE
        WHEN NOT src.is_finished                        THEN 4
        WHEN src.goals_scored > src.goals_conceded      THEN 1
        WHEN src.goals_scored = src.goals_conceded      THEN 2
        ELSE                                                 3
    END                                AS match_result_sk,
    CASE
        WHEN NOT src.is_finished                   THEN NULL
        -- Knockout phases inside a league (e.g. a title play-off) are league
        -- matches but put nothing on the table -> NULL, not 0.
        WHEN NOT {{ awards_league_points('src.league_id', 'src.stage_type', 'src.stage_name',
                                        'src.group_name', 'src.round_name') }}
                                                   THEN NULL
        WHEN src.goals_scored > src.goals_conceded THEN 3
        WHEN src.goals_scored = src.goals_conceded THEN 1
        ELSE                                            0
    END                                AS points_earned,
    src.goals_scored,
    src.goals_conceded,
    src.goals_ht_scored,
    src.goals_ht_conceded,
    src.goals_scored_extra_time,
    src.goals_conceded_extra_time,
    src.goals_scored_penalty_shootout,
    src.goals_conceded_penalty_shootout,
    src.corner_kicks,
    src.ball_possession_pct,
    src.yellow_cards,
    src.red_cards,
    src.shots_on_target,
    src.shots_off_target,
    src.shots_blocked,
    src.shots_inside_box,
    src.shots_outside_box,
    src.expected_goals,
    src.expected_assists,
    src.big_chances_created,
    src.key_passes,
    src.passes_total,
    src.passes_successful,
    src.passes_failed,
    src.passes_final_third,
    src.passes_opposition_half,
    src.passes_own_half,
    src.passes_backward,
    src.long_passes,
    src.long_passes_successful,
    src.crosses,
    src.crosses_successful,
    src.dribbles,
    src.dribbles_successful,
    src.tackles,
    src.tackles_successful,
    src.interceptions,
    src.clearances,
    src.aerial_duels,
    src.aerial_duels_successful,
    src.goalkeeper_saves,
    src.fouls,
    src.offsides,
    src.attacks,
    src.free_kicks,
    src.goal_kicks,
    src.throw_ins
FROM src
LEFT JOIN {{ ref('dim_date') }}          dd      ON dd.date              = src.starting_at::DATE
LEFT JOIN {{ ref('dim_time') }}          dt_time ON dt_time.time_sk      = EXTRACT(hour FROM (src.starting_at::TIMESTAMP AT TIME ZONE 'UTC') AT TIME ZONE {{ league_local_tz('src.league_id') }})::INTEGER
-- Provider-keyed dims match on (natural key, _source): an id identifies an
-- entity only within the feed that minted it.
LEFT JOIN {{ ref('dim_team') }}          dteam   ON dteam.team_id        = src.team_id             AND dteam._source = src._source
LEFT JOIN {{ ref('dim_opponent_team') }} dopp    ON dopp.opponent_team_id = src.opponent_team_id   AND dopp._source  = src._source
LEFT JOIN {{ ref('dim_league') }}        dl      ON dl.league_id         = src.league_id           AND dl._source    = src._source
-- likewise on the durable key: Highlightly names its grounds but mints no
-- venue id, so the fixture's venue_name is the identity
LEFT JOIN {{ ref('dim_stadium') }}       ds      ON ds.stadium_key       = COALESCE({{ canonical_venue_id('src.venue_id') }}::VARCHAR, src.venue_name) AND ds._source = src._source
-- resolved on the durable key: Highlightly mints no referee id, so its
-- officials are identified by name
LEFT JOIN {{ ref('dim_referee') }}       dr      ON dr.referee_key       = COALESCE(src.referee_id::VARCHAR, src.referee_name) AND dr._source = src._source
LEFT JOIN {{ ref('dim_match') }}          dm      ON dm.match_id          = src.fixture_id         AND dm._source    = src._source
LEFT JOIN {{ ref('dim_coach') }}          dc      ON dc.coach_id          = src.coach_id           AND dc._source    = src._source
LEFT JOIN {{ ref('dim_formation') }}      df      ON df.formation         = src.formation
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
