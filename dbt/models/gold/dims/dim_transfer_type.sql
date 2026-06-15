-- Transfer mechanism + direction in one mini-dimension. transfer_type_name is
-- the label (e.g. "Permanent Signing"); transfer_direction is the In/Out split.
SELECT  1 AS transfer_type_sk, 'Permanent Signing'   AS transfer_type_name, 'Incoming' AS transfer_direction
UNION ALL SELECT  2, 'Permanent Sale',     'Outgoing'
UNION ALL SELECT  3, 'Free Signing',       'Incoming'
UNION ALL SELECT  4, 'Free Departure',     'Outgoing'
UNION ALL SELECT  5, 'Loan In',            'Incoming'
UNION ALL SELECT  6, 'Loan Out',           'Outgoing'
UNION ALL SELECT  7, 'Returning from Loan','Incoming'
UNION ALL SELECT  8, 'Loan Spell Ended',   'Outgoing'
UNION ALL SELECT  9, 'Retirement',         'Outgoing'
UNION ALL SELECT -1, 'Unknown',            'Unknown'
UNION ALL SELECT -2, 'Not Applicable',     'Not Applicable'
