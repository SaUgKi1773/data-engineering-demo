-- Match event taxonomy at (type, sub-type) grain, one row per observed combo.
-- event_group classifies the moment by its effect on the match (an own goal IS
-- a goal: the scoreboard moves), not by the provider's taxonomy; the type level
-- underneath keeps provenance distinct. *_code columns are the provider's
-- developer names and serve as the natural key for fact lookups; sub-type NULLs
-- are conformed to 'UNSPECIFIED' so every event resolves to exactly one row.
SELECT *
FROM (VALUES
    -- Goal group: every event that moves the scoreboard
    ( 1, 'Goal', 'Goal', 'Unspecified',                    'GOAL', 'UNSPECIFIED'),
    ( 2, 'Goal', 'Goal', 'Right Foot Shot',                'GOAL', 'RIGHT_FOOT_SHOT'),
    ( 3, 'Goal', 'Goal', 'Left Foot Shot',                 'GOAL', 'LEFT_FOOT_SHOT'),
    ( 4, 'Goal', 'Goal', 'Header',                         'GOAL', 'HEADER'),
    ( 5, 'Goal', 'Goal', 'Shot',                           'GOAL', 'SHOT'),
    ( 6, 'Goal', 'Goal', 'Free Kick',                      'GOAL', 'FREE_KICK'),
    ( 7, 'Goal', 'Goal', 'Penalty',                        'GOAL', 'PENALTY'),
    ( 8, 'Goal', 'Goal', 'Own Goal',                       'GOAL', 'OWNGOAL'),
    ( 9, 'Goal', 'Own Goal', 'Unspecified',                'OWNGOAL', 'UNSPECIFIED'),
    (10, 'Goal', 'Own Goal', 'Right Foot Shot',            'OWNGOAL', 'RIGHT_FOOT_SHOT'),
    (11, 'Goal', 'Own Goal', 'Left Foot Shot',             'OWNGOAL', 'LEFT_FOOT_SHOT'),
    (12, 'Goal', 'Own Goal', 'Header',                     'OWNGOAL', 'HEADER'),
    (13, 'Goal', 'Own Goal', 'Own Goal',                   'OWNGOAL', 'OWNGOAL'),
    (14, 'Goal', 'Penalty', 'Unspecified',                 'PENALTY', 'UNSPECIFIED'),
    (15, 'Goal', 'Penalty', 'Right Foot Shot',             'PENALTY', 'RIGHT_FOOT_SHOT'),
    (16, 'Goal', 'Penalty', 'Left Foot Shot',              'PENALTY', 'LEFT_FOOT_SHOT'),
    (17, 'Goal', 'Penalty', 'Penalty',                     'PENALTY', 'PENALTY'),
    (18, 'Goal', 'Penalty', 'Shot',                        'PENALTY', 'SHOT'),
    -- Missed Penalty group: a penalty incident that does NOT move the scoreboard
    (19, 'Missed Penalty', 'Missed Penalty', 'Unspecified',                 'MISSED_PENALTY', 'UNSPECIFIED'),
    (20, 'Missed Penalty', 'Missed Penalty', 'Penalty Saved by Goalkeeper', 'MISSED_PENALTY', 'PENALTY_SAVED_BY_GOALKEEPER'),
    (21, 'Missed Penalty', 'Missed Penalty', 'Hit the Post',                'MISSED_PENALTY', 'HIT_THE_POST'),
    (22, 'Missed Penalty', 'Missed Penalty', 'Penalty Shot Off Target',     'MISSED_PENALTY', 'PENALTY_SHOT_OFF_TARGET'),
    -- Card group
    (23, 'Card', 'Yellow Card', 'Unspecified',                     'YELLOWCARD', 'UNSPECIFIED'),
    (24, 'Card', 'Yellow Card', 'Foul',                            'YELLOWCARD', 'FOUL'),
    (25, 'Card', 'Yellow Card', 'Argument',                        'YELLOWCARD', 'ARGUMENT'),
    (26, 'Card', 'Yellow Card', 'Time Wasting',                    'YELLOWCARD', 'TIME_WASTING'),
    (27, 'Card', 'Yellow Card', 'Simulation',                      'YELLOWCARD', 'SIMULATION'),
    (28, 'Card', 'Yellow Card', 'Handball',                        'YELLOWCARD', 'HANDBALL'),
    -- PERSITENT is the provider's own typo, preserved in the code, fixed in the label
    (29, 'Card', 'Yellow Card', 'Persistent Fouling',              'YELLOWCARD', 'PERSITENT_FOULING'),
    (30, 'Card', 'Yellow Card', 'Substitution Because of Injury',  'YELLOWCARD', 'SUB_BECAUSE_OF_INJURY'),
    (31, 'Card', 'Yellow Card', 'Off the Ball Foul',               'YELLOWCARD', 'OFF_THE_BALL_FOUL'),
    (32, 'Card', 'Yellow Card', 'Entering Field Unallowed',        'YELLOWCARD', 'ENTERING_FIELD_UNALLOWED'),
    (33, 'Card', 'Yellow Card', 'Dangerous Play',                  'YELLOWCARD', 'DANGEROUS_PLAY'),
    (34, 'Card', 'Second Yellow Card', 'Unspecified',              'YELLOWREDCARD', 'UNSPECIFIED'),
    (35, 'Card', 'Second Yellow Card', 'Foul',                     'YELLOWREDCARD', 'FOUL'),
    (36, 'Card', 'Second Yellow Card', 'Argument',                 'YELLOWREDCARD', 'ARGUMENT'),
    (37, 'Card', 'Second Yellow Card', 'Handball',                 'YELLOWREDCARD', 'HANDBALL'),
    (38, 'Card', 'Second Yellow Card', 'Time Wasting',             'YELLOWREDCARD', 'TIME_WASTING'),
    (39, 'Card', 'Second Yellow Card', 'Simulation',               'YELLOWREDCARD', 'SIMULATION'),
    (40, 'Card', 'Red Card', 'Unspecified',                        'REDCARD', 'UNSPECIFIED'),
    (41, 'Card', 'Red Card', 'Professional Last Man Foul',         'REDCARD', 'PROFESSIONAL_LAST_MAN_FOUL'),
    (42, 'Card', 'Red Card', 'Foul',                               'REDCARD', 'FOUL'),
    (43, 'Card', 'Red Card', 'Handball',                           'REDCARD', 'HANDBALL'),
    (44, 'Card', 'Red Card', 'Violent Conduct',                    'REDCARD', 'VIOLENT_CONDUCT'),
    (45, 'Card', 'Red Card', 'Argument',                           'REDCARD', 'ARGUMENT'),
    -- Substitution group
    (46, 'Substitution', 'Substitution', 'Unspecified',                    'SUBSTITUTION', 'UNSPECIFIED'),
    (47, 'Substitution', 'Substitution', 'Tactical Substitution',          'SUBSTITUTION', 'TACTICAL_SUB'),
    (48, 'Substitution', 'Substitution', 'Substitution Because of Injury', 'SUBSTITUTION', 'SUB_BECAUSE_OF_INJURY'),
    -- VAR group: completed review decisions
    (49, 'VAR', 'VAR Review', 'Unspecified',            'VAR', 'UNSPECIFIED'),
    (50, 'VAR', 'VAR Review', 'Goal Disallowed',        'VAR', 'GOAL_DISALLOWED'),
    (51, 'VAR', 'VAR Review', 'Penalty Confirmed',      'VAR', 'PENALTY_CONFIRMED'),
    (52, 'VAR', 'VAR Review', 'Goal Awarded',           'VAR', 'GOAL_AWARDED'),
    (53, 'VAR', 'VAR Review', 'Penalty Cancelled',      'VAR', 'PENALTY_CANCELLED'),
    (54, 'VAR', 'VAR Review', 'Review',                 'VAR', 'REVIEW'),
    (55, 'VAR', 'VAR Card Review', 'Unspecified',        'VAR_CARD', 'UNSPECIFIED'),
    (56, 'VAR', 'VAR Card Review', 'Card Adjusted',      'VAR_CARD', 'CARD_ADJUSTED'),
    (57, 'VAR', 'VAR Card Review', 'Red Card Cancelled', 'VAR_CARD', 'RED_CARD_CANCELLED'),
    (58, 'VAR', 'VAR Card Review', 'Review',             'VAR_CARD', 'REVIEW'),
    (-1, 'Unknown Event Group',        'Unknown Event Type',        'Unknown Event Sub Type',        'UNKNOWN',        'UNKNOWN'),
    (-2, 'Not Applicable Event Group', 'Not Applicable Event Type', 'Not Applicable Event Sub Type', 'NOT_APPLICABLE', 'NOT_APPLICABLE')
) t(match_event_type_sk, event_group, event_type_name, event_sub_type_name, event_type_code, event_sub_type_code)
