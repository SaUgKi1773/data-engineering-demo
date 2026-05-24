WITH player_agg AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_on_target)     AS shots_on_goal,
        SUM(shots_total)         AS total_shots,
        SUM(big_chances_created) AS big_chances_created
    FROM superligaen.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
),
base AS (
    SELECT
        m.match_id,
        d.date                              AS match_date,
        d.season,
        d.is_current_season,
        m.match_round_number,
        m.match_round_name,
        m.match_name,
        m.match_short_name,
        m.match_result                      AS score,
        ref.referee_common_name             AS referee_name,
        r.match_result                      AS result,
        f.goals_scored,
        f.yellow_cards,
        f.red_cards,
        COALESCE(pa.shots_on_goal, 0)       AS shots_on_goal,
        COALESCE(pa.total_shots, 0)         AS total_shots,
        COALESCE(pa.big_chances_created, 0) AS big_chances_created
    FROM superligaen.gold.fct_team_matches    f
    JOIN superligaen.gold.dim_date            d   ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match           m   ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result    r   ON r.match_result_sk = f.match_result_sk
    JOIN superligaen.gold.dim_referee         ref ON ref.referee_sk    = f.referee_sk
    LEFT JOIN player_agg                      pa  ON pa.match_sk       = f.match_sk
                                               AND pa.team_sk          = f.team_sk
    WHERE m.match_type = 'Group Stage'
      AND d.season >= '2020/21'
)
SELECT
    match_id,
    match_date,
    season,
    is_current_season,
    match_round_number,
    match_round_name,
    match_name,
    match_short_name,
    score,
    referee_name,
    SUM(goals_scored)         AS total_goals,
    SUM(shots_on_goal)        AS total_shots_on_goal,
    SUM(total_shots)          AS total_shots,
    SUM(big_chances_created)  AS total_big_chances,
    SUM(yellow_cards)         AS total_yellow_cards,
    SUM(red_cards)            AS total_red_cards
FROM base
WHERE result IN ('Win', 'Draw', 'Loss')
GROUP BY
    match_id, match_date, season, is_current_season,
    match_round_number, match_round_name, match_name, match_short_name,
    score, referee_name
ORDER BY match_date DESC
