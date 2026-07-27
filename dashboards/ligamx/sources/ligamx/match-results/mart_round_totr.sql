-- Teams of the Round: the standout team performance in each of six categories,
-- one row per (tournament, round, category).
--
-- This is the Liga MX answer to the Danish Players of the Week. Liga MX has no
-- player-level data at all - no appearances, no ratings, no minutes - so there
-- is nobody to award. Its team-level feed is the deeper of the two, so the
-- award moves up a level: same six-card shelf, clubs instead of players.
--
-- Every category is emitted for every round even when nothing can win it, so
-- the shelf never changes shape from one round to the next. xG and big chances
-- only exist from 2024/25 Clausura, and a round with no cards has no card
-- winner; those cards render as an em dash rather than disappearing.
WITH base AS (
    SELECT
        d.season_mexico                                     AS tournament,
        CASE m.match_round_type
            WHEN 'Regular Season'  THEN m.match_round_number
            WHEN 'Reclasificación' THEN 18
            WHEN 'Play-offs'       THEN 19
            WHEN 'Quarter-finals'  THEN 20
            WHEN 'Semi-finals'     THEN 21
            WHEN 'Final'           THEN 22
        END                                                 AS round_order,
        t.team_name,
        t.team_short_name,
        t.team_logo,
        ot.opponent_team_short_name,
        f.goals_scored,
        f.expected_goals,
        f.ball_possession_pct,
        f.shots_on_target,
        f.big_chances_created,
        COALESCE(f.yellow_cards, 0) + COALESCE(f.red_cards, 0) AS cards
    FROM superligaen.gold.fct_team_matches   f
    JOIN superligaen.gold.dim_date           d  ON d.date_sk           = f.date_sk
    JOIN superligaen.gold.dim_match          m  ON m.match_sk          = f.match_sk
    JOIN superligaen.gold.dim_team           t  ON t.team_sk           = f.team_sk
    JOIN superligaen.gold.dim_opponent_team  ot ON ot.opponent_team_sk = f.opponent_team_sk
    JOIN superligaen.gold.dim_match_result   r  ON r.match_result_sk   = f.match_result_sk
    WHERE r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)  -- Liga MX only
      AND d.season_mexico IS NOT NULL
),
ranked AS (
    -- team_name breaks every tie, so a redeploy never reshuffles the winners
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY goals_scored        DESC NULLS LAST, team_name) AS rn_goals,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY expected_goals      DESC NULLS LAST, team_name) AS rn_xg,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY ball_possession_pct DESC NULLS LAST, team_name) AS rn_poss,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY shots_on_target     DESC NULLS LAST, team_name) AS rn_sog,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY big_chances_created DESC NULLS LAST, team_name) AS rn_bc,
        ROW_NUMBER() OVER (PARTITION BY tournament, round_order
                           ORDER BY cards               DESC NULLS LAST, team_name) AS rn_cards
    FROM base
),
picks AS (
    SELECT tournament, round_order, 1 AS sort_order, team_name, team_short_name, team_logo,
           opponent_team_short_name, goals_scored::VARCHAR AS stat_value
    FROM ranked WHERE rn_goals = 1 AND goals_scored IS NOT NULL
    UNION ALL
    SELECT tournament, round_order, 2, team_name, team_short_name, team_logo,
           opponent_team_short_name, printf('%.2f', expected_goals)
    FROM ranked WHERE rn_xg = 1 AND expected_goals IS NOT NULL
    UNION ALL
    SELECT tournament, round_order, 3, team_name, team_short_name, team_logo,
           opponent_team_short_name, printf('%.0f%%', ball_possession_pct)
    FROM ranked WHERE rn_poss = 1 AND ball_possession_pct IS NOT NULL
    UNION ALL
    SELECT tournament, round_order, 4, team_name, team_short_name, team_logo,
           opponent_team_short_name, shots_on_target::VARCHAR
    FROM ranked WHERE rn_sog = 1 AND shots_on_target IS NOT NULL
    UNION ALL
    SELECT tournament, round_order, 5, team_name, team_short_name, team_logo,
           opponent_team_short_name, big_chances_created::VARCHAR
    FROM ranked WHERE rn_bc = 1 AND big_chances_created IS NOT NULL
    UNION ALL
    SELECT tournament, round_order, 6, team_name, team_short_name, team_logo,
           opponent_team_short_name, cards::VARCHAR
    FROM ranked WHERE rn_cards = 1 AND cards > 0
),
rounds AS (
    SELECT DISTINCT tournament, round_order FROM base
),
categories AS (
    SELECT * FROM (VALUES
        ('Top Scorer',          '⚽',  'Goals',          1),
        ('Best xG',             '🎯',  'Expected Goals', 2),
        ('Most Possession',     '🕹️',  'Possession',     3),
        ('Most Shots on Goal',  '🥅',  'On Target',      4),
        ('Most Big Chances',    '💥',  'Big Chances',    5),
        ('Most Cards',          '🟨',  'Cards',          6)
    ) AS v(category, icon, stat_label, sort_order)
)
SELECT
    r.tournament,
    r.round_order,
    c.category,
    c.icon,
    c.stat_label,
    c.sort_order,
    p.team_name,
    p.team_short_name,
    p.team_logo,
    p.opponent_team_short_name,
    p.stat_value
FROM rounds r
CROSS JOIN categories c
LEFT JOIN picks p ON p.tournament  = r.tournament
                 AND p.round_order = r.round_order
                 AND p.sort_order  = c.sort_order
ORDER BY r.tournament, r.round_order, c.sort_order
