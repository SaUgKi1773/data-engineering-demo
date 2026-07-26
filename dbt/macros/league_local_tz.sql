{% macro league_local_tz(league_id_col) %}
    {#-
        The league's own local timezone, used for kick-off time and for the
        hour that resolves dim_time.

        There is no safe default. This macro previously fell back to
        Europe/Copenhagen for any unlisted league, which was silently wrong the
        moment a non-CET league arrived: Liga MX kick-offs read 05:00 for
        matches that kicked off at 21:00, and Süper Lig ran an hour or two out.
        Nothing failed - the times were simply wrong, and plausible enough to
        go unnoticed.

        An unlisted league now yields NULL, which propagates to a NULL kick-off
        and an Unknown time_sk. A missing time is obvious; a wrong one is not.

        Caveat for Liga MX: Mexico spans several zones and this is the zone
        for the great majority of the league. Club Tijuana plays on Pacific
        time, so its home kick-offs are an hour or two out. Fixing that
        properly needs a stadium-level timezone, not a league-level one.
    -#}
    (CASE
        WHEN {{ league_id_col }} = 271    THEN 'Europe/Copenhagen'    -- Danish Superliga
        WHEN {{ league_id_col }} = 501    THEN 'Europe/London'        -- Scottish Premiership
        WHEN {{ league_id_col }} = 119924 THEN 'Europe/Madrid'        -- La Liga
        WHEN {{ league_id_col }} = 173537 THEN 'Europe/Istanbul'      -- Süper Lig (UTC+3, no DST)
        WHEN {{ league_id_col }} = 223746 THEN 'America/Mexico_City'  -- Liga MX
        ELSE NULL
    END)
{% endmacro %}
