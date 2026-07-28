-- Row-level basis for the La Liga table: one row per (team, played match).
-- The page aggregates it, so the table can be recomputed "as of round N"
-- without another round-trip.
--
-- Every La Liga match is a regular-season match — a double round-robin with
-- no championship split and no play-off — so there is no round filter here and
-- the round number is the round number.
--
-- `opponent_team_sk` is here for one reason: La Liga separates clubs on equal
-- points by their head-to-head record, not by goal difference, so the page has
-- to be able to rebuild the mini-table between tied clubs. Ranking Granada's
-- 2020/21 season on goal difference puts them below Athletic Club, one place
-- off where the league put them, despite a goal difference 22 worse: the two
-- split the meetings, and Granada took it on head-to-head goal difference.
SELECT
    m.match_id,
    d.date                       AS match_date,
    d.season_spain              AS season,
    d.is_current_season_spain   AS is_current_season,
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
WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 119924)
  AND r.match_result IN ('Win', 'Draw', 'Loss')
  AND d.season_spain IS NOT NULL
