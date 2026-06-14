-- Per league-club, per calendar-year transfer activity. "League club" = a club
-- that has actually played league matches (appears in fct_team_matches); foreign
-- counterparties are excluded as subjects. Spend / income / net follow the club's
-- perspective: spend on incoming permanents, income on outgoing permanents.
WITH league_clubs AS (
    SELECT DISTINCT team_sk FROM superligaen.gold.fct_team_matches WHERE team_sk > 0
),
rows AS (
    SELECT
        f.team_sk,
        t.team_name,
        t.team_logo,
        d.year                AS transfer_year,
        tt.transfer_direction AS direction,
        tt.transfer_nature    AS nature,
        tt.transfer_basis     AS basis,
        f.transfer_fee_eur    AS fee
    FROM superligaen.gold.fct_team_transfers f
    JOIN league_clubs                       lc ON lc.team_sk = f.team_sk
    JOIN superligaen.gold.dim_team          t  ON t.team_sk = f.team_sk
    JOIN superligaen.gold.dim_date          d  ON d.date_sk = f.date_sk
    JOIN superligaen.gold.dim_transfer_type tt ON tt.transfer_type_sk = f.transfer_type_sk
    WHERE f.date_sk <> -1
      AND d.year >= 2020
)
SELECT
    transfer_year,
    team_name,
    MAX(team_logo) AS team_logo,
    count(*) FILTER (WHERE direction = 'Incoming')                    AS signings,
    count(*) FILTER (WHERE direction = 'Outgoing')                    AS departures,
    count(*) FILTER (WHERE direction = 'Incoming' AND basis = 'Loan') AS loans_in,
    count(*) FILTER (WHERE direction = 'Outgoing' AND basis = 'Loan') AS loans_out,
    count(*) FILTER (WHERE nature = 'Permanent')                      AS permanent_moves,
    count(*) FILTER (WHERE nature = 'Free')                           AS free_moves,
    count(*) FILTER (WHERE nature IN ('Loan', 'Loan Return'))         AS loan_moves,
    count(*) FILTER (WHERE nature = 'Retirement')                     AS retirements,
    COALESCE(sum(fee) FILTER (WHERE direction = 'Incoming'), 0)       AS spend_eur,
    COALESCE(sum(fee) FILTER (WHERE direction = 'Outgoing'), 0)       AS income_eur,
    COALESCE(sum(fee) FILTER (WHERE direction = 'Incoming'), 0)
        - COALESCE(sum(fee) FILTER (WHERE direction = 'Outgoing'), 0) AS net_spend_eur,
    COALESCE(max(fee), 0)                                             AS biggest_fee_eur
FROM rows
GROUP BY transfer_year, team_name
