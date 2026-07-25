{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['fixture_id', '_source']
) }}

-- unique_key is a delete SCOPE: re-processing a fixture replaces its referee
-- rows for that source. Highlightly rows carry no ids - referee_id stays NULL
-- (the provider has no referee entity, only a name + nationality per match),
-- so dim_referee's referee_id IS NOT NULL filter keeps them out of gold until
-- the #438 gold PR resolves them by name.

WITH src AS MATERIALIZED (
    SELECT *
    FROM {{ source('bronze', 'sportmonks__fixtures') }}
    {% if is_incremental() %}
    WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'sportmonks')
    {% endif %}
)

SELECT
    (ref->>'id')::INTEGER                                                       AS id,
    f.id                                                                        AS fixture_id,
    COALESCE(o.canonical_referee_id, (ref->>'referee_id')::INTEGER)             AS referee_id,
    (ref->>'type_id')::INTEGER                                                  AS type_id,
    ref->'referee'->>'common_name'                                              AS referee_common_name,
    ref->'referee'->>'firstname'                                                AS referee_firstname,
    ref->'referee'->>'lastname'                                                 AS referee_lastname,
    ref->'referee'->>'name'                                                     AS referee_name,
    ref->'referee'->>'display_name'                                             AS referee_display_name,
    ref->'referee'->>'image_path'                                               AS referee_image_path,
    NULL::VARCHAR                                                               AS referee_nationality,
    'sportmonks'                                                                AS _source,
    f._ingested_at
FROM src AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"referees": ["JSON"]}').referees) AS t(ref)
LEFT JOIN {{ ref('referee_id_overrides') }} o
    ON o.referee_id = (ref->>'referee_id')::INTEGER
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.referees')) > 0

UNION ALL

SELECT
    NULL::INTEGER                                            AS id,
    id                                                       AS fixture_id,
    NULL::INTEGER                                            AS referee_id,
    NULL::INTEGER                                            AS type_id,
    NULL::VARCHAR                                            AS referee_common_name,
    NULL::VARCHAR                                            AS referee_firstname,
    NULL::VARCHAR                                            AS referee_lastname,
    json_extract_string(raw_json, '$.referee.name')          AS referee_name,
    NULL::VARCHAR                                            AS referee_display_name,
    NULL::VARCHAR                                            AS referee_image_path,
    json_extract_string(raw_json, '$.referee.nationality')   AS referee_nationality,
    'highlightly'                                            AS _source,
    _ingested_at
FROM {{ source('bronze', 'highlightly__match_details') }}
WHERE json_extract_string(raw_json, '$.referee.name') IS NOT NULL
{% if is_incremental() %}
  AND _ingested_at > COALESCE((SELECT MAX(_ingested_at) FROM {{ this }} WHERE _source = 'highlightly'), '1900-01-01'::TIMESTAMP)
{% endif %}
