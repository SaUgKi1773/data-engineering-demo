{{ config(severity='warn') }}
-- Every event type string Highlightly emits should exist in the
-- event_types_highlightly seed; an unmapped type lands in silver with NULL
-- type_id/type_developer_name and is invisible to gold until mapped.
-- Severity warn: vocabulary drift is expected provider behaviour, not
-- corruption - patch the seed within the 7-day re-pull window and the rows
-- heal on the next overwrite; older stragglers need a (safe) full refresh.
WITH ev AS (
    SELECT unnest(json_transform(raw_json::VARCHAR, '{"events": ["JSON"]}').events) AS event
    FROM {{ source('bronze', 'highlightly__match_details') }}
    WHERE json_array_length(json_extract(raw_json::VARCHAR, '$.events')) > 0
)
SELECT (ev.event->>'type') AS unmapped_type, COUNT(*) AS n
FROM ev
LEFT JOIN {{ ref('event_types_highlightly') }} et
    ON et.highlightly_type = (ev.event->>'type')
WHERE et.highlightly_type IS NULL
GROUP BY 1
