-- Single source for the Transfer Intelligence page: row-level transfer log from
-- the perspective of each league club. One row per (transfer, league club),
-- included only for years the club actually played a league match (a
-- fct_team_matches record in that calendar year). Every KPI / chart / table
-- aggregates from this, so all filters affect everything.
WITH team_match_years AS (
    SELECT DISTINCT m.team_sk, dd.year AS match_year
    FROM superligaen.gold.fct_team_matches m
    JOIN superligaen.gold.dim_date dd ON dd.date_sk = m.date_sk
    WHERE m.team_sk > 0
)
SELECT
    f.transfer_id,
    d.year       AS transfer_year,
    d.month      AS transfer_month,
    d.month_name AS transfer_month_name,
    d.date       AS transfer_date,
    t.team_name  AS club,
    t.team_code  AS club_code,
    tt.transfer_direction AS direction,
    tt.transfer_type_name AS transfer_type,
    ts.transfer_status,
    p.player_name,
    p.player_photo,
    p.player_main_position AS position,
    date_diff('year', p.player_birth_date::date, d.date) AS player_age,
    pt.transfer_partner_team_name    AS partner,
    pt.transfer_partner_team_country AS partner_country,
    f.transfer_fee_eur AS fee_eur
FROM superligaen.gold.fct_team_transfers        f
JOIN superligaen.gold.dim_date                  d   ON d.date_sk = f.date_sk
JOIN team_match_years                           tmy ON tmy.team_sk = f.team_sk AND tmy.match_year = d.year
JOIN superligaen.gold.dim_team                  t   ON t.team_sk = f.team_sk
JOIN superligaen.gold.dim_transfer_type         tt  ON tt.transfer_type_sk = f.transfer_type_sk
JOIN superligaen.gold.dim_transfer_status       ts  ON ts.transfer_status_sk = f.transfer_status_sk
JOIN superligaen.gold.dim_player                p   ON p.player_sk = f.player_sk
JOIN superligaen.gold.dim_transfer_partner_team pt  ON pt.transfer_partner_team_sk = f.transfer_partner_team_sk
WHERE f.date_sk <> -1
  AND d.year >= 2020
