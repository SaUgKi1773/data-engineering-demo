-- Row-level basis for the Süper Lig table: one row per (team, played match).
-- The page aggregates it, so the table can be recomputed "as of round N"
-- without another round-trip.
--
-- Every Süper Lig match is a regular-season match — a double round-robin with
-- no championship split and no play-off — so there is no round filter here and
-- the round number is the round number.
--
-- `opponent_team_sk` is here for one reason: the Süper Lig separates clubs on
-- equal points by their head-to-head record, not by goal difference, so the
-- page has to be able to rebuild the mini-table between tied clubs. Ranking
-- Kasımpaşa's 2023/24 season on goal difference puts them below Beşiktaş, one
-- place off where the league put them, having beaten them twice.
SELECT
    m.match_id,
    d.date                       AS match_date,
    d.season_turkey              AS season,
    d.is_current_season_turkey   AS is_current_season,
    m.match_round_number         AS round,
    t.team_sk,
    f.opponent_team_sk,
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
WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 173537)
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND d.season_turkey IS NOT NULL
