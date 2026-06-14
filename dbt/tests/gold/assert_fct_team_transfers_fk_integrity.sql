-- The subject club and the type/status descriptors must always resolve to a real
-- row. team_sk = -1 means a transfer's own club went unresolved; transfer_type_sk
-- or transfer_status_sk = -1 means an unmapped source value slipped through.
-- (transfer_partner_team_sk, player_sk and date_sk may legitimately be -1/-2:
-- unknown counterparty, an un-ingested player, or a pre-1900s..pre-dim_date date.)
SELECT 'team_sk'            AS fk, transfer_id FROM {{ ref('fct_team_transfers') }} WHERE team_sk = -1
UNION ALL
SELECT 'transfer_type_sk',       transfer_id FROM {{ ref('fct_team_transfers') }} WHERE transfer_type_sk = -1
UNION ALL
SELECT 'transfer_status_sk',     transfer_id FROM {{ ref('fct_team_transfers') }} WHERE transfer_status_sk = -1
