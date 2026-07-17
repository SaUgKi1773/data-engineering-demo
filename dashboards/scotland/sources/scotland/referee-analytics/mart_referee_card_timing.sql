-- When each referee reaches for cards: one row per season, referee and
-- 15-minute bucket, with the league's per-match rate alongside as a baseline.
WITH card_events AS (
    SELECT
        d.season_scotland AS season,
        ref.referee_common_name AS referee_name,
        mm.minute_bucket,
        mm.minute_bucket_sort,
        et.event_type_name,
        f.match_sk
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date             d   ON d.date_sk              = f.date_sk
    JOIN superligaen.gold.dim_referee          ref ON ref.referee_sk         = f.referee_sk
    JOIN superligaen.gold.dim_match_minute     mm  ON mm.match_minute_sk     = f.match_minute_sk
    JOIN superligaen.gold.dim_match_event_type et  ON et.match_event_type_sk = f.match_event_type_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
      AND f.referee_sk > 0
      AND et.event_group = 'Card'
      AND mm.match_minute_sk > 0
      AND mm.minute_bucket != 'Extra Time'
),
referee_matches AS (
    SELECT d.season_scotland AS season, ref.referee_common_name AS referee_name, COUNT(DISTINCT f.match_sk) AS matches
    FROM superligaen.gold.fct_match_events f
    JOIN superligaen.gold.dim_date    d   ON d.date_sk      = f.date_sk
    JOIN superligaen.gold.dim_referee ref ON ref.referee_sk = f.referee_sk
    WHERE d.season_scotland >= '2020/21'
      AND f.league_sk = (SELECT league_sk FROM superligaen.gold.dim_league WHERE league_id = 501)  -- Premiership only
      AND f.referee_sk > 0
    GROUP BY 1, 2
),
per_referee AS (
    SELECT
        ce.season,
        ce.referee_name,
        ce.minute_bucket,
        ce.minute_bucket_sort,
        rm.matches,
        COUNT(*)                                                            AS cards,
        COUNT(*) FILTER (WHERE ce.event_type_name = 'Yellow Card')          AS yellow_cards,
        COUNT(*) FILTER (WHERE ce.event_type_name = 'Second Yellow Card')   AS second_yellow_cards,
        COUNT(*) FILTER (WHERE ce.event_type_name = 'Red Card')             AS red_cards
    FROM card_events ce
    JOIN referee_matches rm ON rm.season = ce.season AND rm.referee_name = ce.referee_name
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    season,
    referee_name,
    minute_bucket,
    minute_bucket_sort,
    matches,
    cards,
    yellow_cards,
    second_yellow_cards,
    red_cards,
    ROUND(cards::double / matches, 2) AS cards_per_match,
    ROUND(SUM(cards)   OVER (PARTITION BY season, minute_bucket)::double
        / SUM(matches) OVER (PARTITION BY season, minute_bucket), 2) AS league_cards_per_match
FROM per_referee
ORDER BY season DESC, referee_name, minute_bucket_sort
