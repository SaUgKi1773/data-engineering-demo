-- Every statistics displayName Highlightly emits must exist in the
-- stat_measure_codes_highlightly seed; an unmapped name would land in silver
-- with NULL measure_code and be unreachable by gold.
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
