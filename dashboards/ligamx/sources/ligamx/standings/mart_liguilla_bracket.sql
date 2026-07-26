-- The liguilla as a bracket: one row per TIE, not per match.
--
-- Liga MX decides its title in a knockout, so the regular table alone tells
-- you almost nothing about who won. This feeds a Champions-League-style
-- bracket sitting above the table.
--
-- Three things make this harder than a European knockout:
--
--  1. A tie is usually TWO legs, so the unit is a team pair within a round,
--     not a match. Pairs are keyed on LEAST/GREATEST of the two surrogate
--     keys so both legs collapse onto the same tie regardless of who hosted.
--
--  2. The bracket shape CHANGES between eras. 2020/21-2022/23 ran a
--     four-match repechaje; from 2023/24 it is a two-stage play-in
--     (Reclasificación, then Play-offs). Nothing here assumes a fixed number
--     of ties per round — whatever rounds exist for a tournament are what
--     gets rendered.
--
--  3. A level aggregate does NOT mean a shootout. In the quarter-finals and
--     semi-finals the better-seeded club simply goes through: 13 of 48 QF
--     ties and 8 of 24 SF ties in our data finish level with no shootout
--     played. Only the final goes to penalties.
--
-- Because of (3), the winner of a two-legged QF/SF tie is derived from who
-- actually turns up in the NEXT round rather than from a scoring rule. That
-- is deliberate — Mexican competition rules change often, and reading the
-- outcome off the fixtures records what happened instead of what a rule said
-- should happen. Single-leg play-in matches and the final are decided by the
-- score, since both are always resolved on the day.
WITH ko AS (
    SELECT
        d.season_mexico AS tournament,
        d.date,
        f.match_sk,
        f.team_sk,
        f.opponent_team_sk,
        f.goals_scored,
        f.goals_scored_penalty_shootout,
        f.goals_scored_extra_time,
        CASE m.match_round_type
            WHEN 'Reclasificación' THEN 1
            WHEN 'Play-offs'       THEN 2
            WHEN 'Quarter-finals'  THEN 3
            WHEN 'Semi-finals'     THEN 4
            WHEN 'Final'           THEN 5
        END AS round_order,
        m.match_round_type AS round_type
    FROM superligaen.gold.fct_team_matches f
    JOIN superligaen.gold.dim_date  d ON d.date_sk  = f.date_sk
    JOIN superligaen.gold.dim_match m ON m.match_sk = f.match_sk
    WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
      AND m.match_round_type IN ('Reclasificación', 'Play-offs', 'Quarter-finals', 'Semi-finals', 'Final')
      AND d.season_mexico IS NOT NULL
),
-- Regular-season finishing position. It seeds the bracket, orders the ties
-- within a round, and is what breaks a level QF/SF aggregate.
seeds AS (
    SELECT
        tournament,
        team_sk,
        ROW_NUMBER() OVER (
            PARTITION BY tournament
            ORDER BY pts DESC, gd DESC, gf DESC
        ) AS seed
    FROM (
        SELECT
            d.season_mexico AS tournament,
            f.team_sk,
            SUM(f.points_earned)                        AS pts,
            SUM(f.goals_scored) - SUM(f.goals_conceded) AS gd,
            SUM(f.goals_scored)                         AS gf
        FROM superligaen.gold.fct_team_matches f
        JOIN superligaen.gold.dim_date         d ON d.date_sk         = f.date_sk
        JOIN superligaen.gold.dim_match        m ON m.match_sk        = f.match_sk
        JOIN superligaen.gold.dim_match_result r ON r.match_result_sk = f.match_result_sk
        WHERE f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 223746)
          AND m.match_round_type = 'Regular Season'
          AND r.match_result IN ('Win', 'Draw', 'Loss')
          AND d.season_mexico IS NOT NULL
        GROUP BY 1, 2
    )
),
-- Who was still playing in each round — used to resolve two-legged ties.
appearances AS (
    SELECT DISTINCT tournament, round_order, team_sk FROM ko
),
tie AS (
    SELECT
        tournament,
        round_type,
        round_order,
        LEAST(team_sk, opponent_team_sk)    AS lo_sk,
        GREATEST(team_sk, opponent_team_sk) AS hi_sk,
        COUNT(DISTINCT match_sk)            AS n_legs,
        MIN(date)                           AS first_leg,
        MAX(date)                           AS last_leg,
        SUM(CASE WHEN team_sk = LEAST(team_sk, opponent_team_sk)    THEN goals_scored END) AS agg_lo,
        SUM(CASE WHEN team_sk = GREATEST(team_sk, opponent_team_sk) THEN goals_scored END) AS agg_hi,
        MAX(CASE WHEN team_sk = LEAST(team_sk, opponent_team_sk)    THEN goals_scored_penalty_shootout END) AS pens_lo,
        MAX(CASE WHEN team_sk = GREATEST(team_sk, opponent_team_sk) THEN goals_scored_penalty_shootout END) AS pens_hi,
        SUM(COALESCE(goals_scored_extra_time, 0))                                          AS et_goals
    FROM ko
    GROUP BY 1, 2, 3, 4, 5
),
-- Orient each tie so the better-seeded club is side A, the way a bracket is
-- always drawn.
oriented AS (
    SELECT
        t.*,
        COALESCE(sl.seed, 99) AS seed_lo,
        COALESCE(sh.seed, 99) AS seed_hi,
        COALESCE(sl.seed, 99) <= COALESCE(sh.seed, 99) AS lo_is_a
    FROM tie t
    LEFT JOIN seeds sl ON sl.tournament = t.tournament AND sl.team_sk = t.lo_sk
    LEFT JOIN seeds sh ON sh.tournament = t.tournament AND sh.team_sk = t.hi_sk
),
sided AS (
    SELECT
        tournament, round_type, round_order, n_legs, first_leg, last_leg, et_goals,
        CASE WHEN lo_is_a THEN lo_sk   ELSE hi_sk   END AS team_a_sk,
        CASE WHEN lo_is_a THEN seed_lo ELSE seed_hi END AS team_a_seed,
        CASE WHEN lo_is_a THEN agg_lo  ELSE agg_hi  END AS team_a_goals,
        CASE WHEN lo_is_a THEN pens_lo ELSE pens_hi END AS team_a_pens,
        CASE WHEN lo_is_a THEN hi_sk   ELSE lo_sk   END AS team_b_sk,
        CASE WHEN lo_is_a THEN seed_hi ELSE seed_lo END AS team_b_seed,
        CASE WHEN lo_is_a THEN agg_hi  ELSE agg_lo  END AS team_b_goals,
        CASE WHEN lo_is_a THEN pens_hi ELSE pens_lo END AS team_b_pens
    FROM oriented
),
resolved AS (
    SELECT
        s.*,
        -- did each side turn up in the following round?
        (na.team_sk IS NOT NULL) AS a_advanced,
        (nb.team_sk IS NOT NULL) AS b_advanced
    FROM sided s
    LEFT JOIN appearances na
           ON na.tournament  = s.tournament
          AND na.team_sk     = s.team_a_sk
          AND na.round_order = s.round_order + 1
    LEFT JOIN appearances nb
           ON nb.tournament  = s.tournament
          AND nb.team_sk     = s.team_b_sk
          AND nb.round_order = s.round_order + 1
)
SELECT
    r.tournament,
    r.round_type,
    r.round_order,
    r.n_legs,
    r.first_leg,
    r.last_leg,
    r.team_a_seed,
    ta.team_name       AS team_a_name,
    ta.team_short_name AS team_a_short,
    ta.team_logo       AS team_a_logo,
    r.team_a_goals,
    r.team_a_pens,
    r.team_b_seed,
    tb.team_name       AS team_b_name,
    tb.team_short_name AS team_b_short,
    tb.team_logo       AS team_b_logo,
    r.team_b_goals,
    r.team_b_pens,
    -- Score first for the ties that are always settled on the pitch; the
    -- next-round appearance for the two-legged rounds where a level aggregate
    -- is settled by seeding instead.
    CASE
        WHEN r.team_a_goals > r.team_b_goals THEN 'A'
        WHEN r.team_b_goals > r.team_a_goals THEN 'B'
        WHEN COALESCE(r.team_a_pens, 0) > COALESCE(r.team_b_pens, 0) THEN 'A'
        WHEN COALESCE(r.team_b_pens, 0) > COALESCE(r.team_a_pens, 0) THEN 'B'
        WHEN r.a_advanced AND NOT r.b_advanced THEN 'A'
        WHEN r.b_advanced AND NOT r.a_advanced THEN 'B'
        -- a level two-legged tie whose round has no successor is the final,
        -- and every final in the data resolves above
        ELSE NULL
    END AS winner_side,
    CASE
        WHEN r.team_a_goals <> r.team_b_goals AND r.n_legs > 1 THEN 'Aggregate'
        WHEN r.team_a_goals <> r.team_b_goals AND r.et_goals > 0 THEN 'Extra time'
        WHEN r.team_a_goals <> r.team_b_goals THEN 'Full time'
        WHEN COALESCE(r.team_a_pens, 0) <> COALESCE(r.team_b_pens, 0) THEN 'Penalties'
        ELSE 'Seeding'
    END AS decided_by
FROM resolved r
JOIN superligaen.gold.dim_team ta ON ta.team_sk = r.team_a_sk
JOIN superligaen.gold.dim_team tb ON tb.team_sk = r.team_b_sk
