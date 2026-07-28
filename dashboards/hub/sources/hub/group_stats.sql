-- All-time, group-wide numbers across every league platform.
--
-- The league roster is taken from dim_league rather than a hardcoded id list,
-- so adding a league is one CASE arm here instead of a filter to keep in sync.
-- dim_league carries two sentinel rows ("Unknown League", "Not Applicable
-- League") with a NULL league_id; every count excludes them.
WITH played AS (
    SELECT
        dl.league_id,
        CASE dl.league_id
            WHEN 271    THEN d.season_denmark
            WHEN 501    THEN d.season_scotland
            WHEN 223746 THEN d.season_mexico
            WHEN 173537 THEN d.season_turkey
            WHEN 119924 THEN d.season_spain
        END                    AS season,
        f.match_sk,
        f.goals_scored
    FROM superligaen.gold.fct_team_matches  f
    JOIN superligaen.gold.dim_league        dl ON dl.league_sk      = f.league_sk
    JOIN superligaen.gold.dim_date          d  ON d.date_sk         = f.date_sk
    JOIN superligaen.gold.dim_match_result  r  ON r.match_result_sk = f.match_result_sk
    WHERE dl.league_id IS NOT NULL
      AND r.match_result IN ('Win', 'Draw', 'Loss')
)
SELECT
    -- Every league we hold, straight off the dimension - not only those with
    -- matches in the fact, so a league counts from the moment it is ingested.
    (SELECT COUNT(*)
     FROM superligaen.gold.dim_league
     WHERE league_id IS NOT NULL)                   AS leagues,
    COUNT(DISTINCT league_id || '·' || season)      AS seasons,
    COUNT(DISTINCT match_sk)                        AS matches,
    SUM(goals_scored)                               AS goals,
    -- Everyone in the platform, whether or not they have played a minute.
    -- Appearance data only exists for some leagues, so counting minutes here
    -- would report those leagues rather than the platform.
    (SELECT COUNT(*)
     FROM superligaen.gold.dim_player
     WHERE player_id IS NOT NULL)                   AS players,
    (SELECT COUNT(DISTINCT transfer_id)
     FROM superligaen.gold.fct_team_transfers)      AS transfers
FROM played
