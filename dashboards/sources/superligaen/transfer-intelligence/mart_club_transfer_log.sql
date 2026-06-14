-- Row-level transfer log from the perspective of each league club (the deal log
-- behind the aggregates). One row per (transfer, league club). Powers the club
-- detail table and the league-wide record-fee tables.
WITH league_clubs AS (
    SELECT DISTINCT team_sk FROM superligaen.gold.fct_team_matches WHERE team_sk > 0
),
enriched AS (
    SELECT
        f.transfer_id,
        (CASE WHEN d.month >= 7 THEN d.year ELSE d.year - 1 END) AS season_start_year,
        d.date AS transfer_date,
        CASE WHEN d.month IN (6, 7, 8) THEN 'Summer'
             WHEN d.month IN (1, 2)    THEN 'Winter'
             ELSE 'Other' END AS transfer_window,
        t.team_name  AS club,
        t.team_logo  AS club_logo,
        tt.transfer_direction AS direction,
        tt.transfer_type_name AS transfer_type,
        tt.transfer_nature    AS nature,
        tt.transfer_basis     AS basis,
        tt.is_fee_bearing,
        p.player_name,
        p.player_photo,
        p.player_main_position AS position,
        pt.transfer_partner_team_name    AS partner,
        pt.transfer_partner_team_logo    AS partner_logo,
        pt.transfer_partner_team_country AS partner_country,
        f.transfer_fee_eur AS fee_eur
    FROM superligaen.gold.fct_team_transfers       f
    JOIN league_clubs                              lc ON lc.team_sk = f.team_sk
    JOIN superligaen.gold.dim_team                 t  ON t.team_sk = f.team_sk
    JOIN superligaen.gold.dim_date                 d  ON d.date_sk = f.date_sk
    JOIN superligaen.gold.dim_transfer_type        tt ON tt.transfer_type_sk = f.transfer_type_sk
    JOIN superligaen.gold.dim_player               p  ON p.player_sk = f.player_sk
    JOIN superligaen.gold.dim_transfer_partner_team pt ON pt.transfer_partner_team_sk = f.transfer_partner_team_sk
    WHERE f.date_sk <> -1
)
SELECT
    transfer_id,
    season_start_year,
    (season_start_year || '/' || right((season_start_year + 1)::varchar, 2)) AS season,
    transfer_window,
    transfer_date,
    club,
    club_logo,
    direction,
    transfer_type,
    nature,
    basis,
    is_fee_bearing,
    CASE WHEN player_name IN ('Unknown Player', 'Not Applicable Player') THEN NULL ELSE player_name END AS player_name,
    player_photo,
    position,
    partner,
    partner_logo,
    partner_country,
    fee_eur
FROM enriched
WHERE season_start_year >= 2015
