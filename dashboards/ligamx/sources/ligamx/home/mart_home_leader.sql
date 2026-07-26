-- Who leads, and who actually won — two different questions in Liga MX.
--
-- On the European sites the club top of the table at the end of the season is
-- the champion. Here it is only the top seed: the title is decided by the
-- liguilla. So this source resolves both, and the home page must not label
-- the table leader a champion.
--
-- The champion is the club that won the second leg of the Final, or took the
-- shootout when the tie finished level on aggregate.
WITH regular AS (
    SELECT
        d.season_mexico AS tournament,
        f.team_sk,
        SUM(f.points_earned)                        AS points,
        SUM(f.goals_scored) - SUM(f.goals_conceded) AS gd,
        SUM(f.goals_scored)                         AS gf
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date  d ON d.date_sk  = f.date_sk
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND m.match_round_type = 'Regular Season'
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND d.season_mexico IS NOT NULL
    GROUP BY 1, 2
),
top_seed AS (
    SELECT tournament, team_sk
    FROM regular
    QUALIFY ROW_NUMBER() OVER (PARTITION BY tournament ORDER BY points DESC, gd DESC, gf DESC) = 1
),
-- The final is a TWO-LEGGED tie, decided in three steps, and all three have
-- to be modelled or the answer is wrong:
--
--   1. Aggregate across both legs.
--   2. If the aggregate is level, the second leg goes to extra time. Those
--      goals are already inside goals_scored, which is the full-time score
--      including extra time, so the aggregate below accounts for them without
--      a separate term.
--   3. If it is still level after extra time, a shootout settles it.
--
-- Reading only the second leg gets this wrong, and not rarely. In Apertura
-- 2024/25 América won leg one 2-1 and drew leg two 1-1, taking the title 3-2
-- on aggregate having won neither the second leg nor a shootout.
final_agg AS (
    SELECT
        d.season_mexico AS tournament,
        f.team_sk,
        SUM(f.goals_scored)                    AS agg_for,
        SUM(f.goals_conceded)                  AS agg_against,
        -- only the leg that went to a shootout carries these
        MAX(f.goals_scored_penalty_shootout)   AS pens_for,
        MAX(f.goals_conceded_penalty_shootout) AS pens_against
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date  d ON d.date_sk  = f.date_sk
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND m.match_round_type = 'Final'
      AND d.season_mexico IS NOT NULL
    GROUP BY 1, 2
),
champion AS (
    SELECT tournament, team_sk
    FROM final_agg
    WHERE agg_for > agg_against
       OR (agg_for = agg_against AND pens_for > pens_against)
)
SELECT
    r.tournament,
    ts.team_sk                       AS top_seed_sk,
    tst.team_short_name              AS top_seed,
    tst.team_logo                    AS top_seed_logo,
    ch.team_sk                       AS champion_sk,
    cht.team_short_name              AS champion,
    cht.team_logo                    AS champion_logo
FROM (SELECT DISTINCT tournament FROM regular) r
LEFT JOIN top_seed  ts  ON ts.tournament = r.tournament
LEFT JOIN champion  ch  ON ch.tournament = r.tournament
LEFT JOIN superligaen.gold.dim_team tst ON tst.team_sk = ts.team_sk
LEFT JOIN superligaen.gold.dim_team cht ON cht.team_sk = ch.team_sk
