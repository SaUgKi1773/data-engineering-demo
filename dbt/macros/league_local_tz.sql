{% macro league_local_tz(league_id_col) %}
    (CASE
        WHEN {{ league_id_col }} = 501 THEN 'Europe/London'      -- Scottish Premiership
        WHEN {{ league_id_col }} = 271 THEN 'Europe/Copenhagen'  -- Danish Superliga
        ELSE 'Europe/Copenhagen'                                 -- default: CET
    END)
{% endmacro %}
