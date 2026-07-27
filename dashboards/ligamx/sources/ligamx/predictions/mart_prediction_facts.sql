-- Prediction module facts: one row per team per predicted fixture, scored and
-- pending alike. Row-level so the page can slice by tournament and team; all
-- aggregation happens over this small parquet.
-- The model pick is computed once from the home perspective and mirrored to the
-- away row, so both sides of a match always agree on what the model called.
--
-- Liga MX notes:
--   * `tournament` (Apertura / Clausura) is the unit, not the season year.
--   * The model only predicts regular-season rounds, which are the only ones
--     that put points on the table - a liguilla tie awards none.
--   * `standings_type` is a constant here. Denmark splits into championship
--     and relegation groups after the regular rounds; Liga MX does not split,
--     so the page's group legend simply never appears.
WITH match_pick AS (
    SELECT
        p.match_sk,
        CASE
            WHEN p.win_probability  >= p.draw_probability
             AND p.win_probability  >= p.loss_probability THEN 'Win'
            WHEN p.loss_probability >= p.draw_probability  THEN 'Loss'
            ELSE 'Draw'
        END AS home_pick
    FROM superligaen.gold.fct_match_predictions p
    WHERE p.team_side_sk = 1
),
base AS (
    SELECT
        d.date                                  AS match_date,
        d.season_mexico                         AS tournament,
        d.is_current_season_mexico              AS is_current_tournament,
        CASE m.match_round_type
            WHEN 'Regular Season'  THEN m.match_round_number
            WHEN 'Reclasificación' THEN 18
            WHEN 'Play-offs'       THEN 19
            WHEN 'Quarter-finals'  THEN 20
            WHEN 'Semi-finals'     THEN 21
            WHEN 'Final'           THEN 22
        END::INT                                AS round_order,
        CASE m.match_round_type
            WHEN 'Regular Season' THEN m.match_round_number::VARCHAR
            WHEN 'Play-offs'      THEN 'Play-in'
            ELSE m.match_round_type
        END                                     AS round_label,
        'Regular Season'                        AS standings_type,
        m.match_id,
        m.match_result                          AS score,
        t.team_name,
        t.team_short_name,
        ot.opponent_team_name,
        ot.opponent_team_short_name,
        CASE p.team_side_sk WHEN 1 THEN 'Home' ELSE 'Away' END AS team_side,
        p.win_probability,
        p.draw_probability,
        p.loss_probability,
        p.predicted_goals_scored,
        p.predicted_goals_conceded,
        p.predicted_points,
        CASE
            WHEN p.team_side_sk = 1 THEN mp.home_pick
            ELSE CASE mp.home_pick WHEN 'Win' THEN 'Loss' WHEN 'Loss' THEN 'Win' ELSE 'Draw' END
        END                                     AS model_pick,
        r.match_result                          AS actual_result,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        r.match_result IN ('Win', 'Draw', 'Loss') AS is_scored,
        CASE
            WHEN r.match_result IN ('Win', 'Draw', 'Loss')
            THEN model_pick = r.match_result
        END                                     AS hit
    FROM superligaen.gold.fct_match_predictions p
    JOIN match_pick                          mp ON mp.match_sk         = p.match_sk
    JOIN superligaen.gold.fct_team_matches   f  ON f.match_sk          = p.match_sk
                                               AND f.team_side_sk      = p.team_side_sk
    JOIN superligaen.gold.dim_match_result   r  ON r.match_result_sk   = f.match_result_sk
    JOIN superligaen.gold.dim_match          m  ON m.match_sk          = p.match_sk
    JOIN superligaen.gold.dim_date           d  ON d.date_sk           = p.date_sk
    JOIN superligaen.gold.dim_team           t  ON t.team_sk           = p.team_sk
    JOIN superligaen.gold.dim_opponent_team  ot ON ot.opponent_team_sk = p.opponent_team_sk
    WHERE p.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
      AND d.season_mexico IS NOT NULL
)
SELECT * FROM base
UNION ALL
-- sentinel row so parquet is never empty (filtered out in page queries via match_id IS NOT NULL)
SELECT
    date '1900-01-01',      -- match_date
    '0000/00 - Apertura',   -- tournament
    false,                  -- is_current_tournament
    0,                      -- round_order
    NULL,                   -- round_label
    NULL,                   -- standings_type
    NULL, NULL,             -- match_id, score
    NULL, NULL,             -- team_name, team_short_name
    NULL, NULL,             -- opponent_team_name, opponent_team_short_name
    NULL,                   -- team_side
    NULL, NULL, NULL,       -- win/draw/loss probability
    NULL, NULL, NULL,       -- predicted goals scored/conceded, predicted_points
    NULL, NULL,             -- model_pick, actual_result
    NULL, NULL, NULL,       -- goals_scored, goals_conceded, points_earned
    NULL, NULL              -- is_scored, hit
WHERE NOT EXISTS (SELECT 1 FROM base)
ORDER BY match_date DESC
