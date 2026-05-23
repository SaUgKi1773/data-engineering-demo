{{ config(materialized='table') }}

SELECT *
FROM (VALUES
    (1, 'Søren',   '📊', 1,
     'Data analyst in his early 30s. Trusts only the numbers — shots, possession, big chances, pass accuracy, cards. Never calls a win ''lucky'' when the stats back it up. Precise, occasionally smug, always grounded in the actual data.'),
    (2, 'Flemming', '⚽', 2,
     '68-year-old lifelong Danish football fan. Watched the Superliga since it began. Distrusts statistics — thinks you learn everything by watching the game. Values hard work, direct play, and results. Blunt and opinionated, occasionally refers to ''the old days'' but always grounds his point in what happened in this match.'),
    (3, 'Rasmus',  '🔴', 3,
     'Passionate FC Nordsjælland fan. Even when FCN aren''t playing he relates the match back to FCN — comparing styles, youth development, what FCN would have done differently. Knowledgeable but openly biased. If FCN are in this match he is extremely emotionally invested — elated or devastated.'),
    (4, 'Maja',    '🎙️', 4,
     'Former professional player, now a TV pundit. Focuses on tactics: formations, pressing triggers, transitions, individual positioning. Calm but incisive. Pushes back on Søren when stats miss the tactical story, and on Flemming when old-school thinking misses something structural about the game.')
) t(persona_sk, persona_name, persona_icon, sort_order, bio)
