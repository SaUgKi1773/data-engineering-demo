---
sidebar: never
hide_toc: true
title: Player Intelligence
---

<script>
  import TeamRadar from '../../components/TeamRadar.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';
  const pageInputs = getInputContext();

  $: if (players_in_team?.length > 0) {
    pageInputs.update(($i) => {
      const currentIsValid = players_in_team.some(p => p.player_name === $i.player?.value);
      if (currentIsValid) return $i;
      const first = players_in_team[0];
      return { ...$i, player: { value: first.player_name, label: first.player_name, rawValues: [{ value: first.player_name, label: first.player_name, selected: true }] } };
    });
  }

  const playerMetrics = [
    { key: 'attacking_pct',   label: 'Attacking'   },
    { key: 'creativity_pct',  label: 'Creativity'  },
    { key: 'possession_pct',  label: 'Possession'  },
    { key: 'defending_pct',   label: 'Defending'   },
    { key: 'physicality_pct', label: 'Physicality' },
    { key: 'impact_pct',      label: 'Impact'      },
  ];
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_player_season
  group by season
) order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from superligaen.mart_player_season
  where season = '${inputs.season.value}'
) order by ord, team_name
```

```sql positions
select player_position from (
  select 'All' as player_position, 0 as ord
  union all
  select distinct player_position, 1 as ord
  from superligaen.mart_player_season
  where season = '${inputs.season.value}'
    and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
    and player_position is not null
) order by ord, player_position
```

```sql players_in_team
select distinct player_name
from superligaen.mart_player_season
where season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and ('All' in ${inputs.position.value} OR player_position in ${inputs.position.value})
order by player_name
```


```sql podium_measures
select * from (values
  -- Attacking
  ('goals',                  'Goals'),
  ('assists',                'Assists'),
  ('goals_per90',            'Goals per 90'),
  ('assists_per90',          'Assists per 90'),
  ('contributions_per90',    'G+A per 90'),
  ('shots_on_target',        'Shots on Target'),
  ('shot_conv',              'Shot Conv %'),
  ('shots_total',            'Total Shots'),
  ('shots_off_target',       'Shots Off Target'),
  ('shots_blocked',          'Shots Blocked'),
  ('woodwork_hits',          'Woodwork Hits'),
  ('big_chances_missed',     'Big Chances Missed'),
  -- Creativity
  ('big_chances_created',    'Big Chances Created'),
  ('all_chances',            'Chances Created'),
  ('key_passes',             'Key Passes'),
  ('passes_final_third',     'Passes Final Third'),
  ('cross_acc',              'Cross Acc %'),
  ('crosses_total',          'Crosses Total'),
  ('crosses_accurate',       'Crosses Accurate'),
  -- Possession
  ('pass_acc',               'Pass Acc %'),
  ('passes_total',           'Passes Total'),
  ('passes_accurate',        'Passes Accurate'),
  ('dribble_success',        'Dribble Success %'),
  ('dribbles_completed',     'Dribbles Completed'),
  ('dribbles_attempts',      'Dribble Attempts'),
  ('long_ball_success',      'Long Ball Success %'),
  ('long_balls',             'Long Balls'),
  ('long_balls_won',         'Long Balls Won'),
  -- Defending
  ('tkl_int',                'Tkl + Int'),
  ('def_actions',            'Defensive Actions'),
  ('tackles',                'Tackles'),
  ('tackles_won',            'Tackles Won'),
  ('tackle_success',         'Tackle Success %'),
  ('interceptions',          'Interceptions'),
  ('clearances',             'Clearances'),
  ('clearances_off_line',    'Clearances Off Line'),
  ('blocks',                 'Blocks'),
  ('balls_recovered',        'Balls Recovered'),
  ('times_dribbled_past',    'Times Dribbled Past'),
  ('errors_leading_to_goal', 'Errors Leading to Goal'),
  ('errors_leading_to_shot', 'Errors Leading to Shot'),
  ('last_man_tackle',        'Last Man Tackle'),
  -- Physicality
  ('duel_win',               'Duel Win %'),
  ('duels_total',            'Duels Total'),
  ('duels_won',              'Duels Won'),
  ('duels_lost',             'Duels Lost'),
  ('aerial_success',         'Aerial Success %'),
  ('aerials_won',            'Aerials Won'),
  ('aerials_lost',           'Aerials Lost'),
  ('fouls_drawn',            'Fouls Drawn'),
  ('fouls_drawn_per90',      'Fouls Drawn per 90'),
  ('fouls_committed',        'Fouls Committed'),
  -- Discipline
  ('yellow_cards',           'Yellow Cards'),
  ('yellow_red_cards',       'Yellow-Red Cards'),
  ('red_cards',              'Red Cards'),
  ('offsides',               'Offsides'),
  -- Possession Loss
  ('dispossessed',           'Dispossessed'),
  ('possession_losses',      'Possession Losses'),
  -- Penalties
  ('penalty_won',            'Penalty Won'),
  ('penalty_scored',         'Penalty Scored'),
  ('penalty_missed',         'Penalty Missed'),
  ('penalty_committed',      'Penalty Committed'),
  ('penalty_saved',          'Penalty Saved'),
  -- Goalkeeping
  ('saves',                  'Saves'),
  ('saves_inside_box',       'Saves Inside Box'),
  ('goals_conceded',         'Goals Conceded'),
  ('goalkeeper_punches',     'GK Punches'),
  ('high_ball_claims',       'High Ball Claims'),
  -- Match Stats
  ('avg_rating',             'Avg Rating'),
  ('minutes_played',         'Minutes Played'),
  ('matches',                'Matches Played'),
  ('starts',                 'Starts'),
  ('wins',                   'Wins'),
  ('draws',                  'Draws'),
  ('losses',                 'Losses'),
  ('own_goals',              'Own Goals'),
  -- Radar Scores
  ('attacking_pct',          'Attacking Score'),
  ('creativity_pct',         'Creativity Score'),
  ('possession_pct',         'Possession Score'),
  ('defending_pct',          'Defending Score'),
  ('physicality_pct',        'Physicality Score'),
  ('impact_pct',             'Impact Score')
) t(value, label)
```

```sql podium_players
with base as (
    select
        player_name,
        player_photo,
        player_position,
        team_name,
        team_logo,
        matches,
        goals::double                       as goals,
        assists::double                     as assists,
        shots_on_target::double             as shots_on_target,
        shot_conv::double                   as shot_conv,
        woodwork_hits::double               as woodwork_hits,
        big_chances_created::double         as big_chances_created,
        chances_created::double             as all_chances,
        key_passes::double                  as key_passes,
        cross_acc::double                   as cross_acc,
        passes_final_third::double          as passes_final_third,
        pass_accuracy::double               as pass_acc,
        dribble_success::double             as dribble_success,
        long_ball_success::double           as long_ball_success,
        tkl_int::double                     as tkl_int,
        tackle_success::double              as tackle_success,
        balls_recovered::double             as balls_recovered,
        times_dribbled_past::double         as times_dribbled_past,
        errors_leading_to_goal::double      as errors_leading_to_goal,
        duel_win_pct::double                as duel_win,
        fouls_drawn::double                 as fouls_drawn,
        aerial_success::double              as aerial_success,
        avg_rating::double                  as avg_rating,
        minutes_played::double              as minutes_played,
        yellow_cards::double                as yellow_cards,
        shots_total::double                 as shots_total,
        shots_off_target::double            as shots_off_target,
        big_chances_missed::double          as big_chances_missed,
        fouls_committed::double             as fouls_committed,
        offsides::double                    as offsides,
        dispossessed::double                as dispossessed,
        possession_losses::double           as possession_losses,
        clearances::double                  as clearances,
        blocks::double                      as blocks,
        interceptions::double               as interceptions,
        tackles::double                     as tackles,
        saves::double                       as saves,
        goals_conceded::double              as goals_conceded,
        own_goals::double                   as own_goals,
        penalty_missed::double              as penalty_missed,
        shots_blocked::double               as shots_blocked,
        clearances_off_line::double         as clearances_off_line,
        last_man_tackle::double             as last_man_tackle,
        red_cards::double                   as red_cards,
        yellow_red_cards::double            as yellow_red_cards,
        penalty_won::double                 as penalty_won,
        penalty_committed::double           as penalty_committed,
        penalty_scored::double              as penalty_scored,
        penalty_saved::double               as penalty_saved,
        saves_inside_box::double            as saves_inside_box,
        goalkeeper_punches::double          as goalkeeper_punches,
        high_ball_claims::double            as high_ball_claims,
        errors_leading_to_shot::double      as errors_leading_to_shot,
        dribbles_completed::double          as dribbles_completed,
        starts::double                      as starts,
        matches::double                     as matches_played,
        wins::double                        as wins,
        draws::double                       as draws,
        losses::double                      as losses,
        passes_total::double                as passes_total,
        passes_accurate::double             as passes_accurate,
        crosses_total::double               as crosses_total,
        crosses_accurate::double            as crosses_accurate,
        long_balls::double                  as long_balls,
        long_balls_won::double              as long_balls_won,
        dribbles_attempts::double           as dribbles_attempts,
        tackles_won::double                 as tackles_won,
        def_actions::double                 as def_actions,
        aerials_won::double                 as aerials_won,
        aerials_lost::double                as aerials_lost,
        duels_total::double                 as duels_total,
        duels_won::double                   as duels_won,
        duels_lost::double                  as duels_lost,
        goals_per90::double                 as goals_per90,
        assists_per90::double               as assists_per90,
        contributions_per90::double         as contributions_per90,
        fouls_drawn_per90::double           as fouls_drawn_per90,
        attacking_pct::double               as attacking_pct,
        creativity_pct::double              as creativity_pct,
        possession_pct::double              as possession_pct,
        defending_pct::double               as defending_pct,
        physicality_pct::double             as physicality_pct,
        impact_pct::double                  as impact_pct
    from superligaen.mart_player_season
    where season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and ('All' in ${inputs.position.value} OR player_position in ${inputs.position.value})
      and matches >= 5
),
ranked as (
    select *,
        case '${inputs.podium_measure.value}'
            when 'goals'                  then goals
            when 'assists'                then assists
            when 'shots_on_target'        then shots_on_target
            when 'shot_conv'              then shot_conv
            when 'woodwork_hits'          then woodwork_hits
            when 'big_chances_created'    then big_chances_created
            when 'all_chances'            then all_chances
            when 'key_passes'             then key_passes
            when 'cross_acc'              then cross_acc
            when 'passes_final_third'     then passes_final_third
            when 'pass_acc'               then pass_acc
            when 'dribble_success'        then dribble_success
            when 'long_ball_success'      then long_ball_success
            when 'tkl_int'                then tkl_int
            when 'tackle_success'         then tackle_success
            when 'balls_recovered'        then balls_recovered
            when 'times_dribbled_past'    then times_dribbled_past
            when 'errors_leading_to_goal' then errors_leading_to_goal
            when 'duel_win'               then duel_win
            when 'fouls_drawn'            then fouls_drawn
            when 'aerial_success'         then aerial_success
            when 'avg_rating'             then avg_rating
            when 'minutes_played'         then minutes_played
            when 'yellow_cards'           then yellow_cards
            when 'shots_total'            then shots_total
            when 'shots_off_target'       then shots_off_target
            when 'big_chances_missed'     then big_chances_missed
            when 'fouls_committed'        then fouls_committed
            when 'offsides'               then offsides
            when 'dispossessed'           then dispossessed
            when 'possession_losses'      then possession_losses
            when 'clearances'             then clearances
            when 'blocks'                 then blocks
            when 'interceptions'          then interceptions
            when 'tackles'                then tackles
            when 'saves'                  then saves
            when 'goals_conceded'         then goals_conceded
            when 'own_goals'              then own_goals
            when 'penalty_missed'         then penalty_missed
            when 'shots_blocked'          then shots_blocked
            when 'clearances_off_line'    then clearances_off_line
            when 'last_man_tackle'        then last_man_tackle
            when 'red_cards'              then red_cards
            when 'yellow_red_cards'       then yellow_red_cards
            when 'penalty_won'            then penalty_won
            when 'penalty_committed'      then penalty_committed
            when 'penalty_scored'         then penalty_scored
            when 'penalty_saved'          then penalty_saved
            when 'saves_inside_box'       then saves_inside_box
            when 'goalkeeper_punches'     then goalkeeper_punches
            when 'high_ball_claims'       then high_ball_claims
            when 'errors_leading_to_shot' then errors_leading_to_shot
            when 'dribbles_completed'     then dribbles_completed
            when 'starts'                 then starts
            when 'matches'                then matches_played
            when 'wins'                   then wins
            when 'draws'                  then draws
            when 'losses'                 then losses
            when 'passes_total'           then passes_total
            when 'passes_accurate'        then passes_accurate
            when 'crosses_total'          then crosses_total
            when 'crosses_accurate'       then crosses_accurate
            when 'long_balls'             then long_balls
            when 'long_balls_won'         then long_balls_won
            when 'dribbles_attempts'      then dribbles_attempts
            when 'tackles_won'            then tackles_won
            when 'def_actions'            then def_actions
            when 'aerials_won'            then aerials_won
            when 'aerials_lost'           then aerials_lost
            when 'duels_total'            then duels_total
            when 'duels_won'              then duels_won
            when 'duels_lost'             then duels_lost
            when 'goals_per90'            then goals_per90
            when 'assists_per90'          then assists_per90
            when 'contributions_per90'    then contributions_per90
            when 'fouls_drawn_per90'      then fouls_drawn_per90
            when 'attacking_pct'          then attacking_pct
            when 'creativity_pct'         then creativity_pct
            when 'possession_pct'         then possession_pct
            when 'defending_pct'          then defending_pct
            when 'physicality_pct'        then physicality_pct
            when 'impact_pct'             then impact_pct
            else goals
        end as measure_value,
        row_number() over (
            order by case '${inputs.podium_measure.value}'
                when 'goals'                  then goals
                when 'assists'                then assists
                when 'shots_on_target'        then shots_on_target
                when 'shot_conv'              then shot_conv
                when 'woodwork_hits'          then woodwork_hits
                when 'big_chances_created'    then big_chances_created
                when 'all_chances'            then all_chances
                when 'key_passes'             then key_passes
                when 'cross_acc'              then cross_acc
                when 'passes_final_third'     then passes_final_third
                when 'pass_acc'               then pass_acc
                when 'dribble_success'        then dribble_success
                when 'long_ball_success'      then long_ball_success
                when 'tkl_int'                then tkl_int
                when 'tackle_success'         then tackle_success
                when 'balls_recovered'        then balls_recovered
                when 'times_dribbled_past'    then times_dribbled_past
                when 'errors_leading_to_goal' then errors_leading_to_goal
                when 'duel_win'               then duel_win
                when 'fouls_drawn'            then fouls_drawn
                when 'aerial_success'         then aerial_success
                when 'avg_rating'             then avg_rating
                when 'minutes_played'         then minutes_played
                when 'yellow_cards'           then yellow_cards
                when 'shots_total'            then shots_total
                when 'shots_off_target'       then shots_off_target
                when 'big_chances_missed'     then big_chances_missed
                when 'fouls_committed'        then fouls_committed
                when 'offsides'               then offsides
                when 'dispossessed'           then dispossessed
                when 'possession_losses'      then possession_losses
                when 'clearances'             then clearances
                when 'blocks'                 then blocks
                when 'interceptions'          then interceptions
                when 'tackles'                then tackles
                when 'saves'                  then saves
                when 'goals_conceded'         then goals_conceded
                when 'own_goals'              then own_goals
                when 'penalty_missed'         then penalty_missed
                when 'shots_blocked'          then shots_blocked
                when 'clearances_off_line'    then clearances_off_line
                when 'last_man_tackle'        then last_man_tackle
                when 'red_cards'              then red_cards
                when 'yellow_red_cards'       then yellow_red_cards
                when 'penalty_won'            then penalty_won
                when 'penalty_committed'      then penalty_committed
                when 'penalty_scored'         then penalty_scored
                when 'penalty_saved'          then penalty_saved
                when 'saves_inside_box'       then saves_inside_box
                when 'goalkeeper_punches'     then goalkeeper_punches
                when 'high_ball_claims'       then high_ball_claims
                when 'errors_leading_to_shot' then errors_leading_to_shot
                when 'dribbles_completed'     then dribbles_completed
                when 'starts'                 then starts
                when 'matches'                then matches_played
                when 'wins'                   then wins
                when 'draws'                  then draws
                when 'losses'                 then losses
                when 'passes_total'           then passes_total
                when 'passes_accurate'        then passes_accurate
                when 'crosses_total'          then crosses_total
                when 'crosses_accurate'       then crosses_accurate
                when 'long_balls'             then long_balls
                when 'long_balls_won'         then long_balls_won
                when 'dribbles_attempts'      then dribbles_attempts
                when 'tackles_won'            then tackles_won
                when 'def_actions'            then def_actions
                when 'aerials_won'            then aerials_won
                when 'aerials_lost'           then aerials_lost
                when 'duels_total'            then duels_total
                when 'duels_won'              then duels_won
                when 'duels_lost'             then duels_lost
                when 'goals_per90'            then goals_per90
                when 'assists_per90'          then assists_per90
                when 'contributions_per90'    then contributions_per90
                when 'fouls_drawn_per90'      then fouls_drawn_per90
                when 'attacking_pct'          then attacking_pct
                when 'creativity_pct'         then creativity_pct
                when 'possession_pct'         then possession_pct
                when 'defending_pct'          then defending_pct
                when 'physicality_pct'        then physicality_pct
                when 'impact_pct'             then impact_pct
                else goals
            end desc nulls last
        ) as rn
    from base
)
select player_name, player_photo, player_position, team_name, team_logo,
       measure_value, rn
