-- Headline numbers for the current Liga MX tournament.
--
-- Deliberately exposes the SAME column contract as the Danish and Scottish
-- mart_home_summary (season, season_is_live, total_*, leader_name/short) so
-- the home page can be an exact twin of theirs. Only the meaning behind the
-- columns is Mexican:
--
--   * `season` is a TOURNAMENT, not a season year. Apertura and Clausura are
--     separate competitions with separate tables and separate champions, so a
--     season year produces two of these rather than one.
--   * `leader_name` is the club top of the regular table while the tournament
--     is live, and the club that actually WON once it has ended — which in
--     Mexico is frequently not the same club, since the title is decided in
--     the liguilla and the top seed has taken it in only half of the
--     completed tournaments we hold.
WITH matches AS (
    SELECT
        d.season_mexico            AS season,
        d.is_current_season_mexico AS season_is_live,
        d.date,
        f.match_sk,
        f.team_sk,
        f.goals_scored,
        f.goals_conceded,
        f.points_earned,
        f.goals_scored_penalty_shootout,
        f.goals_conceded_penalty_shootout,
        m.match_round_type
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date         d ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match        m ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND d.season_mexico IS NOT NULL
),
-- The most recent tournament, by match date. String ordering would happen to
-- work today (Apertura sorts before Clausura, and also runs first), but that
-- is a coincidence of the labels rather than a fact about the calendar.
latest_season AS (
    SELECT season
    FROM matches
    GROUP BY season
    ORDER BY MAX(date) DESC
    LIMIT 1
),
-- Regular-season table. Liguilla matches award no table points.
team_pts AS (
    SELECT
        m.team_sk,
        SUM(m.points_earned)                        AS pts,
        SUM(m.goals_scored) - SUM(m.goals_conceded) AS gd,
        SUM(m.goals_scored)                         AS gf
    FROM matches m
    JOIN latest_season ls ON m.season = ls.season
    WHERE m.match_round_type = 'Regular Season'
    GROUP BY m.team_sk
),
table_leader AS (
    SELECT team_sk FROM team_pts ORDER BY pts DESC, gd DESC, gf DESC LIMIT 1
),
-- Champion: the final is a TWO-LEGGED tie decided in three steps, and all
-- three have to be modelled or the answer is wrong. Aggregate across both
-- legs; if level, extra time (already inside goals_scored, which is the
-- full-time score); if still level, the shootout.
--
-- Reading only the second leg finds no champion at all in Apertura 2024/25,
-- where América won leg one 2-1 and drew leg two 1-1, taking the title 3-2 on
-- aggregate having won neither the second leg nor a shootout.
final_agg AS (
    SELECT
        m.team_sk,
        SUM(m.goals_scored)                    AS agg_for,
        SUM(m.goals_conceded)                  AS agg_against,
        MAX(m.goals_scored_penalty_shootout)   AS pens_for,
        MAX(m.goals_conceded_penalty_shootout) AS pens_against
    FROM matches m
    JOIN latest_season ls ON m.season = ls.season
    WHERE m.match_round_type = 'Final'
    GROUP BY m.team_sk
),
champion AS (
    SELECT team_sk
    FROM final_agg
    WHERE agg_for > agg_against
       OR (agg_for = agg_against AND pens_for > pens_against)
),
-- Live tournament -> the table leader. Finished tournament -> the club that
-- actually lifted it.
winner AS (
    SELECT COALESCE(
        (SELECT team_sk FROM champion),
        (SELECT team_sk FROM table_leader)
    ) AS team_sk
)
SELECT
    ls.season,
    BOOL_OR(m.season_is_live)  AS season_is_live,
    COUNT(DISTINCT m.match_sk) AS total_matches,
    SUM(m.goals_scored)        AS total_goals,
    COUNT(DISTINCT m.team_sk)  AS total_teams,
    MAX(t.team_name)           AS leader_name,
    MAX(t.team_short_name)     AS leader_short,
    -- the WINNER's own points, not the table leader's. Once a tournament has
    -- ended those are two different clubs half the time, and reading them from
    -- the table leader would caption the champion with someone else's total.
    MAX(wp.pts)                AS leader_pts
FROM matches m
JOIN latest_season ls ON m.season = ls.season
CROSS JOIN winner w
JOIN superligaen.gold.dim_team t ON t.team_sk = w.team_sk
LEFT JOIN team_pts wp ON wp.team_sk = w.team_sk
GROUP BY ls.season
