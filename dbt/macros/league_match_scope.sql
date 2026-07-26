-- Two related questions about a fixture, answered per league. They coincide for
-- every league we hold today and diverge for the first league whose own
-- competition includes a knockout phase (Liga MX's liguilla), which is why they
-- are separate macros rather than one flag.
--
-- Both are deliberately per-league CASEs: what counts as "the league" is a
-- property of the competition, not of the data provider, and every league is
-- structured differently.


{% macro is_league_match(league_id_col, stage_type_col) %}
    {#-
        "Does this fixture belong to its own league's competition?"
        The scope rule for every league fact — decides what exists in
        fct_team_matches, fct_match_events, fct_player_appearances and dim_match.

        Denmark (271) / Scotland (501), both Sportmonks: GROUP_STAGE covers
        Regular Season, Championship Round and Relegation Round (Scotland's
        post-split phase is modelled as groups inside a GROUP_STAGE stage, so it
        is already in scope). The excluded KNOCK_OUT stages are the Europa and
        Conference League play-offs — qualification for a DIFFERENT competition
        that Superliga clubs happen to contest — plus the relegation play-off
        final. Those are not league matches and never count toward league totals.

        A new league adds its own branch. Liga MX will be the first where the
        answer is not simply GROUP_STAGE: the liguilla is the Apertura/Clausura
        title decider, so it IS a league match despite being knockout football.

        Unlisted leagues fail closed — a league with no branch here produces no
        gold rows at all, which is loud and immediate rather than subtly wrong.
    -#}
    (CASE
        WHEN {{ league_id_col }} IN (271, 501) THEN {{ stage_type_col }} = 'GROUP_STAGE'
        -- Highlightly leagues (La Liga, Süper Lig, Liga MX): the feed is
        -- queried per league id, so every fixture it returns belongs to that
        -- domestic competition. Liga MX's liguilla is included deliberately —
        -- it is the competition's own title decider, not a different cup.
        WHEN {{ league_id_col }} IN (119924, 173537, 223746) THEN TRUE
        ELSE FALSE
    END)
{% endmacro %}


{% macro awards_league_points(league_id_col, stage_type_col, stage_name_col, group_name_col, round_name_col) %}
    {#-
        "Does this fixture put points on the league table?"
        Drives both dim_match.match_type and fct_team_matches.points_earned, so
        the two can never disagree about the same fixture.

        Identical to is_league_match for Denmark and Scotland: everything in
        scope also awards points. Liga MX will be the first divergence — the
        liguilla is a league match, but the Apertura/Clausura table is the 17
        regular rounds only, so a semifinal win adds nothing to it and those
        fixtures must carry NULL points.
    -#}
    (CASE
        WHEN {{ league_id_col }} IN (271, 501) THEN {{ stage_type_col }} = 'GROUP_STAGE'
        -- Spain and Turkey are pure double round-robins: every fixture in the
        -- feed is a numbered league round and every one awards points.
        WHEN {{ league_id_col }} IN (119924, 173537) THEN TRUE
        -- Liga MX diverges. The Apertura/Clausura table is the numbered rounds
        -- only; the liguilla decides the title but adds nothing to the table,
        -- so those fixtures carry NULL points.
        --
        -- Decided on the CONFORMED round, not the provider's spelling, so
        -- this rule and dim_match.match_round_type can never disagree about
        -- the same fixture. Fails closed: a round we cannot classify is not a
        -- regular round, which is the safe direction - a missed knockout costs
        -- a match its points, a missed regular round would corrupt the table.
        WHEN {{ league_id_col }} = 223746
            THEN {{ conformed_round_type(league_id_col, stage_name_col, group_name_col, round_name_col) }} = 'Regular Season'
        ELSE FALSE
    END)
{% endmacro %}