from ranked
where rn <= 3
order by rn
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key teams[0]?.team_name}
<Dropdown data={teams} name=team value=team_name label=team_name multiple=true defaultValue={['All Teams']} />
{/key}

{#key positions.map(p => p.player_position).join(',')}
<Dropdown data={positions} name=position value=player_position label=player_position multiple=true defaultValue={['All']} title="Position" />
{/key}

```sql player_profile
select
    player_name,
    player_photo,
    player_nationality,
    player_detailed_position,
    player_birth_date                                           as birth_date,
    date_diff('year', player_birth_date::date, current_date)   as age,
    player_height                                              as height,
    player_weight                                              as weight,
    team_name,
    team_logo,
    player_position,
    matches,
    minutes_played                                             as minutes,
    goals,
    assists,
    shots_total                                                as shots,
    shots_on_target,
    key_passes,
    big_chances_created,
    chances_created,
    tackles,
    interceptions,
    balls_recovered,
    duels_won,
    duels_total,
    passes_accurate,
    passes_total,
    yellow_cards,
    starts,
    avg_rating,
    goals_per90,
    assists_per90,
    contributions_per90,
    pass_accuracy,
    shot_conversion,
    duel_win_pct,
    def_actions,
    wins,
    draws,
    losses
from superligaen.mart_player_season
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
```

```sql player_trend
select
    match_round_number                                                      as round,
    goals_scored,
    big_chances_created,
    tackles + interceptions                                                 as tkl_int,
    pass_accuracy                                                           as pass_acc,
    round(100.0 * duels_won / nullif(duels_total, 0), 1)                   as duel_win,
    rating
from superligaen.mart_match_lineup
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_round_number
```

```sql player_match_log
select
    strftime(match_date, '%Y-%m-%d')                                            as match_date,
    match_round_name                                                            as round,
    opponent_team_name                                                          as opponent,
    opponent_team_short_name                                                    as opponent_short,
    team_side                                                                   as home_away,
    case result
        when 'Win'  then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#22c55e;color:white;border-radius:4px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#eab308;color:white;border-radius:4px;font-size:12px;font-weight:700;">D</span>'
        else             '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#ef4444;color:white;border-radius:4px;font-size:12px;font-weight:700;">L</span>'
    end                                                                         as result_badge,
    goals_scored                                                                as goals,
    assists,
    shots_on_target,
    round(100.0 * goals_scored / nullif(shots_total, 0), 1)                     as shot_conv,
    woodwork_hits,
    big_chances_created,
    chances_created,
    key_passes,
    round(100.0 * crosses_accurate / nullif(crosses_total, 0), 1)               as cross_acc,
    passes_final_third,
    pass_accuracy                                                               as pass_acc,
    round(100.0 * dribbles_completed / nullif(dribbles_attempts, 0), 1)         as dribble_success,
    round(100.0 * long_balls_won / nullif(long_balls, 0), 1)                    as long_ball_success,
    tackles + interceptions                                                     as tkl_int,
    round(100.0 * tackles_won / nullif(tackles, 0), 1)                          as tackle_success,
    balls_recovered,
    times_dribbled_past,
    errors_leading_to_goal,
    round(100.0 * duels_won / nullif(duels_total, 0), 1)                        as duel_win,
    fouls_drawn,
    round(100.0 * aerials_won / nullif(aerials_won + aerials_lost, 0), 1)       as aerial_success,
    rating,
    minutes_played,
    yellow_cards,
    shots_total,
    shots_off_target,
    big_chances_missed,
    fouls_committed,
    offsides,
    dispossessed,
    possession_losses,
    clearances,
    blocks,
    interceptions,
    tackles,
    saves,
    goals_conceded,
    own_goals,
    penalty_missed,
    shots_blocked,
    clearances_off_line,
    last_man_tackle,
    red_cards,
    yellow_red_cards,
    penalty_won,
    penalty_committed,
    penalty_scored,
    penalty_saved,
    saves_inside_box,
    goalkeeper_punches,
    high_ball_claims,
    errors_leading_to_shot,
    dribbles_completed
from superligaen.mart_match_lineup
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql league_context
select attacking_pct, creativity_pct, possession_pct, defending_pct, physicality_pct, impact_pct
from superligaen.mart_player_season
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
```

---

## Top Players

*Rankings are based on the selected season, team, and position filters. Use the measure dropdown to rank by different metrics. Only players with at least 5 appearances are included.*

<Dropdown data={podium_measures} name=podium_measure value=value label=label defaultValue="goals" title="Measure" />

<div style="display:flex;align-items:flex-end;justify-content:center;gap:1rem;margin-top:2rem;border-bottom:3px solid #e5e7eb;">

  <!-- 2nd – Silver -->
  <div style="display:flex;flex-direction:column;align-items:center;flex:1;max-width:160px;">
    <span style="font-size:1.5rem;margin-bottom:0.25rem;">🥈</span>
    <img src="{podium_players[1]?.player_photo}" alt="{podium_players[1]?.player_name}" style="height:4rem;width:4rem;border-radius:50%;object-fit:cover;border:3px solid #94a3b8;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="font-size:0.75rem;font-weight:700;text-align:center;line-height:1.3;">{podium_players[1]?.player_name}</div>
    <div style="font-size:0.625rem;color:#9ca3af;margin:0.1rem 0 0.25rem;">{podium_players[1]?.player_position}</div>
    <img src="{podium_players[1]?.team_logo}" alt="{podium_players[1]?.team_name}" style="height:1.375rem;width:1.375rem;object-fit:contain;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="background:#f1f5f9;border-radius:8px;padding:0.2rem 0.625rem 0.3rem;text-align:center;margin-bottom:0.625rem;">
      <div style="font-size:1.375rem;font-weight:900;color:#475569;line-height:1.15;">{podium_players[1]?.measure_value % 1 === 0 ? Math.round(podium_players[1].measure_value) : podium_players[1].measure_value}</div>
      <div style="font-size:0.55rem;color:#94a3b8;text-transform:uppercase;letter-spacing:0.04em;word-break:break-word;line-height:1.3;">{inputs.podium_measure.label}</div>
    </div>
    <div style="width:100%;height:68px;background:linear-gradient(to bottom,#b0bec5,#90a4ae);border-radius:4px 4px 0 0;"></div>
  </div>

  <!-- 1st – Gold -->
  <div style="display:flex;flex-direction:column;align-items:center;flex:1;max-width:160px;">
    <span style="font-size:2rem;margin-bottom:0.25rem;">🥇</span>
    <img src="{podium_players[0]?.player_photo}" alt="{podium_players[0]?.player_name}" style="height:5rem;width:5rem;border-radius:50%;object-fit:cover;border:3px solid #eab308;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="font-size:0.875rem;font-weight:700;text-align:center;line-height:1.3;">{podium_players[0]?.player_name}</div>
    <div style="font-size:0.65rem;color:#9ca3af;margin:0.1rem 0 0.25rem;">{podium_players[0]?.player_position}</div>
    <img src="{podium_players[0]?.team_logo}" alt="{podium_players[0]?.team_name}" style="height:1.625rem;width:1.625rem;object-fit:contain;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="background:#fef9c3;border-radius:8px;padding:0.2rem 0.75rem 0.3rem;text-align:center;margin-bottom:0.625rem;">
      <div style="font-size:1.875rem;font-weight:900;color:#ca8a04;line-height:1.15;">{podium_players[0]?.measure_value % 1 === 0 ? Math.round(podium_players[0].measure_value) : podium_players[0].measure_value}</div>
      <div style="font-size:0.6rem;color:#a16207;text-transform:uppercase;letter-spacing:0.04em;word-break:break-word;line-height:1.3;">{inputs.podium_measure.label}</div>
    </div>
    <div style="width:100%;height:100px;background:linear-gradient(to bottom,#fbbf24,#d97706);border-radius:4px 4px 0 0;"></div>
  </div>

  <!-- 3rd – Bronze -->
  <div style="display:flex;flex-direction:column;align-items:center;flex:1;max-width:160px;">
    <span style="font-size:1.5rem;margin-bottom:0.25rem;">🥉</span>
    <img src="{podium_players[2]?.player_photo}" alt="{podium_players[2]?.player_name}" style="height:3.5rem;width:3.5rem;border-radius:50%;object-fit:cover;border:3px solid #cd7c2f;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="font-size:0.7rem;font-weight:700;text-align:center;line-height:1.3;">{podium_players[2]?.player_name}</div>
    <div style="font-size:0.6rem;color:#9ca3af;margin:0.1rem 0 0.25rem;">{podium_players[2]?.player_position}</div>
    <img src="{podium_players[2]?.team_logo}" alt="{podium_players[2]?.team_name}" style="height:1.25rem;width:1.25rem;object-fit:contain;margin-bottom:0.5rem;" onerror="this.style.display='none'" />
    <div style="background:#fdf4e7;border-radius:8px;padding:0.2rem 0.625rem 0.3rem;text-align:center;margin-bottom:0.625rem;">
      <div style="font-size:1.125rem;font-weight:900;color:#92400e;line-height:1.15;">{podium_players[2]?.measure_value % 1 === 0 ? Math.round(podium_players[2].measure_value) : podium_players[2].measure_value}</div>
      <div style="font-size:0.55rem;color:#b45309;text-transform:uppercase;letter-spacing:0.04em;word-break:break-word;line-height:1.3;">{inputs.podium_measure.label}</div>
    </div>
    <div style="width:100%;height:44px;background:linear-gradient(to bottom,#cd7c2f,#a05c24);border-radius:4px 4px 0 0;"></div>
  </div>

</div>

---

## Player Deep Dive

*Select a player to explore their full profile, season stats, performance radar, timeline, and match log.*

{#key players_in_team[0]?.player_name}
<Dropdown data={players_in_team} name=player value=player_name label=player_name defaultValue={players_in_team[0]?.player_name} />
{/key}

## Player Profile

{#each player_profile as p}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{p.player_photo}" alt="{p.player_name}"
      class="h-28 w-28 rounded-full object-cover border-4 border-white/20 shadow-xl flex-shrink-0"
      onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl md:text-4xl font-extrabold text-white leading-tight">{p.player_name}</div>
      <div class="flex items-center justify-center md:justify-start gap-2 mt-2">
        <img src="{p.team_logo}" alt="{p.team_name}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
        <span class="text-gray-300 text-sm">{p.team_name}</span>
        <span class="text-gray-500 text-sm">·</span>
        <span class="text-gray-400 text-sm">{p.player_position}</span>
      </div>
      <div class="text-sm text-gray-400 mt-3">
        {p.player_nationality ?? '—'} · {p.age != null ? p.age + ' yrs' : '—'} · {p.height ? p.height + ' cm' : '—'} · {p.weight ? p.weight + ' kg' : '—'}
      </div>
      <div class="text-xs text-gray-500 mt-1">{p.player_detailed_position ?? p.player_position}</div>
      <div class="flex flex-wrap justify-center md:justify-start gap-3 mt-5">
        {#if p.avg_rating != null}
        <span class="px-3 py-1 rounded-full bg-white/10 text-white text-sm font-bold">★ {p.avg_rating}</span>
        {/if}
        <span class="px-3 py-1 rounded-full bg-green-500/20 text-green-400 text-sm font-bold">{p.wins}W</span>
        <span class="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-sm font-bold">{p.draws}D</span>
        <span class="px-3 py-1 rounded-full bg-red-500/20 text-red-400 text-sm font-bold">{p.losses}L</span>
        <span class="px-3 py-1 rounded-full bg-gray-500/20 text-gray-400 text-sm">{p.minutes} mins</span>
      </div>
    </div>
  </div>
</div>
{/each}

---

## Season Overview

{#each player_profile as p}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.goals}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} shots · {p.shot_conversion != null ? p.shot_conversion + '% conv.' : '—'}</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Assists</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.assists}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.key_passes} key passes · {p.big_chances_created} big chances</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">G+A / 90</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.contributions_per90}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.goals_per90} G · {p.assists_per90} A per 90</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shots on Target</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.shots_on_target}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} total shots</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.pass_accuracy != null ? p.pass_accuracy + '%' : '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.passes_accurate} of {p.passes_total} passes</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Duel Win %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.duel_win_pct != null ? p.duel_win_pct + '%' : '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.duels_total} total duels</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Defensive Actions</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.def_actions}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.tackles} tkl · {p.interceptions} int · {p.balls_recovered} rec</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Appearances</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.matches}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.starts} starts</div>
  </div>

</div>
{/each}

---

## Player Characteristics

*Composite percentile score among all players with 450+ minutes in {inputs.season.value}. Each axis combines multiple rate metrics weighted by their importance to that dimension. Higher = better relative to the league.*

{#each league_context as lc}
<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-center">

  <div class="flex flex-col gap-3">

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Attacking</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-blue-500" style="width:{lc.attacking_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.attacking_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Creativity</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-sky-400" style="width:{lc.creativity_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.creativity_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Possession</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-indigo-500" style="width:{lc.possession_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.possession_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Defending</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-teal-500" style="width:{lc.defending_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.defending_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Physicality</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-amber-400" style="width:{lc.physicality_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.physicality_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Impact</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-violet-500" style="width:{lc.impact_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.impact_pct}</div>
    </div>

  </div>

  <TeamRadar data={league_context} metrics={playerMetrics} />

</div>
{/each}

---

## Performance Timeline

*Select a measure to see how it evolved across rounds. Rating is always shown as the secondary axis.*

```sql timeline_measures
select * from (values
  ('goals_scored',        'Goals'),
  ('big_chances_created', 'Big Chances Created'),
  ('pass_acc',            'Pass Accuracy %'),
  ('tkl_int',             'Tkl + Interceptions'),
  ('duel_win',            'Duel Win %')
) t(value, label)
```

<Dropdown data={timeline_measures} name=measure value=value label=label defaultValue="goals_scored" />

{#if inputs.measure.value === 'goals_scored'}
<BarChart
    data={player_trend}
    x=round
    y=goals_scored
    y2=rating
    y2SeriesType=line
    title="Attacking — Goals per Match"
    xAxisTitle="Round"
    yAxisTitle="Goals"
    y2AxisTitle="Rating"
    colorPalette={['#3b82f6','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'big_chances_created'}
<BarChart
    data={player_trend}
    x=round
    y=big_chances_created
    y2=rating
    y2SeriesType=line
    title="Creativity — Big Chances Created"
    xAxisTitle="Round"
    yAxisTitle="Big Chances"
    y2AxisTitle="Rating"
    colorPalette={['#38bdf8','#94a3b8']}
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'pass_acc'}
<BarChart
    data={player_trend}
    x=round
    y=pass_acc
    y2=rating
    y2SeriesType=line
    title="Possession — Pass Accuracy %"
    xAxisTitle="Round"
    yAxisTitle="Pass Acc %"
    y2AxisTitle="Rating"
    colorPalette={['#6366f1','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'tkl_int'}
<BarChart
    data={player_trend}
    x=round
    y=tkl_int
    y2=rating
    y2SeriesType=line
    title="Defending — Tackles + Interceptions"
    xAxisTitle="Round"
    yAxisTitle="Tkl + Int"
    y2AxisTitle="Rating"
    colorPalette={['#14b8a6','#94a3b8']}
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'duel_win'}
<BarChart
    data={player_trend}
    x=round
    y=duel_win
    y2=rating
    y2SeriesType=line
    title="Physicality — Duel Win %"
    xAxisTitle="Round"
    yAxisTitle="Duel Win %"
    y2AxisTitle="Rating"
    colorPalette={['#f59e0b','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{/if}

---

## Match Log

*Use the selectors below to add or remove columns per domain.*

```sql other_measures
select * from (values
  ('minutes_played',    'Minutes Played'),
  ('yellow_cards',      'Yellow Cards'),
  ('shots_total',       'Total Shots'),
  ('shots_off_target',  'Shots Off Target'),
  ('big_chances_missed','Big Chances Missed'),
  ('fouls_committed',   'Fouls Committed'),
  ('offsides',          'Offsides'),
  ('dispossessed',      'Dispossessed'),
  ('possession_losses', 'Possession Losses'),
  ('clearances',        'Clearances'),
  ('blocks',            'Blocks'),
  ('interceptions',     'Interceptions'),
  ('tackles',           'Tackles'),
  ('saves',             'Saves'),
  ('goals_conceded',         'Goals Conceded'),
  ('own_goals',              'Own Goals'),
  ('penalty_missed',         'Penalty Missed'),
  ('shots_blocked',          'Shots Blocked'),
  ('clearances_off_line',    'Clearances Off Line'),
  ('last_man_tackle',        'Last Man Tackle'),
  ('red_cards',              'Red Cards'),
  ('yellow_red_cards',       'Yellow-Red Cards'),
  ('penalty_won',            'Penalty Won'),
  ('penalty_committed',      'Penalty Committed'),
  ('penalty_scored',         'Penalty Scored'),
  ('penalty_saved',          'Penalty Saved'),
  ('saves_inside_box',       'Saves Inside Box'),
  ('goalkeeper_punches',     'GK Punches'),
  ('high_ball_claims',       'High Ball Claims'),
  ('errors_leading_to_shot', 'Errors Leading to Shot'),
  ('dribbles_completed',     'Dribbles Completed')
) t(value, label)
```

```sql attacking_measures
select * from (values
  ('goals',           'Goals'),
  ('assists',         'Assists'),
  ('shots_on_target', 'Shots on Target'),
  ('shot_conv',       'Shot Conv %'),
  ('woodwork_hits',   'Woodwork Hits')
) t(value, label)
```

```sql creativity_measures
select * from (values
  ('big_chances_created', 'Big Chances Created'),
  ('all_chances',         'Chances Created'),
  ('key_passes',          'Key Passes'),
  ('cross_acc',           'Cross Acc %'),
  ('passes_final_third',  'Passes Final Third')
) t(value, label)
```

```sql possession_measures
select * from (values
  ('pass_acc',          'Pass Acc %'),
  ('dribble_success',   'Dribble Success %'),
  ('long_ball_success', 'Long Ball Success %')
) t(value, label)
```

```sql defending_measures
select * from (values
  ('tkl_int',             'Tkl + Int'),
  ('tackle_success',      'Tackle Success %'),
  ('balls_recovered',     'Balls Recovered'),
  ('times_dribbled_past', 'Times Dribbled Past'),
  ('errors_leading_to_goal', 'Errors Leading to Goal')
) t(value, label)
```

```sql physicality_measures
select * from (values
  ('duel_win',       'Duel Win %'),
  ('fouls_drawn',    'Fouls Drawn'),
  ('aerial_success', 'Aerial Success %')
) t(value, label)
```

<div class="grid grid-cols-2 md:grid-cols-3 gap-2 mb-4">
  <Dropdown data={attacking_measures}   name=atk value=value label=label multiple=true defaultValue={['goals']}               title="Attacking"   />
  <Dropdown data={creativity_measures}  name=cre value=value label=label multiple=true defaultValue={['big_chances_created']} title="Creativity"  />
  <Dropdown data={possession_measures}  name=pos value=value label=label multiple=true defaultValue={['pass_acc']}            title="Possession"  />
  <Dropdown data={defending_measures}   name=def value=value label=label multiple=true defaultValue={['tkl_int']}             title="Defending"   />
  <Dropdown data={physicality_measures} name=phy value=value label=label multiple=true defaultValue={['duel_win']}            title="Physicality" />
  <Dropdown data={other_measures}       name=oth value=value label=label multiple=true defaultValue={['minutes_played']}    title="Other"       />
</div>

{#key `${inputs.atk.value}|${inputs.cre.value}|${inputs.pos.value}|${inputs.def.value}|${inputs.phy.value}|${inputs.oth.value}`}
<div class="hidden md:block">
<DataTable data={player_match_log} rows=20 search=true downloadable=true>
    <Column id=match_date   title="Date"     />
    <Column id=round        title="Round"    />
    <Column id=home_away    title="H/A"      align=center />
    <Column id=opponent     title="Opponent" />
    <Column id=result_badge title="Result"   contentType=html align=center />
    <Column id=rating              title="Rating"         align=center contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {#if inputs.atk.value?.includes('goals')}
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.cre.value?.includes('big_chances_created')}
    <Column id=big_chances_created title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('all_chances')}
    <Column id=chances_created     title="Chances"        align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('key_passes')}
    <Column id=key_passes          title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('cross_acc')}
    <Column id=cross_acc           title="Cross Acc %"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('passes_final_third')}
    <Column id=passes_final_third  title="Final 3rd Pass" align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.pos.value?.includes('pass_acc')}
    <Column id=pass_acc          title="Pass Acc %"       align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('dribble_success')}
    <Column id=dribble_success   title="Dribble %"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('long_ball_success')}
    <Column id=long_ball_success title="Long Ball %"      align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.def.value?.includes('tkl_int')}
    <Column id=tkl_int             title="Tkl+Int"        align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('tackle_success')}
    <Column id=tackle_success      title="Tackle %"       align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('balls_recovered')}
    <Column id=balls_recovered     title="Balls Rec."     align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('times_dribbled_past')}
    <Column id=times_dribbled_past title="Drib. Past"     align=center />
    {/if}
    {#if inputs.def.value?.includes('errors_leading_to_goal')}
    <Column id=errors_leading_to_goal title="Errors"      align=center />
    {/if}
    {#if inputs.phy.value?.includes('duel_win')}
    <Column id=duel_win       title="Duel Win %"  align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn    title="Fouls Drawn" align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('aerial_success')}
    <Column id=aerial_success title="Aerial %"    align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.oth.value?.includes('minutes_played')}
    <Column id=minutes_played    title="Minutes"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('yellow_cards')}
    <Column id=yellow_cards      title="YC"               align=center contentType=colorscale colorPalette={['white','#eab308']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_total')}
    <Column id=shots_total       title="Total Shots"      align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_off_target')}
    <Column id=shots_off_target  title="Off Target"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('big_chances_missed')}
    <Column id=big_chances_missed title="Big Ch. Missed"  align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('fouls_committed')}
    <Column id=fouls_committed   title="Fouls Com."       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('offsides')}
    <Column id=offsides          title="Offsides"         align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('dispossessed')}
    <Column id=dispossessed      title="Dispossessed"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('possession_losses')}
    <Column id=possession_losses title="Poss. Losses"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('clearances')}
    <Column id=clearances        title="Clearances"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('blocks')}
    <Column id=blocks            title="Blocks"           align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('interceptions')}
    <Column id=interceptions     title="Interceptions"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('tackles')}
    <Column id=tackles           title="Tackles"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('saves')}
    <Column id=saves             title="Saves"            align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('goals_conceded')}
    <Column id=goals_conceded    title="Goals Conceded"   align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('own_goals')}
    <Column id=own_goals         title="Own Goals"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_missed')}
    <Column id=penalty_missed          title="Pen. Missed"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_blocked')}
    <Column id=shots_blocked           title="Shots Blocked"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('clearances_off_line')}
    <Column id=clearances_off_line     title="Clr. Off Line"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('last_man_tackle')}
    <Column id=last_man_tackle         title="Last Man Tkl"      align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('red_cards')}
    <Column id=red_cards               title="RC"                align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.oth.value?.includes('yellow_red_cards')}
    <Column id=yellow_red_cards        title="YRC"               align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_won')}
    <Column id=penalty_won             title="Pen. Won"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_committed')}
    <Column id=penalty_committed       title="Pen. Com."         align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_scored')}
    <Column id=penalty_scored          title="Pen. Scored"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_saved')}
    <Column id=penalty_saved           title="Pen. Saved"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('saves_inside_box')}
    <Column id=saves_inside_box        title="Saves IB"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('goalkeeper_punches')}
    <Column id=goalkeeper_punches      title="GK Punches"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('high_ball_claims')}
    <Column id=high_ball_claims        title="High Ball Clms"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('errors_leading_to_shot')}
    <Column id=errors_leading_to_shot  title="Errors to Shot"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('dribbles_completed')}
    <Column id=dribbles_completed      title="Dribbles"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={player_match_log} rows=20 search=true>
    <Column id=match_date      title="Date"     />
    <Column id=opponent_short  title="Opponent" />
    <Column id=result_badge title="Result"   contentType=html align=center />
    <Column id=rating              title="Rating"         align=center contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {#if inputs.atk.value?.includes('goals')}
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    {/if}
    {#if inputs.cre.value?.includes('big_chances_created')}
    <Column id=big_chances_created title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('all_chances')}
    <Column id=chances_created     title="Chances"        align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('key_passes')}
    <Column id=key_passes          title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('cross_acc')}
    <Column id=cross_acc           title="Cross Acc %"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('passes_final_third')}
    <Column id=passes_final_third  title="Final 3rd Pass" align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.pos.value?.includes('pass_acc')}
    <Column id=pass_acc          title="Pass Acc %"       align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('dribble_success')}
    <Column id=dribble_success   title="Dribble %"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('long_ball_success')}
    <Column id=long_ball_success title="Long Ball %"      align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.def.value?.includes('tkl_int')}
    <Column id=tkl_int             title="Tkl+Int"        align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('tackle_success')}
    <Column id=tackle_success      title="Tackle %"       align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('balls_recovered')}
    <Column id=balls_recovered     title="Balls Rec."     align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('times_dribbled_past')}
    <Column id=times_dribbled_past title="Drib. Past"     align=center />
    {/if}
    {#if inputs.def.value?.includes('errors_leading_to_goal')}
    <Column id=errors_leading_to_goal title="Errors"      align=center />
    {/if}
    {#if inputs.phy.value?.includes('duel_win')}
    <Column id=duel_win       title="Duel Win %"  align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn    title="Fouls Drawn" align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('aerial_success')}
    <Column id=aerial_success title="Aerial %"    align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.oth.value?.includes('minutes_played')}
    <Column id=minutes_played    title="Minutes"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('yellow_cards')}
    <Column id=yellow_cards      title="YC"               align=center contentType=colorscale colorPalette={['white','#eab308']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_total')}
    <Column id=shots_total       title="Total Shots"      align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_off_target')}
    <Column id=shots_off_target  title="Off Target"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('big_chances_missed')}
    <Column id=big_chances_missed title="Big Ch. Missed"  align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('fouls_committed')}
    <Column id=fouls_committed   title="Fouls Com."       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('offsides')}
    <Column id=offsides          title="Offsides"         align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('dispossessed')}
    <Column id=dispossessed      title="Dispossessed"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('possession_losses')}
    <Column id=possession_losses title="Poss. Losses"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('clearances')}
    <Column id=clearances        title="Clearances"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('blocks')}
    <Column id=blocks            title="Blocks"           align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('interceptions')}
    <Column id=interceptions     title="Interceptions"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('tackles')}
    <Column id=tackles           title="Tackles"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('saves')}
    <Column id=saves             title="Saves"            align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('goals_conceded')}
    <Column id=goals_conceded    title="Goals Conceded"   align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('own_goals')}
    <Column id=own_goals         title="Own Goals"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_missed')}
    <Column id=penalty_missed          title="Pen. Missed"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('shots_blocked')}
    <Column id=shots_blocked           title="Shots Blocked"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('clearances_off_line')}
    <Column id=clearances_off_line     title="Clr. Off Line"     align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('last_man_tackle')}
    <Column id=last_man_tackle         title="Last Man Tkl"      align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('red_cards')}
    <Column id=red_cards               title="RC"                align=center contentType=colorscale colorPalette={['white','#ef4444']} />
    {/if}
    {#if inputs.oth.value?.includes('yellow_red_cards')}
    <Column id=yellow_red_cards        title="YRC"               align=center contentType=colorscale colorPalette={['white','#f97316']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_won')}
    <Column id=penalty_won             title="Pen. Won"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_committed')}
    <Column id=penalty_committed       title="Pen. Com."         align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_scored')}
    <Column id=penalty_scored          title="Pen. Scored"       align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('penalty_saved')}
    <Column id=penalty_saved           title="Pen. Saved"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('saves_inside_box')}
    <Column id=saves_inside_box        title="Saves IB"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('goalkeeper_punches')}
    <Column id=goalkeeper_punches      title="GK Punches"        align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('high_ball_claims')}
    <Column id=high_ball_claims        title="High Ball Clms"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('errors_leading_to_shot')}
    <Column id=errors_leading_to_shot  title="Errors to Shot"    align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
    {#if inputs.oth.value?.includes('dribbles_completed')}
    <Column id=dribbles_completed      title="Dribbles"          align=center contentType=colorscale colorPalette={['white','#94a3b8']} />
    {/if}
</DataTable>
</div>

{/key}