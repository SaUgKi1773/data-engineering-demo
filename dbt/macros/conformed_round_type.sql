{% macro conformed_round_type(league_id_col, stage_name_col, group_name_col, round_name_col) %}
    {#-
        One round vocabulary across every league, so a provider's spelling can
        never reach a page or a filter.

        The source is not the authority on how a round is named. Highlightly
        alone reports the same Liga MX rounds as "Final" and "Finals",
        "Reclasificación" and "Reclasificacion", and with or without the
        tournament prefix ("Apertura - Semi-finals" in one season, bare
        "Semi-finals" the next). Conform once here and every consumer -
        points, display, filtering - agrees by construction.

        Order matters: "Quarter-finals" and "Semi-finals" both contain
        "final", so they must be tested first.

        An unrecognised label resolves to 'Unclassified Round', which awards no
        points and is surfaced by a test rather than guessed at.
    -#}
    (CASE
        -- Denmark / Scotland: the phase is carried by the stage and group.
        WHEN {{ league_id_col }} = 501 AND {{ group_name_col }} = 'Championship Group' THEN 'Championship Round'
        WHEN {{ league_id_col }} = 501 AND {{ group_name_col }} = 'Relegation Group'   THEN 'Relegation Round'
        WHEN {{ league_id_col }} = 501 AND {{ stage_name_col }} = '1st Phase'          THEN 'Regular Season'
        WHEN {{ league_id_col }} IN (271, 501)                                         THEN {{ stage_name_col }}

        -- Highlightly: the phase is carried by the round label alone.
        -- A trailing " - <number>" is a numbered league round in every one of
        -- these competitions.
        WHEN {{ league_id_col }} IN (119924, 173537, 223746)
             AND regexp_matches({{ round_name_col }}, ' - [0-9]+$')                    THEN 'Regular Season'
        WHEN {{ league_id_col }} = 223746 AND {{ round_name_col }} ILIKE '%Reclasificaci%' THEN 'Reclasificación'
        WHEN {{ league_id_col }} = 223746 AND {{ round_name_col }} ILIKE '%Play-off%'      THEN 'Play-offs'
        WHEN {{ league_id_col }} = 223746 AND {{ round_name_col }} ILIKE '%Quarter-final%' THEN 'Quarter-finals'
        WHEN {{ league_id_col }} = 223746 AND {{ round_name_col }} ILIKE '%Semi-final%'    THEN 'Semi-finals'
        WHEN {{ league_id_col }} = 223746 AND {{ round_name_col }} ILIKE '%Final%'         THEN 'Final'

        ELSE 'Unclassified Round'
    END)
{% endmacro %}
