{{
    config(materialized='table')
}}

-- Full rebuild each run (not date-incremental): a transfer's effective date is
-- unrelated to when it lands in bronze — backfills and future-dated windows would
-- be missed by a date-window filter. The table is small (~10k rows), so a plain
-- table materialization is both correct and simpler.

-- One row per (transfer, club). A two-club move emits 2 rows (selling club =
-- Outgoing, buying club = Incoming). A retirement / unknown-destination move
-- emits only the side that is a real club. Direction + mechanism live on
-- dim_transfer_type; the partner club is a role view over dim_team.
WITH transfers AS (
    SELECT * FROM {{ ref('transfers') }}
),
outgoing AS (
    -- subject = selling club (from_team); emitted only when from_team is a real club
    SELECT
        id                                          AS transfer_id,
        transfer_date,
        player_id,
        from_team_id                                AS team_id,
        CASE WHEN to_team_id IS NOT NULL AND NOT to_team_placeholder
             THEN to_team_id END                    AS partner_team_id,
        CASE WHEN career_ended THEN -2 ELSE -1 END  AS partner_fallback_sk,
        CASE
            WHEN career_ended           THEN 9   -- Retirement
            WHEN type_name = 'Transfer'      THEN 2   -- Permanent Sale
            WHEN type_name = 'Free Transfer' THEN 4   -- Free Departure
            WHEN type_name = 'Loan'          THEN 6   -- Loan Out
            WHEN type_name = 'End of loan'   THEN 8   -- Loan Spell Ended
            ELSE -1
        END                                         AS transfer_type_sk,
        completed,
        CASE
            WHEN amount IS NOT NULL                         THEN amount  -- disclosed fee
            WHEN type_name = 'Transfer' AND NOT career_ended THEN NULL    -- permanent move, fee undisclosed (unknown)
            ELSE 0                                                        -- free / loan / loan return / retirement: no fee
        END                                         AS transfer_fee_eur
    FROM transfers
    WHERE from_team_id IS NOT NULL
      AND NOT from_team_placeholder
),
incoming AS (
    -- subject = buying club (to_team); emitted only when to_team is a real club
    SELECT
        id                                          AS transfer_id,
        transfer_date,
        player_id,
        to_team_id                                  AS team_id,
        CASE WHEN from_team_id IS NOT NULL AND NOT from_team_placeholder
             THEN from_team_id END                  AS partner_team_id,
        -1                                          AS partner_fallback_sk,
        CASE
            WHEN type_name = 'Transfer'      THEN 1   -- Permanent Signing
            WHEN type_name = 'Free Transfer' THEN 3   -- Free Signing
            WHEN type_name = 'Loan'          THEN 5   -- Loan In
            WHEN type_name = 'End of loan'   THEN 7   -- Returning from Loan
            ELSE -1
        END                                         AS transfer_type_sk,
        completed,
        CASE
            WHEN amount IS NOT NULL                         THEN amount  -- disclosed fee
            WHEN type_name = 'Transfer' AND NOT career_ended THEN NULL    -- permanent move, fee undisclosed (unknown)
            ELSE 0                                                        -- free / loan / loan return / retirement: no fee
        END                                         AS transfer_fee_eur
    FROM transfers
    WHERE to_team_id IS NOT NULL
      AND NOT to_team_placeholder
),
src AS (
    SELECT * FROM outgoing
    UNION ALL
    SELECT * FROM incoming
)
SELECT
    src.transfer_id,
    COALESCE(dd.date_sk, -1)                                       AS date_sk,
    COALESCE(dt.team_sk, -1)                                       AS team_sk,
    COALESCE(dp.transfer_partner_team_sk, src.partner_fallback_sk) AS transfer_partner_team_sk,
    COALESCE(dpl.player_sk, -1)                                    AS player_sk,
    src.transfer_type_sk,
    CASE WHEN src.completed THEN 1 ELSE 2 END                      AS transfer_status_sk,
    1                                                              AS transfer_count,
    src.transfer_fee_eur
FROM src
LEFT JOIN {{ ref('dim_date') }}                  dd  ON dd.date = src.transfer_date
LEFT JOIN {{ ref('dim_team') }}                  dt  ON dt.team_id = src.team_id
LEFT JOIN {{ ref('dim_transfer_partner_team') }} dp  ON dp.transfer_partner_team_id = src.partner_team_id
LEFT JOIN {{ ref('dim_player') }}                dpl ON dpl.player_id = src.player_id
