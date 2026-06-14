-- Deal state of a transfer.
SELECT  1 AS transfer_status_sk, 'Completed'                     AS transfer_status
UNION ALL SELECT  2, 'Pending'
UNION ALL SELECT -1, 'Unknown Transfer Status'
UNION ALL SELECT -2, 'Not Applicable Transfer Status'
