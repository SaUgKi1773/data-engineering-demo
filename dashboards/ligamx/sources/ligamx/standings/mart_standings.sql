-- Row-level basis for the Liga MX table: one row per (team, regular-season
-- match). The page aggregates it, so the table can be recomputed "as of round
-- N" without another round-trip.
--
-- Liga MX differs from the European leagues on this platform in three ways
-- that matter here:
--   * A season year holds TWO separate competitions, Apertura and Clausura,
--     each with its own table and champion. `tournament` is the unit, not the
--     season year.
--   * It is a SINGLE round-robin: 18 teams, 17 rounds, everyone plays everyone
--     once. A table is complete at 17 games, not 34.
--   * The table does not decide the title. It seeds the liguilla. Only the
--     17 regular rounds are included below; liguilla matches award no points
--     and are handled by mart_liguilla.
SELECT
    m.match_id,
    d.date                       AS match_date,
    d.season_mexico              AS tournament,
    d.is_current_season_mexico   AS is_current_tournament,
    m.match_round_number         AS round,
    t.team_sk,
    t.team_name,
    t.team_short_name,
    t.team_code,
    t.team_logo,
    r.match_result               AS result,
    f.goals_scored,
    f.goals_conceded,
    f.points_earned
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date          d ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_match         m ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_team          t ON t.team_sk         = f.team_sk
JOIN superligaen.gold.dim_match_result  r ON r.match_result_sk = f.match_result_sk
WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
  AND m.match_round_type = 'Regular Season'
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND d.season_mexico IS NOT NULL
