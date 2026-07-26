-- Headline numbers for the current Liga MX tournament.
--
-- Exposes the same column contract as the Danish and Scottish
-- mart_home_summary (season, season_is_live, total_*, leader_name/short) so
-- the home page stays a twin of theirs, plus two columns Mexico needs:
-- `state` and `liguilla_round`.
--
-- A Liga MX tournament passes through THREE phases, and the banner says a
-- different thing in each:
--
--   Leader    the 17 regular rounds are being played -> the club top of the
--             table, which is a real, current standing.
--   Liguilla  the table is final and the knockout is under way -> the round
--             being played. Deliberately NOT a club: there is no leader any
--             more, and the club that topped the table is frequently already
--             out. Across the twelve completed tournaments here the top seed
--             was eliminated before the final in five of them.
--   Champion  the final is complete -> the club that won it.
--
-- `season` is a TOURNAMENT, not a season year: Apertura and Clausura are
-- separate competitions with separate tables and separate champions, so a
-- season year produces two of these rather than one.
WITH fixtures AS (
    -- Every fixture, finished or not. The unfinished ones matter for one
    -- reason only: telling a final that is over from one that is half played.
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
        m.match_round_type,
        r.match_result
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date         d ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match        m ON m.match_sk        = f.match_sk
    JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND d.season_mexico IS NOT NULL
),
matches AS (
    SELECT * FROM fixtures WHERE match_result IN ('Win', 'Draw', 'Loss')
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
current_fixtures AS (
    SELECT f.* FROM fixtures f JOIN latest_season ls ON f.season = ls.season
),
current_matches AS (
    SELECT * FROM current_fixtures WHERE match_result IN ('Win', 'Draw', 'Loss')
),
-- Regular-season table. Liguilla matches award no table points.
team_pts AS (
    SELECT
        team_sk,
        SUM(points_earned)                      AS pts,
        SUM(goals_scored) - SUM(goals_conceded) AS gd,
        SUM(goals_scored)                       AS gf
    FROM current_matches
    WHERE match_round_type = 'Regular Season'
    GROUP BY team_sk
),
table_leader AS (
    SELECT team_sk FROM team_pts ORDER BY pts DESC, gd DESC, gf DESC LIMIT 1
),
-- Is the final actually over? A two-legged tie read at half time crowns the
-- wrong club: whoever happens to lead after leg one. So the champion is only
-- resolved once every scheduled final fixture has been played.
final_progress AS (
    SELECT
        COUNT(DISTINCT match_sk) AS scheduled,
        COUNT(DISTINCT CASE WHEN match_result IN ('Win', 'Draw', 'Loss') THEN match_sk END) AS played
    FROM current_fixtures
    WHERE match_round_type = 'Final'
),
-- Champion: aggregate across both legs; if level, extra time (already inside
-- goals_scored, which is the full-time score); if still level, the shootout.
--
-- Reading only the second leg finds no champion at all in Apertura 2024/25,
-- where América won leg one 2-1 and drew leg two 1-1, taking the title 3-2 on
-- aggregate having won neither the second leg nor a shootout.
final_agg AS (
    SELECT
        team_sk,
        SUM(goals_scored)                    AS agg_for,
        SUM(goals_conceded)                  AS agg_against,
        MAX(goals_scored_penalty_shootout)   AS pens_for,
        MAX(goals_conceded_penalty_shootout) AS pens_against
    FROM current_matches
    WHERE match_round_type = 'Final'
    GROUP BY team_sk
),
champion AS (
    SELECT f.team_sk
    FROM final_agg f
    CROSS JOIN final_progress p
    WHERE p.scheduled > 0
      AND p.played = p.scheduled
      AND (f.agg_for > f.agg_against
           OR (f.agg_for = f.agg_against AND f.pens_for > f.pens_against))
),
-- How far the knockout has got, by the deepest round with a completed match.
-- Reading the deepest SCHEDULED round instead would jump the banner ahead to
-- a round nobody has played yet as soon as fixtures are published.
liguilla_progress AS (
    SELECT MAX(CASE match_round_type
                   WHEN 'Reclasificación' THEN 1
                   WHEN 'Play-offs'       THEN 2
                   WHEN 'Quarter-finals'  THEN 3
                   WHEN 'Semi-finals'     THEN 4
                   WHEN 'Final'           THEN 5
               END) AS depth
    FROM current_matches
    WHERE match_round_type <> 'Regular Season'
),
-- Champion first, then the knockout, then the regular season.
phase AS (
    SELECT
        CASE
            WHEN (SELECT COUNT(*) FROM champion) > 0            THEN 'Champion'
            WHEN COALESCE((SELECT depth FROM liguilla_progress), 0) > 0 THEN 'Liguilla'
            ELSE 'Leader'
        END AS state,
        CASE (SELECT depth FROM liguilla_progress)
            WHEN 1 THEN 'Play-in'
            WHEN 2 THEN 'Play-in'
            WHEN 3 THEN 'Quarter-finals'
            WHEN 4 THEN 'Semi-finals'
            WHEN 5 THEN 'Final'
        END AS liguilla_round
),
-- The club the banner names. Only read in the Leader and Champion states —
-- in the Liguilla state the page shows the round instead, because this would
-- be the top seed, who may well have been knocked out.
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
    MAX(p.state)               AS state,
    MAX(p.liguilla_round)      AS liguilla_round,
    MAX(t.team_name)           AS leader_name,
    MAX(t.team_short_name)     AS leader_short,
    -- the NAMED club's own points, not the table leader's. Once a tournament
    -- has ended those are different clubs half the time, and reading them
    -- from the table leader would caption the champion with someone else's
    -- total.
    MAX(wp.pts)                AS leader_pts
FROM current_matches m
CROSS JOIN latest_season ls
CROSS JOIN phase p
CROSS JOIN winner w
JOIN superligaen.gold.dim_team t ON t.team_sk = w.team_sk
LEFT JOIN team_pts wp ON wp.team_sk = w.team_sk
GROUP BY ls.season
