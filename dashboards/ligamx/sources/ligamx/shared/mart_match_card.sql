-- One row per match, home and away pivoted onto the same row. Purpose-built
-- for the head-to-head block on the Match Preview page, so it carries only the
-- columns that block reads - the full stat sheet lives in mart_match_results.
--
-- Every match since 2020/21 Apertura is here, liguilla ties included: a
-- head-to-head history that silently dropped knockout meetings would be the
-- wrong history in a league where the knockout is the title.
--
-- Shots on goal and big chances come straight off the team fact. Big chances
-- only exist from 2024/25 Clausura, when the deep-stat feed starts, and stay
-- NULL before that - never 0, which would read as "no big chances created".
SELECT
    m.match_id,
    MAX(d.date)                                                                 AS match_date,
    MAX(d.season_mexico)                                                        AS tournament,
    MAX(CASE m.match_round_type
            WHEN 'Regular Season'  THEN m.match_round_number
            WHEN 'Reclasificación' THEN 18
            WHEN 'Play-offs'       THEN 19
            WHEN 'Quarter-finals'  THEN 20
            WHEN 'Semi-finals'     THEN 21
            WHEN 'Final'           THEN 22
        END)                                                                    AS round_order,
    MAX(CASE m.match_round_type
            WHEN 'Regular Season' THEN m.match_round_number::VARCHAR
            WHEN 'Play-offs'      THEN 'Play-in'
            ELSE m.match_round_type
        END)                                                                    AS round_label,
    MAX(CASE m.match_round_type
            WHEN 'Regular Season' THEN 'Round ' || m.match_round_number::VARCHAR
            WHEN 'Play-offs'      THEN 'Play-in'
            ELSE m.match_round_type
        END)                                                                    AS round_display,
    MAX(m.match_result)                                                         AS score,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name             END)       AS home_team,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name             END)       AS away_team,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_short_name       END)       AS home_team_short,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_short_name       END)       AS away_team_short,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_scored          END)       AS home_goals,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_scored          END)       AS away_goals,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.shots_on_target       END)       AS home_sog,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.shots_on_target       END)       AS away_sog,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.big_chances_created   END)       AS home_big_chances,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.big_chances_created   END)       AS away_big_chances
FROM superligaen.gold.fct_team_matches  f
JOIN superligaen.gold.dim_date          d  ON d.date_sk       = f.date_sk
JOIN superligaen.gold.dim_match         m  ON m.match_sk      = f.match_sk
JOIN superligaen.gold.dim_team          t  ON t.team_sk       = f.team_sk
JOIN superligaen.gold.dim_team_side     ts ON ts.team_side_sk = f.team_side_sk
WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
  AND d.season_mexico IS NOT NULL
GROUP BY m.match_id
