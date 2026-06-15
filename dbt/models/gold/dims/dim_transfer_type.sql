-- Transfer mechanism + direction in one mini-dimension.
-- transfer_type_name is the label; transfer_nature is the direction-agnostic
-- mechanism for slicing (Permanent / Free / Loan / Loan Return / Retirement).
SELECT  1 AS transfer_type_sk, 'Permanent Signing'   AS transfer_type_name, 'Incoming' AS transfer_direction, 'Permanent'      AS transfer_nature
UNION ALL SELECT  2, 'Permanent Sale',     'Outgoing', 'Permanent'
UNION ALL SELECT  3, 'Free Signing',       'Incoming', 'Free'
UNION ALL SELECT  4, 'Free Departure',     'Outgoing', 'Free'
UNION ALL SELECT  5, 'Loan In',            'Incoming', 'Loan'
UNION ALL SELECT  6, 'Loan Out',           'Outgoing', 'Loan'
UNION ALL SELECT  7, 'Returning from Loan','Incoming', 'Loan Return'
UNION ALL SELECT  8, 'Loan Spell Ended',   'Outgoing', 'Loan Return'
UNION ALL SELECT  9, 'Retirement',         'Outgoing', 'Retirement'
UNION ALL SELECT -1, 'Unknown',            'Unknown',        'Unknown'
UNION ALL SELECT -2, 'Not Applicable',     'Not Applicable', 'Not Applicable'
