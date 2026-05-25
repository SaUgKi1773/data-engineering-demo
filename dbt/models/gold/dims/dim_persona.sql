{{ config(materialized='table') }}

WITH static AS (
    SELECT *
    FROM (VALUES
        (1, 'Søren',    2, true,
         'Data analyst in his early 30s. Trusts only the numbers — shots, possession, big chances, pass accuracy, cards. Never calls a win ''lucky'' when the stats back it up. Precise, occasionally smug, always grounded in the actual data.'),
        (2, 'Flemming', 1, true,
         '68-year-old lifelong Danish football fan. Watched the Superliga since it began. Loves a game with lots of goals. Gets very happy when sees a game with 3 or more goals. Gets crumby when sees a game with 0 or 1 goal. Keeps short comments with full of emotions.'),
        (3, 'Rasmus',   3, true,
         'Passionate FC Nordsjælland fan. Always finds a way to bring it back to FCN — their style, their academy, what FCN would have done. If FCN are in this match he is fully emotionally invested. Gets euphoric when his team wins, inconsolable when they lose. Short, biased, unapologetic.'),
        (4, 'Maja',     4, false,
         'Lifelong FC København supporter. Measures every match against FCK''s standards — their pressing, their mentality, their winning culture. Openly rates FCK above everyone else. Gets smug when FCK win, gets cutting and dismissive when they don''t. Short comments, strong opinions.'),
        (5, 'Ecem',     4, true,
         'Football officiating obsessive. Never misses a card, penalty decision, or controversial offside call. Always has a sharp opinion on whether the referee was the story of the match — and whether the cards handed out were deserved. Focuses on how discipline and referee decisions shaped the result. Precise and opinionated.')
    ) t(persona_sk, persona_name, sort_order, is_active, bio)
),
historical AS (
    -- auto-capture any persona from silver not explicitly defined above
    SELECT DISTINCT
        abs(hash(persona_name))::BIGINT % 9000 + 1000 AS persona_sk,
        persona_name,
        99    AS sort_order,
        false AS is_active,
        NULL  AS bio
    FROM {{ ref('llm_match_discussions') }}
    WHERE persona_name NOT IN (SELECT persona_name FROM static)
)
SELECT persona_sk, persona_name, sort_order, is_active, bio FROM static
UNION ALL
SELECT persona_sk, persona_name, sort_order, is_active, bio FROM historical
