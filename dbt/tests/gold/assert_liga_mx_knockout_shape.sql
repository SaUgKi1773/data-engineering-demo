-- Liga MX's liguilla has a fixed shape: four quarter-final ties, two
-- semi-final ties and one final, each played over two legs - 8, 4 and 2
-- matches. Any tournament that has reached the knockout stage must show
-- exactly that.
--
-- This is a structural check on the round conformance, not on the source. The
-- provider has already mislabelled a tournament's play-in matches as
-- "Semi-finals" and "Final" (Apertura 2025, corrected by seed); had this test
-- existed then, it would have caught it as 6 semi-finals and 3 finals.
--
-- The play-in is deliberately NOT asserted: its size changes with the format
-- (four repechaje matches through 2022/23, three play-in matches since), and
-- one tournament is missing it at source entirely.
WITH knockout_shape AS (
    SELECT
        d.season_mexico                     AS tournament,
        dm.match_round_type,
        COUNT(DISTINCT f.match_sk)          AS matches
    FROM {{ ref('fct_team_matches') }} f
    JOIN {{ ref('dim_match') }}  dm ON dm.match_sk  = f.match_sk
    JOIN {{ ref('dim_date') }}   d  ON d.date_sk    = f.date_sk
    JOIN {{ ref('dim_league') }} dl ON dl.league_sk = f.league_sk
    WHERE dl.league_id = 223746
      AND dm.match_round_type IN ('Quarter-finals', 'Semi-finals', 'Final')
      AND d.season_mexico IS NOT NULL
    GROUP BY 1, 2
)
SELECT tournament, match_round_type, matches
FROM knockout_shape
WHERE matches != CASE match_round_type
                     WHEN 'Quarter-finals' THEN 8
                     WHEN 'Semi-finals'    THEN 4
                     WHEN 'Final'          THEN 2
                 END
