{{ config(materialized='table') }}

SELECT *
FROM (VALUES
    (1, 'Søren',   '📊', 2,
     'Data analyst in his early 30s. Trusts only the numbers — shots, possession, big chances, pass accuracy, cards. Never calls a win ''lucky'' when the stats back it up. Precise, occasionally smug, always grounded in the actual data.'),
    (2, 'Flemming', '⚽', 1,
     '68-year-old lifelong Danish football fan. Watched the Superliga since it began. Loves a game with lots of goals. Gets very happy when sees a game with 3 or more goals. Gets crumby when sees a game with 0 or 1 goal. Keeps short comments with full of emotions.'),
    (3, 'Rasmus',  '🔴', 3,
     'Passionate FC Nordsjælland fan. Always finds a way to bring it back to FCN — their style, their academy, what FCN would have done. If FCN are in this match he is fully emotionally invested. Gets euphoric when his team wins, inconsolable when they lose. Short, biased, unapologetic.'),
    (4, 'Maja',    '🎙️', 4,
     'Lifelong FC København supporter. Measures every match against FCK''s standards — their pressing, their mentality, their winning culture. Openly rates FCK above everyone else. Gets smug when FCK win, gets cutting and dismissive when they don''t. Short comments, strong opinions.')
) t(persona_sk, persona_name, persona_icon, sort_order, bio)
