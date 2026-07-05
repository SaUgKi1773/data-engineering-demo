-- All-time, group-wide numbers across every league platform.
WITH played AS (
    SELECT
        dl.league_id,
        CASE dl.league_id
            WHEN 271 THEN d.season_denmark
            WHEN 501 THEN d.season_scotland
        END                    AS season,
        f.match_sk,
        f.goals_scored
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_league        dl ON dl.league_sk      = f.league_sk
    JOIN superligaen.gold.dim_date          d  ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match_result  r  ON r.match_result_sk = f.match_result_sk
    WHERE dl.league_id IN (271, 501)
      AND r.match_result IN ('Win', 'Draw', 'Loss')
)
SELECT
    COUNT(DISTINCT league_id)                       AS leagues,
    COUNT(DISTINCT league_id || '·' || season)      AS seasons,
    COUNT(DISTINCT match_sk)                        AS matches,
    SUM(goals_scored)                               AS goals,
    (SELECT COUNT(DISTINCT pa.player_sk)
     FROM superligaen.gold.fct_player_appearances pa
     JOIN superligaen.gold.dim_league dl ON dl.league_sk = pa.league_sk
     WHERE dl.league_id IN (271, 501)
       AND pa.minutes_played > 0)                   AS players,
    (SELECT COUNT(DISTINCT transfer_id)
     FROM superligaen.gold.fct_team_transfers)      AS transfers
FROM played
