{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['event_type_code', 'event_sub_type_code'],
        merge_update_columns=['event_group', 'event_type_name', 'event_sub_type_name'],
        post_hook=[
            "DELETE FROM {{ this }} WHERE match_event_type_sk IN (-1, -2)",
            "INSERT INTO {{ this }} SELECT * FROM (VALUES (-1, 'Unknown Event Group', 'Unknown Event Type', 'Unknown Event Sub Type', 'UNKNOWN', 'UNKNOWN'), (-2, 'Not Applicable Event Group', 'Not Applicable Event Type', 'Not Applicable Event Sub Type', 'NOT_APPLICABLE', 'NOT_APPLICABLE')) t(match_event_type_sk, event_group, event_type_name, event_sub_type_name, event_type_code, event_sub_type_code)"
        ]
    )
}}

-- Match event taxonomy at (type, sub-type) grain, derived from the observed
-- event stream. event_group classifies the moment by its effect on the match
-- (an own goal IS a goal: the scoreboard moves), not by the provider's
-- taxonomy. Merge on the code pair keeps SKs stable forever: a new provider
-- combo is auto-inserted with the next SK and the provider's display name,
-- and a brand-new type lands in 'Unclassified Event Group' — which fails the
-- event_group accepted_values test, forcing a deliberate classification here
-- rather than a silent guess.
WITH observed AS (
    SELECT
        e.type_developer_name                      AS event_type_code,
        COALESCE(st.developer_name, 'UNSPECIFIED') AS event_sub_type_code,
        MAX(e.type_name)                           AS source_type_name,
        MAX(st.name)                               AS source_sub_type_name
    FROM {{ ref('fixture_events') }} e
    LEFT JOIN {{ ref('types') }} st ON st.id = e.sub_type_id
    WHERE e.type_developer_name IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    {% if is_incremental() %}
    (SELECT COALESCE(MAX(match_event_type_sk), 0) FROM {{ this }} WHERE match_event_type_sk > 0)
        + ROW_NUMBER() OVER (ORDER BY event_type_code, event_sub_type_code) AS match_event_type_sk,
    {% else %}
    ROW_NUMBER() OVER (ORDER BY event_type_code, event_sub_type_code) AS match_event_type_sk,
    {% endif %}
    CASE
        WHEN event_type_code IN ('GOAL', 'OWNGOAL', 'PENALTY')             THEN 'Goal'
        WHEN event_type_code = 'MISSED_PENALTY'                            THEN 'Missed Penalty'
        WHEN event_type_code IN ('YELLOWCARD', 'YELLOWREDCARD', 'REDCARD') THEN 'Card'
        WHEN event_type_code = 'SUBSTITUTION'                              THEN 'Substitution'
        WHEN event_type_code IN ('VAR', 'VAR_CARD')                        THEN 'VAR'
        WHEN event_type_code = 'CORNER'                                    THEN 'Corner'
        WHEN event_type_code IN ('PENALTY_SHOOTOUT_GOAL', 'PENALTY_SHOOTOUT_MISS') THEN 'Penalty Shootout'
        ELSE 'Unclassified Event Group'
    END AS event_group,
    CASE event_type_code
        WHEN 'YELLOWCARD'    THEN 'Yellow Card'
        WHEN 'YELLOWREDCARD' THEN 'Second Yellow Card'
        WHEN 'REDCARD'       THEN 'Red Card'
        WHEN 'VAR'           THEN 'VAR Review'
        WHEN 'VAR_CARD'      THEN 'VAR Card Review'
        ELSE COALESCE(source_type_name, event_type_code)
    END AS event_type_name,
    CASE
        WHEN event_sub_type_code = 'UNSPECIFIED' THEN 'Unspecified'
        ELSE COALESCE(source_sub_type_name, event_sub_type_code)
    END AS event_sub_type_name,
    event_type_code,
    event_sub_type_code
FROM observed
