{{
    config(materialized='view')
}}

-- Role-playing view over dim_team: the other club in a transfer (selling club
-- when we sign, buying club when we sell). Parallel to dim_opponent_team.
SELECT
    team_sk      AS transfer_partner_team_sk,
    team_id      AS transfer_partner_team_id,
    team_name    AS transfer_partner_team_name,
    team_country AS transfer_partner_team_country,
    team_logo    AS transfer_partner_team_logo
FROM {{ ref('dim_team') }}
