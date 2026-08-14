-- Every timed event placed on the match clock, by league and day.
-- Generalises the goal-only clock to cards and substitutions, which the event
-- stream carries for all five leagues. Fifteen-minute slices; extra time is
-- excluded because only knock-out football ever plays it.
SELECT
    l.league_name,
    d.date                                              AS match_date,
    d.year                                              AS calendar_year,
    et.event_group,
    mm.minute_bucket,
    mm.minute_bucket_sort,
    COUNT(*)                                            AS events
FROM superligaen.gold.fct_match_events e
JOIN superligaen.gold.dim_league           l  ON l.league_sk            = e.league_sk
JOIN superligaen.gold.dim_date             d  ON d.date_sk              = e.date_sk
JOIN superligaen.gold.dim_match            m  ON m.match_sk             = e.match_sk
JOIN superligaen.gold.dim_match_minute     mm ON mm.match_minute_sk     = e.match_minute_sk
JOIN superligaen.gold.dim_match_event_type et ON et.match_event_type_sk = e.match_event_type_sk
WHERE m.match_type = 'Regular League'
  AND d.year >= 2020
  AND mm.minute_bucket_sort BETWEEN 1 AND 8
  AND et.event_group IN ('Goal', 'Card', 'Substitution')
GROUP BY 1, 2, 3, 4, 5, 6
