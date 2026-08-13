-- THE FACT TABLE — one row per club per day of football.
--
-- Club grain rather than league grain, because a league total is just the sum
-- of its clubs and this way one model answers both questions. Every column is
-- an additive count, so any set of days sums correctly and rates are computed
-- afterwards; each measure carries its own match count, because a rate must
-- divide by the matches that reported it rather than by every match played.
--
-- From 2020, the platform-wide cutoff. Earlier Danish rows store 0 rather than
-- NULL for measures the feed was not yet carrying, and counted as real they
-- drag a long-run average to less than half the truth.
WITH by_player AS (
    SELECT a.match_sk, a.team_sk,
        SUM(a.shots_on_target) AS shots_on_target, SUM(a.passes_total) AS passes,
        SUM(a.passes_accurate) AS passes_accurate, SUM(a.fouls_committed) AS fouls,
        SUM(a.offsides) AS offsides, SUM(a.saves) AS saves
    FROM superligaen.gold.fct_player_appearances a GROUP BY 1,2
)
SELECT
    t.team_name,
    t.team_code,
    l.league_name,
    l.league_country,
    d.date                                              AS match_date,
    d.year                                              AS calendar_year,
    d.month_name,
    d.day_name,
    ts.team_side,
    COUNT(*)                                            AS matches,
    SUM(f.goals_scored)                                 AS goals_for,
    SUM(f.goals_conceded)                               AS goals_against,
    COUNT(*) FILTER (WHERE r.match_result = 'Win')      AS wins,
    COUNT(*) FILTER (WHERE r.match_result = 'Draw')     AS draws,
    COUNT(*) FILTER (WHERE r.match_result = 'Loss')     AS losses,
    COUNT(*) FILTER (WHERE f.goals_conceded = 0)        AS clean_sheets,
    SUM(f.points_earned)                                AS points,
    SUM(f.corner_kicks)                                 AS corners,     COUNT(f.corner_kicks) AS n_corners,
    SUM(f.yellow_cards)                                 AS yellow_cards,
    SUM(f.red_cards)                                    AS red_cards,   COUNT(f.yellow_cards) AS n_cards,
    SUM(COALESCE(f.shots_on_target, p.shots_on_target))   AS shots_on_target,
    COUNT(COALESCE(f.shots_on_target, p.shots_on_target)) AS n_shots,
    SUM(COALESCE(f.passes_total, p.passes))               AS passes,
    SUM(COALESCE(f.passes_successful, p.passes_accurate)) AS passes_accurate,
    COUNT(COALESCE(f.passes_total, p.passes))             AS n_passes,
    SUM(COALESCE(f.fouls, p.fouls))                       AS fouls,     COUNT(COALESCE(f.fouls, p.fouls))    AS n_fouls,
    SUM(COALESCE(f.offsides, p.offsides))                 AS offsides,  COUNT(COALESCE(f.offsides, p.offsides)) AS n_offsides,
    SUM(COALESCE(f.goalkeeper_saves, p.saves))            AS saves,     COUNT(COALESCE(f.goalkeeper_saves, p.saves)) AS n_saves
FROM superligaen.gold.fct_team_matches f
JOIN superligaen.gold.dim_league       l  ON l.league_sk       = f.league_sk
JOIN superligaen.gold.dim_date         d  ON d.date_sk         = f.date_sk
JOIN superligaen.gold.dim_team         t  ON t.team_sk         = f.team_sk
JOIN superligaen.gold.dim_match        m  ON m.match_sk        = f.match_sk
JOIN superligaen.gold.dim_match_result r  ON r.match_result_sk = f.match_result_sk
JOIN superligaen.gold.dim_team_side    ts ON ts.team_side_sk   = f.team_side_sk
LEFT JOIN by_player p ON p.match_sk = f.match_sk AND p.team_sk = f.team_sk
WHERE r.match_result IN ('Win','Draw','Loss')
  AND m.match_type = 'Regular League'
  AND d.year >= 2020
  AND ts.team_side IN ('Home','Away')
GROUP BY 1,2,3,4,5,6,7,8,9
