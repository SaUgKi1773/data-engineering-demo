{% macro is_match_finished(source_col, state_developer_name_col, state_name_col, has_result_col) %}
    {#-
        "Does this fixture have a final result?"

        Every fact gates its measures on this, so it has to be answered per
        source. Sportmonks publishes a coded state; Highlightly publishes only
        free text and no coded state at all, which is the trap: a
        state_developer_name test silently evaluates NOT FINISHED for every
        Highlightly row rather than erroring, filling the fact with matches
        marked unplayed - all measures NULL, no result, no points - that look
        entirely plausible.

        Highlightly's rule is deliberately NOT "has a score". An in-progress
        match carries a current score (a "Half time" fixture is live, not
        finished), so keying on score presence would put a half-time scoreline
        on the league table.

        The Cancelled clause is the awarded-result case: a walkover recorded as
        Cancelled but carrying a real score put points on the table and belongs
        in the fact. A cancelled fixture that was never played carries no score
        and stays out.

        Unlisted sources fail closed - a new provider produces no finished
        matches at all, which is loud, rather than a fact full of blanks.
    -#}
    (CASE
        WHEN {{ source_col }} = 'sportmonks'
            THEN {{ state_developer_name_col }} IN ('FT', 'FT_PEN', 'AET')
        WHEN {{ source_col }} = 'highlightly'
            THEN {{ state_name_col }} LIKE 'Finished%'
              OR ({{ state_name_col }} = 'Cancelled' AND {{ has_result_col }})
        ELSE FALSE
    END)
{% endmacro %}
