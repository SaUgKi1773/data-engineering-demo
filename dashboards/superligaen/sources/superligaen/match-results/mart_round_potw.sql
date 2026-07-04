WITH base AS (
    SELECT
        d.season,
        m.match_round_number,
        p.player_name,
        p.player_photo,
        t.team_name,
        t.team_logo,
        dpos.position_group,
        f.rating,
        f.minutes_played
    FROM superligaen.gold.fct_player_appearances   f
    JOIN superligaen.gold.dim_date                 d      ON d.date_sk               = f.date_sk
    JOIN superligaen.gold.dim_match                m      ON m.match_sk              = f.match_sk
    JOIN superligaen.gold.dim_player               p      ON p.player_sk             = f.player_sk
    JOIN superligaen.gold.dim_team                 t      ON t.team_sk               = f.team_sk
    JOIN superligaen.gold.dim_match_result         r      ON r.match_result_sk       = f.match_result_sk
    JOIN superligaen.gold.dim_appearance_type      at_dim ON at_dim.appearance_type_sk = f.appearance_type_sk
    JOIN superligaen.gold.dim_position             dpos   ON dpos.position_sk        = f.position_sk
    WHERE d.season >= '2020/21'
      AND r.match_result IN ('Win', 'Draw', 'Loss')
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 271)  -- Superliga only
      AND f.rating IS NOT NULL
      AND f.minutes_played >= 30
),
overall AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY season, match_round_number
                           ORDER BY rating DESC, minutes_played DESC) AS rn_best,
        ROW_NUMBER() OVER (PARTITION BY season, match_round_number
                           ORDER BY rating ASC,  minutes_played DESC) AS rn_worst
    FROM base
),
position_awards AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY season, match_round_number, position_group
                           ORDER BY rating DESC, minutes_played DESC) AS rn_pos
    FROM overall
    WHERE rn_best != 1
)
SELECT season, match_round_number, 'MVP'             AS category, '⭐' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR) AS stat_value, 'Rating' AS stat_label, 1 AS sort_order
FROM overall WHERE rn_best = 1
UNION ALL
SELECT season, match_round_number, 'Best Attacker'   AS category, '⚽' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR), 'Rating', 2
FROM position_awards WHERE position_group = 'Attacker'   AND rn_pos = 1
UNION ALL
SELECT season, match_round_number, 'Best Midfielder'  AS category, '🎯' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR), 'Rating', 3
FROM position_awards WHERE position_group = 'Midfielder'  AND rn_pos = 1
UNION ALL
SELECT season, match_round_number, 'Best Defender'   AS category, '🛡️' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR), 'Rating', 4
FROM position_awards WHERE position_group = 'Defender'   AND rn_pos = 1
UNION ALL
SELECT season, match_round_number, 'Best GK'         AS category, '🧤' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR), 'Rating', 5
FROM position_awards WHERE position_group = 'Goalkeeper' AND rn_pos = 1
UNION ALL
SELECT season, match_round_number, 'LVP'             AS category, '📉' AS icon,
       player_name, player_photo, team_name, team_logo,
       CAST(ROUND(rating, 2) AS VARCHAR), 'Rating', 6
FROM overall WHERE rn_worst = 1
ORDER BY season, match_round_number, sort_order
