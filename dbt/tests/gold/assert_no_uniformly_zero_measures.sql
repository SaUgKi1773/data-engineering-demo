-- No measure may be zero on every recorded row of an entire league.
--
-- This is the check that would have caught #482. Half-time goals were 0 on all
-- 13,018 rows of the three Highlightly leagues, because the provider publishes
-- no half-time score and the missing value was COALESCEd to zero. Nothing else
-- could catch it: 0 is a legal half-time score, so the column looked recorded,
-- looked plausible, and answered "level at the break" for 100% of matches.
--
-- The general shape of that trap is a measure the feed omits whose zero is
-- believable, so the assertion is made over every measure at once rather than
-- the two that happened to fail. A league that genuinely never records a
-- measure leaves it NULL and is not counted here - that is the contract.
--
-- The extra-time pair is excluded: a league whose format has no knockout round
-- plays no extra time, so all-zero is the true answer for Denmark, Scotland,
-- La Liga and the Süper Lig. Liga MX has a liguilla and does report them.
--
-- The 100-row floor keeps a league in its first weeks from failing on a measure
-- that simply has not happened yet.
WITH measures AS (
    UNPIVOT (
        SELECT * EXCLUDE (
            date_sk, time_sk, team_sk, opponent_team_sk, stadium_sk, referee_sk,
            match_sk, coach_sk, formation_sk, team_side_sk, match_result_sk,
            goals_scored_extra_time, goals_conceded_extra_time
        )
        FROM {{ ref('fct_team_matches') }}
        WHERE match_result_sk IN (1, 2, 3)
    )
    ON COLUMNS (* EXCLUDE (league_sk))
    INTO NAME measure VALUE value
)
SELECT
    league_sk,
    measure,
    COUNT(value) AS recorded_rows
FROM measures
GROUP BY league_sk, measure
HAVING COUNT(value) > 100
   AND MAX(value) = 0
