-- Transfer mechanism + direction in one mini-dimension.
-- Drill path: transfer_basis -> transfer_nature -> transfer_type_name.
SELECT  1 AS transfer_type_sk, 'Permanent Signing'   AS transfer_type_name, 'Incoming' AS transfer_direction, 'Permanent'      AS transfer_nature, 'Permanent'  AS transfer_basis, TRUE  AS is_fee_bearing
UNION ALL SELECT  2, 'Permanent Sale',     'Outgoing', 'Permanent',   'Permanent',  TRUE
UNION ALL SELECT  3, 'Free Signing',       'Incoming', 'Free',        'Permanent',  FALSE
UNION ALL SELECT  4, 'Free Departure',     'Outgoing', 'Free',        'Permanent',  FALSE
UNION ALL SELECT  5, 'Loan In',            'Incoming', 'Loan',        'Loan',       FALSE
UNION ALL SELECT  6, 'Loan Out',           'Outgoing', 'Loan',        'Loan',       FALSE
UNION ALL SELECT  7, 'Returning from Loan','Incoming', 'Loan Return', 'Loan',       FALSE
UNION ALL SELECT  8, 'Loan Spell Ended',   'Outgoing', 'Loan Return', 'Loan',       FALSE
UNION ALL SELECT  9, 'Retirement',         'Outgoing', 'Retirement',  'Career End', FALSE
UNION ALL SELECT -1, 'Unknown',            'Unknown',        'Unknown',        'Unknown',        FALSE
UNION ALL SELECT -2, 'Not Applicable',     'Not Applicable', 'Not Applicable', 'Not Applicable', FALSE
