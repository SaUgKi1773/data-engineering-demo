-- When the data was last refreshed, for the footer.
--
-- This used to report MAX(date) from the match fact — the date of the last
-- match PLAYED — while the footer rendered it as "Data updated". Those are
-- different facts. Through an off-season the footer would have claimed the
-- data was months old on the morning after a healthy nightly run, and a
-- genuinely broken pipeline would never have shown at all, because a stalled
-- feed does not move the last match date either.
--
-- The site reads two providers: Sportmonks for Denmark and Scotland,
-- Highlightly for Spain, Turkey and Mexico. It is therefore only as fresh as
-- the STALER of the two, so this takes the minimum of each pipeline's latest
-- success. A maximum would let one healthy feed hide the other's failure.
SELECT strftime(MIN(last_success), '%d %b %Y %H:%M UTC') AS last_updated
FROM (
    SELECT pipeline, MAX(completed_at) AS last_success
    FROM superligaen.meta.ingestion_run_log
    WHERE status = 'success'
      AND pipeline IN ('sportmonks', 'highlightly')
    GROUP BY pipeline
)
