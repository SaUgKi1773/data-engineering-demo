{{ config(severity='warn') }}
-- Every statistics displayName Highlightly emits should exist in the
-- stat_measure_codes_highlightly seed; an unmapped name lands in silver with
-- NULL measure_code and is unreachable by gold until mapped.
-- Severity warn: the measure set has grown every era (14 -> 23 -> 40), so new
-- names are expected - patch the seed within the 7-day re-pull window and the
-- rows heal on the next overwrite; older stragglers need a (safe) full refresh.
WITH stats AS (
    SELECT unnest(json_transform(raw_json::VARCHAR, '{"statistics": [{"team": "JSON", "statistics": [{"value": "DOUBLE", "displayName": "VARCHAR"}]}]}').statistics) AS team_stats
    FROM {{ source('bronze', 'highlightly__match_details') }}
    WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.statistics')) > 0
)
SELECT s.displayName AS unmapped_display_name, COUNT(*) AS n
FROM stats, unnest(stats.team_stats.statistics) AS t(s)
LEFT JOIN {{ ref('stat_measure_codes_highlightly') }} hm
    ON hm.display_name = s.displayName
WHERE hm.display_name IS NULL
GROUP BY 1
