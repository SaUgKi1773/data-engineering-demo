-- Fact: match results
-- Grain: one row per team per fixture (each match produces 2 rows).
-- Dimensions must be built before this table.
--
-- {delete_filter} / {insert_filter} examples:
--   incremental  : date_sk >= 20260412 AND date_sk <= 20260512
--   full reload  : TRUE
CREATE SCHEMA IF NOT EXISTS {db}.gold;

CREATE TABLE IF NOT EXISTS {db}.gold.fct_match_results (
    date_sk             INTEGER       NOT NULL,
    time_sk             INTEGER       NOT NULL,
    team_sk             INTEGER       NOT NULL,
    opponent_sk         INTEGER       NOT NULL,
    league_sk           INTEGER       NOT NULL,
    venue_sk            INTEGER       NOT NULL,
    referee_sk          INTEGER       NOT NULL,
    round_sk            INTEGER       NOT NULL,
    match_role_sk       INTEGER       NOT NULL,
    result_sk           INTEGER       NOT NULL,
    fixture_id          INTEGER       NOT NULL,
    points_earned       INTEGER,
    goals_scored        INTEGER,
    goals_conceded      INTEGER,
    goals_ht_scored     INTEGER,
    goals_ht_conceded   INTEGER,
    shots_on_goal       INTEGER,
    shots_off_goal      INTEGER,
    total_shots         INTEGER,
    blocked_shots       INTEGER,
    shots_insidebox     INTEGER,
    shots_outsidebox    INTEGER,
    ball_possession_pct DECIMAL(5,2),
    total_passes        INTEGER,
    passes_accurate     INTEGER,
    passes_pct          DECIMAL(5,2),
    fouls               INTEGER,
    corner_kicks        INTEGER,
    offsides            INTEGER,
    yellow_cards        INTEGER,
    red_cards           INTEGER,
    goalkeeper_saves    INTEGER,
    expected_goals      DECIMAL(6,3)
);

DELETE FROM {db}.gold.fct_match_results WHERE {delete_filter};

INSERT INTO {db}.gold.fct_match_results
SELECT * FROM (
    WITH fixture_teams AS (
        SELECT
            f.fixture_id,
            f.kick_off::DATE                         AS match_date,
            EXTRACT(hour FROM f.kick_off)::INTEGER    AS kick_off_hour,
            f.league_id,
            f.season,
            f.league_round,
            f.referee,
            f.venue_id,
            f.home_team_id                            AS team_id,
            f.away_team_id                            AS opponent_id,
            1                                         AS match_role_sk,
            f.goals_home                              AS goals_scored,
            f.goals_away                              AS goals_conceded,
            f.score_ht_home                           AS goals_ht_scored,
            f.score_ht_away                           AS goals_ht_conceded,
            f.status_short
        FROM {db}.silver.fixtures f
        UNION ALL
        SELECT
            f.fixture_id,
            f.kick_off::DATE,
            EXTRACT(hour FROM f.kick_off)::INTEGER,
            f.league_id,
            f.season,
            f.league_round,
            f.referee,
            f.venue_id,
            f.away_team_id,
            f.home_team_id,
            2,
            f.goals_away,
            f.goals_home,
            f.score_ht_away,
            f.score_ht_home,
            f.status_short
        FROM {db}.silver.fixtures f
    )
    SELECT
        d.date_sk,
        t.time_sk,
        tm.team_sk,
        opp.team_sk                                                          AS opponent_sk,
        l.league_sk,
        COALESCE(v.venue_sk,     -1)                                         AS venue_sk,
        COALESCE(ref.referee_sk, -1)                                         AS referee_sk,
        COALESCE(rnd.round_sk,   -1)                                         AS round_sk,
        ft.match_role_sk,
        CASE
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  > ft.goals_conceded THEN 1   -- Win
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  = ft.goals_conceded THEN 2   -- Draw
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  < ft.goals_conceded THEN 3   -- Loss
            WHEN ft.status_short IN ('NS', 'TBD', '1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE')
                                                              THEN 4   -- Pending
            WHEN ft.status_short IN ('PST', 'CANC', 'ABD', 'AWD', 'WO', 'SUSP', 'INT')
                                                              THEN -2  -- Not Applicable
            ELSE -1                                                    -- Unknown
        END                                                                  AS result_sk,
        ft.fixture_id,
        CASE
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  > ft.goals_conceded THEN 3
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  = ft.goals_conceded THEN 1
            WHEN ft.status_short IN ('FT', 'AET', 'PEN')
                 AND ft.goals_scored  < ft.goals_conceded THEN 0
            ELSE NULL
        END                                                                  AS points_earned,
        ft.goals_scored,
        ft.goals_conceded,
        ft.goals_ht_scored,
        ft.goals_ht_conceded,
        s.shots_on_goal,
        s.shots_off_goal,
        s.total_shots,
        s.blocked_shots,
        s.shots_insidebox,
        s.shots_outsidebox,
        s.ball_possession_pct,
        s.total_passes,
        s.passes_accurate,
        s.passes_pct,
        s.fouls,
        s.corner_kicks,
        s.offsides,
        s.yellow_cards,
        s.red_cards,
        s.goalkeeper_saves,
        s.expected_goals
    FROM fixture_teams ft
    JOIN      {db}.gold.dim_date     d   ON d.full_date      = ft.match_date
    JOIN      {db}.gold.dim_time     t   ON t.time_sk        = ft.kick_off_hour
    JOIN      {db}.gold.dim_team     tm  ON tm.team_id       = ft.team_id
    JOIN      {db}.gold.dim_team     opp ON opp.team_id      = ft.opponent_id
    JOIN      {db}.gold.dim_league   l   ON l.league_id      = ft.league_id
    LEFT JOIN {db}.gold.dim_venue    v   ON v.venue_id       = ft.venue_id
    LEFT JOIN {db}.gold.dim_referee  ref ON ref.referee_name = ft.referee
    LEFT JOIN {db}.gold.dim_round    rnd ON rnd.league_id    = ft.league_id
                                        AND rnd.season       = ft.season
                                        AND rnd.round_name   = ft.league_round
    LEFT JOIN {db}.silver.fixture_statistics s
                                            ON s.fixture_id  = ft.fixture_id
                                           AND s.team_id     = ft.team_id
) _src WHERE {insert_filter};
