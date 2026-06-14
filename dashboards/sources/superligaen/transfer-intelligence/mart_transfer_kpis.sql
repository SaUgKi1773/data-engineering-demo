-- Per-season transfer KPIs and trend. One row per transfer (deduped across the
-- two club-perspective fact rows, which agree on fee / nature / season), bucketed
-- into the football season its window belongs to (Jul–Jun).
WITH txn AS (
    SELECT
        f.transfer_id,
        MAX(CASE WHEN d.month >= 7 THEN d.year ELSE d.year - 1 END) AS season_start_year,
        MAX(tt.transfer_nature) AS nature,
        MAX(f.transfer_fee_eur) AS fee
    FROM superligaen.gold.fct_team_transfers f
    JOIN superligaen.gold.dim_date          d  ON d.date_sk = f.date_sk
    JOIN superligaen.gold.dim_transfer_type tt ON tt.transfer_type_sk = f.transfer_type_sk
    WHERE f.date_sk <> -1
    GROUP BY f.transfer_id
)
SELECT
    (season_start_year || '/' || right((season_start_year + 1)::varchar, 2)) AS season,
    season_start_year,
    (season_start_year = (CASE WHEN month(current_date) >= 7 THEN year(current_date) ELSE year(current_date) - 1 END)) AS is_current,
    count(*)                                              AS transfers,
    count(*) FILTER (WHERE nature = 'Permanent')          AS permanent_moves,
    count(*) FILTER (WHERE nature = 'Free')               AS free_moves,
    count(*) FILTER (WHERE nature IN ('Loan', 'Loan Return')) AS loan_moves,
    count(*) FILTER (WHERE nature = 'Retirement')         AS retirements,
    count(fee)                                            AS disclosed_fee_deals,
    COALESCE(sum(fee), 0)                                 AS total_spend_eur,
    COALESCE(max(fee), 0)                                 AS biggest_fee_eur,
    ROUND(avg(fee))                                       AS avg_fee_eur
FROM txn
WHERE season_start_year >= 2015
GROUP BY 1, 2, 3
ORDER BY season_start_year DESC
