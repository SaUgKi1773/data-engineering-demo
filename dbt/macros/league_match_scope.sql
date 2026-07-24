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
        ELSE FALSE
    END)
{% endmacro %}


{% macro awards_league_points(league_id_col, stage_type_col) %}
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
        ELSE FALSE
    END)
{% endmacro %}
