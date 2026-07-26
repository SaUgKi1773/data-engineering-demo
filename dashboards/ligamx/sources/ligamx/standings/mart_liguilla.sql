-- How far each club actually got in the liguilla, per tournament.
--
-- This is the column a Liga MX table needs and a European one does not. The
-- regular table only seeds the knockout, so finishing top says nothing about
-- who won: in Clausura 2025 Toluca topped the table and won the title, but
-- 3rd-placed Cruz Azul reached the semi-finals while 5th-placed Necaxa went
-- out in the quarters.
--
-- Rounds are ordered by how deep they are, and the deepest one a club appears
-- in is how far it went. A club that appears in the Final could still have
-- lost it, so `won_title` is resolved separately from the second leg.
WITH rounds AS (
    SELECT
        d.season_mexico       AS tournament,
        f.team_sk,
        m.match_round_type,
        CASE m.match_round_type
            WHEN 'Reclasificación' THEN 1
            WHEN 'Play-offs'       THEN 2
            WHEN 'Quarter-finals'  THEN 3
            WHEN 'Semi-finals'     THEN 4
            WHEN 'Final'           THEN 5
        END                   AS depth
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date  d ON d.date_sk  = f.date_sk
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND m.match_round_type IN ('Reclasificación', 'Play-offs', 'Quarter-finals', 'Semi-finals', 'Final')
      AND d.season_mexico IS NOT NULL
),
deepest AS (
    SELECT tournament, team_sk, MAX(depth) AS depth
    FROM rounds
    GROUP BY 1, 2
)
SELECT
    tournament,
    team_sk,
    depth,
    CASE depth
        WHEN 1 THEN 'Play-in'
        WHEN 2 THEN 'Play-in'
        WHEN 3 THEN 'Quarter-finals'
        WHEN 4 THEN 'Semi-finals'
        WHEN 5 THEN 'Final'
    END AS reached
FROM deepest
