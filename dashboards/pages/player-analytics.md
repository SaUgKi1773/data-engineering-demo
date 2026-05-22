---
sidebar: never
hide_toc: true
title: Player Intelligence
---

<script>
  import TeamRadar from '../../components/TeamRadar.svelte';

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
  from superligaen.mart_player_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from superligaen.mart_player_facts
  where season = '${inputs.season.value}'
    and result in ('Win', 'Draw', 'Loss')
) order by ord, team_name
```

```sql positions
select player_position from (
  select 'All' as player_position, 0 as ord
  union all
  select distinct player_position, 1 as ord
  from superligaen.mart_player_facts
  where season = '${inputs.season.value}'
    and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
    and result in ('Win', 'Draw', 'Loss')
    and player_position is not null
) order by ord, player_position
```

```sql players_in_team
select distinct player_name
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and ('All' in ${inputs.position.value} OR player_position in ${inputs.position.value})
  and result in ('Win', 'Draw', 'Loss')
order by player_name
```


```sql podium_measures
select * from (values
  -- Attacking
  ('goals',                  'Goals'),
  ('assists',                'Assists'),
  ('shots_on_target',        'Shots on Target'),
  ('shot_conv',              'Shot Conv %'),
  ('woodwork_hits',          'Woodwork Hits'),
  -- Creativity
  ('big_chances_created',    'Big Chances Created'),
  ('all_chances',            'Chances Created'),
  ('key_passes',             'Key Passes'),
  ('cross_acc',              'Cross Acc %'),
  ('passes_final_third',     'Passes Final Third'),
  -- Possession
  ('pass_acc',               'Pass Acc %'),
  ('dribble_success',        'Dribble Success %'),
  ('long_ball_success',      'Long Ball Success %'),
  -- Defending
  ('tkl_int',                'Tkl + Int'),
  ('tackle_success',         'Tackle Success %'),
  ('balls_recovered',        'Balls Recovered'),
  ('times_dribbled_past',    'Times Dribbled Past'),
  ('errors_leading_to_goal', 'Errors Leading to Goal'),
  -- Physicality
  ('duel_win',               'Duel Win %'),
  ('fouls_drawn',            'Fouls Drawn'),
  ('aerial_success',         'Aerial Success %'),
  -- Impact & Other
  ('avg_rating',             'Avg Rating'),
  ('minutes_played',         'Minutes Played'),
  ('yellow_cards',           'Yellow Cards'),
  ('shots_total',            'Total Shots'),
  ('shots_off_target',       'Shots Off Target'),
  ('big_chances_missed',     'Big Chances Missed'),
  ('fouls_committed',        'Fouls Committed'),
  ('offsides',               'Offsides'),
  ('dispossessed',           'Dispossessed'),
  ('possession_losses',      'Possession Losses'),
  ('clearances',             'Clearances'),
  ('blocks',                 'Blocks'),
  ('interceptions',          'Interceptions'),
  ('tackles',                'Tackles'),
  ('saves',                  'Saves'),
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

```sql podium_players
with base as (
    select
        player_name,
        player_photo,
        player_position,
        max(team_name)                                                                         as team_name,
        max(team_logo)                                                                         as team_logo,
        count(distinct match_id)                                                               as matches,
        -- Attacking
        sum(goals_scored)::double                                                              as goals,
        sum(assists)::double                                                                   as assists,
        sum(shots_on_target)::double                                                           as shots_on_target,
        round(100.0 * sum(goals_scored) / nullif(sum(shots_total), 0), 1)                     as shot_conv,
        sum(woodwork_hits)::double                                                             as woodwork_hits,
        -- Creativity
        sum(big_chances_created)::double                                                       as big_chances_created,
        sum(chances_created)::double                                                           as all_chances,
        sum(key_passes)::double                                                                as key_passes,
        round(100.0 * sum(crosses_accurate) / nullif(sum(crosses_total), 0), 1)               as cross_acc,
        sum(passes_final_third)::double                                                        as passes_final_third,
        -- Possession
        round(100.0 * sum(passes_accurate) / nullif(sum(passes_total), 0), 1)                 as pass_acc,
        round(100.0 * sum(dribbles_completed) / nullif(sum(dribbles_attempts), 0), 1)         as dribble_success,
        round(100.0 * sum(long_balls_won) / nullif(sum(long_balls), 0), 1)                    as long_ball_success,
        -- Defending
        (sum(tackles) + sum(interceptions))::double                                            as tkl_int,
        round(100.0 * sum(tackles_won) / nullif(sum(tackles), 0), 1)                          as tackle_success,
        sum(balls_recovered)::double                                                           as balls_recovered,
        sum(times_dribbled_past)::double                                                       as times_dribbled_past,
        sum(errors_leading_to_goal)::double                                                    as errors_leading_to_goal,
        -- Physicality
        round(100.0 * sum(duels_won) / nullif(sum(duels_total), 0), 1)                        as duel_win,
        sum(fouls_drawn)::double                                                               as fouls_drawn,
        round(100.0 * sum(aerials_won) / nullif(sum(aerials_won) + sum(aerials_lost), 0), 1)  as aerial_success,
        -- Impact & Other
        round(avg(rating), 2)::double                                                          as avg_rating,
        sum(minutes_played)::double                                                            as minutes_played,
        sum(yellow_cards)::double                                                              as yellow_cards,
        sum(shots_total)::double                                                               as shots_total,
        sum(shots_off_target)::double                                                          as shots_off_target,
        sum(big_chances_missed)::double                                                        as big_chances_missed,
        sum(fouls_committed)::double                                                           as fouls_committed,
        sum(offsides)::double                                                                  as offsides,
        sum(dispossessed)::double                                                              as dispossessed,
        sum(possession_losses)::double                                                         as possession_losses,
        sum(clearances)::double                                                                as clearances,
        sum(blocks)::double                                                                    as blocks,
        sum(interceptions)::double                                                             as interceptions,
        sum(tackles)::double                                                                   as tackles,
        sum(saves)::double                                                                     as saves,
        sum(goals_conceded)::double                                                            as goals_conceded,
        sum(own_goals)::double                                                                 as own_goals,
        sum(penalty_missed)::double                                                            as penalty_missed,
        sum(shots_blocked)::double                                                             as shots_blocked,
        sum(clearances_off_line)::double                                                       as clearances_off_line,
        sum(last_man_tackle)::double                                                           as last_man_tackle,
        sum(red_cards)::double                                                                 as red_cards,
        sum(yellow_red_cards)::double                                                          as yellow_red_cards,
        sum(penalty_won)::double                                                               as penalty_won,
        sum(penalty_committed)::double                                                         as penalty_committed,
        sum(penalty_scored)::double                                                            as penalty_scored,
        sum(penalty_saved)::double                                                             as penalty_saved,
        sum(saves_inside_box)::double                                                          as saves_inside_box,
        sum(goalkeeper_punches)::double                                                        as goalkeeper_punches,
        sum(high_ball_claims)::double                                                          as high_ball_claims,
        sum(errors_leading_to_shot)::double                                                    as errors_leading_to_shot,
        sum(dribbles_completed)::double                                                        as dribbles_completed
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, player_position
    having count(distinct match_id) >= 5
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

```sql player_profile
select
    player_name,
    player_photo,
    player_nationality,
    player_detailed_position,
    max(player_birth_date)                                                                 as birth_date,
    date_diff('year', max(player_birth_date)::date, current_date)                         as age,
    max(player_height)                                                                     as height,
    max(player_weight)                                                                     as weight,
    team_name,
    team_logo,
    player_position,
    count(distinct match_id)::int                                                         as matches,
    sum(minutes_played)::int                                                              as minutes,
    sum(goals_scored)::int                                                                as goals,
    sum(assists)::int                                                                     as assists,
    sum(shots_total)::int                                                                 as shots,
    sum(shots_on_target)::int                                                             as shots_on_target,
    sum(key_passes)::int                                                                  as key_passes,
    sum(big_chances_created)::int                                                         as big_chances_created,
    sum(chances_created)::int                                                             as chances_created,
    sum(tackles)::int                                                                     as tackles,
    sum(interceptions)::int                                                               as interceptions,
    sum(balls_recovered)::int                                                             as balls_recovered,
    sum(duels_won)::int                                                                   as duels_won,
    sum(duels_total)::int                                                                 as duels_total,
    sum(passes_accurate)::int                                                             as passes_accurate,
    sum(passes_total)::int                                                                as passes_total,
    sum(yellow_cards)::int                                                                as yellow_cards,
    sum(case when appearance_type = 'Starter' then 1 else 0 end)::int                    as starts,
    round(avg(rating), 2)                                                                 as avg_rating,
    round(sum(goals_scored)  * 90.0 / nullif(sum(minutes_played), 0), 2)                 as goals_per90,
    round(sum(assists)       * 90.0 / nullif(sum(minutes_played), 0), 2)                 as assists_per90,
    round((sum(goals_scored) + sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2) as contributions_per90,
    round(100.0 * sum(passes_accurate)  / nullif(sum(passes_total), 0), 1)               as pass_accuracy,
    round(100.0 * sum(goals_scored)     / nullif(sum(shots_total),  0), 1)               as shot_conversion,
    round(100.0 * sum(duels_won)        / nullif(sum(duels_total),  0), 1)               as duel_win_pct,
    (sum(tackles) + sum(interceptions) + sum(balls_recovered))::int                      as def_actions,
    sum(case when result = 'Win'  then 1 else 0 end)::int                                as wins,
    sum(case when result = 'Draw' then 1 else 0 end)::int                                as draws,
    sum(case when result = 'Loss' then 1 else 0 end)::int                                as losses
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, player_nationality, player_detailed_position, team_name, team_logo, player_position
```

```sql player_trend
select
    match_round_number                                                          as round,
    goals_scored,
    big_chances_created,
    tackles + interceptions                                                     as tkl_int,
    round(100.0 * passes_accurate / nullif(passes_total, 0), 1)                as pass_acc,
    round(100.0 * duels_won       / nullif(duels_total,   0), 1)               as duel_win,
    rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_round_number
```

```sql player_match_log
select
    strftime(match_date, '%Y-%m-%d')              as match_date,
    match_round_name                              as round,
    opponent_team_name                            as opponent,
    opponent_team_short_name                      as opponent_short,
    team_side                                     as home_away,
    case result
        when 'Win'  then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#22c55e;color:white;border-radius:4px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#eab308;color:white;border-radius:4px;font-size:12px;font-weight:700;">D</span>'
        else             '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#ef4444;color:white;border-radius:4px;font-size:12px;font-weight:700;">L</span>'
    end                                           as result_badge,
    -- Attacking
    goals_scored                                                                    as goals,
    assists,
    shots_on_target,
    round(100.0 * goals_scored / nullif(shots_total, 0), 1)                         as shot_conv,
    woodwork_hits,
    -- Creativity
    big_chances_created,
    chances_created,
    key_passes,
    round(100.0 * crosses_accurate / nullif(crosses_total, 0), 1)                   as cross_acc,
    passes_final_third,
    -- Possession
    round(100.0 * passes_accurate / nullif(passes_total, 0), 1)                     as pass_acc,
    round(100.0 * dribbles_completed / nullif(dribbles_attempts, 0), 1)             as dribble_success,
    round(100.0 * long_balls_won / nullif(long_balls, 0), 1)                        as long_ball_success,
    -- Defending
    tackles + interceptions                                                          as tkl_int,
    round(100.0 * tackles_won / nullif(tackles, 0), 1)                              as tackle_success,
    balls_recovered,
    times_dribbled_past,
    errors_leading_to_goal,
    -- Physicality
    round(100.0 * duels_won / nullif(duels_total, 0), 1)                            as duel_win,
    fouls_drawn,
    round(100.0 * aerials_won / nullif(aerials_won + aerials_lost, 0), 1)           as aerial_success,
    -- Impact
    rating,
    -- Other
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
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql league_context
with base as (
    select
        player_name,
        -- Attacking
        sum(goals_scored)         * 90.0 / nullif(sum(minutes_played), 0)                           as goals_per90,
        sum(assists)              * 90.0 / nullif(sum(minutes_played), 0)                           as assists_per90,
        sum(shots_on_target)      * 90.0 / nullif(sum(minutes_played), 0)                           as sot_per90,
        100.0 * sum(goals_scored)          / nullif(sum(shots_total), 0)                            as shot_acc_pct,
        sum(woodwork_hits)        * 90.0 / nullif(sum(minutes_played), 0)                           as woodwork_per90,
        -- Creativity
        sum(big_chances_created)  * 90.0 / nullif(sum(minutes_played), 0)                           as big_chances_per90,
        sum(chances_created)      * 90.0 / nullif(sum(minutes_played), 0)                           as chances_per90,
        sum(key_passes)           * 90.0 / nullif(sum(minutes_played), 0)                           as key_passes_per90,
        100.0 * sum(big_chances_created)   / nullif(sum(chances_created), 0)                        as chance_quality_pct,
        100.0 * sum(crosses_accurate)      / nullif(sum(crosses_total), 0)                          as cross_acc_pct,
        sum(passes_final_third)   * 90.0 / nullif(sum(minutes_played), 0)                           as passes_final_third_per90,
        -- Possession
        100.0 * sum(passes_accurate)       / nullif(sum(passes_total), 0)                           as pass_acc_pct,
        100.0 * sum(dribbles_completed)    / nullif(sum(dribbles_attempts), 0)                      as dribble_success_pct,
        100.0 * sum(long_balls_won)        / nullif(sum(long_balls), 0)                             as long_ball_success_pct,
        -- Defending
        (sum(tackles) + sum(interceptions)) * 90.0 / nullif(sum(minutes_played), 0)                as tkl_int_per90,
        100.0 * sum(tackles_won)           / nullif(sum(tackles), 0)                               as tackle_success_pct,
        sum(balls_recovered)      * 90.0 / nullif(sum(minutes_played), 0)                           as balls_recovered_per90,
        sum(times_dribbled_past)  * 90.0 / nullif(sum(minutes_played), 0)                           as times_dribbled_past_per90,
        sum(errors_leading_to_goal) * 90.0 / nullif(sum(minutes_played), 0)                         as errors_per90,
        -- Physicality
        100.0 * sum(duels_won)             / nullif(sum(duels_total), 0)                            as duel_win_pct,
        sum(fouls_drawn)          * 90.0 / nullif(sum(minutes_played), 0)                           as fouls_drawn_per90,
        100.0 * sum(aerials_won)           / nullif(sum(aerials_won) + sum(aerials_lost), 0)        as aerial_success_pct,
        -- Impact
        avg(rating)                                                                                  as avg_rating
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by player_name
    having sum(minutes_played) >= 450
),
ranked as (
    select
        player_name,
        -- Attacking: anchor goals/90 (2×), + assists/90, sot/90, shot_acc%, woodwork/90 → /6
        round((2 * percent_rank() over (order by goals_per90)
                 + percent_rank() over (order by assists_per90)
                 + percent_rank() over (order by sot_per90)
                 + percent_rank() over (order by shot_acc_pct)
                 + percent_rank() over (order by woodwork_per90)) / 6 * 100)                        as attacking_pct,
        -- Creativity: anchor big_chances/90 (2×), + chances/90, key_passes/90, chance_quality%, cross_acc%, passes_final_third/90 → /7
        round((  percent_rank() over (order by chances_per90)
               + 2 * percent_rank() over (order by big_chances_per90)
               + percent_rank() over (order by key_passes_per90)
               + percent_rank() over (order by chance_quality_pct)
               + percent_rank() over (order by cross_acc_pct)
               + percent_rank() over (order by passes_final_third_per90)) / 7 * 100)               as creativity_pct,
        -- Possession: anchor pass_acc% (2×), + dribble_success%, long_ball_success% → /4
        round((2 * percent_rank() over (order by pass_acc_pct)
                 + percent_rank() over (order by dribble_success_pct)
                 + percent_rank() over (order by long_ball_success_pct)) / 4 * 100)                as possession_pct,
        -- Defending: anchor (tkl+int)/90 (2×), + tackle_success%, balls_recovered/90, times_dribbled_past/90 ↓, errors/90 ↓ → /6
        round((2 * percent_rank() over (order by tkl_int_per90)
                 + percent_rank() over (order by tackle_success_pct)
                 + percent_rank() over (order by balls_recovered_per90)
                 + percent_rank() over (order by times_dribbled_past_per90 desc)
                 + percent_rank() over (order by errors_per90 desc)) / 6 * 100)                    as defending_pct,
        -- Physicality: anchor duel_win% (2×), + fouls_drawn/90, aerial_success% → /4
        round((2 * percent_rank() over (order by duel_win_pct)
                 + percent_rank() over (order by fouls_drawn_per90)
                 + percent_rank() over (order by aerial_success_pct)) / 4 * 100)                   as physicality_pct,
        -- Impact: avg_rating (single)
        round(percent_rank() over (order by avg_rating) * 100)                                     as impact_pct
    from base
)
select * from ranked where player_name = '${inputs.player.value}'
```

---

## Top Players

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
      <div style="font-size:0.55rem;color:#94a3b8;text-transform:uppercase;letter-spacing:0.06em;white-space:nowrap;">{inputs.podium_measure.label}</div>
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
      <div style="font-size:0.6rem;color:#a16207;text-transform:uppercase;letter-spacing:0.06em;white-space:nowrap;">{inputs.podium_measure.label}</div>
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
      <div style="font-size:0.55rem;color:#b45309;text-transform:uppercase;letter-spacing:0.06em;white-space:nowrap;">{inputs.podium_measure.label}</div>
    </div>
    <div style="width:100%;height:44px;background:linear-gradient(to bottom,#cd7c2f,#a05c24);border-radius:4px 4px 0 0;"></div>
  </div>

</div>

---

## Player Deep Dive

*Filter by position and team, then select a player to explore their profile, season stats, player characteristics, performance timeline, and match log.*

{#key positions.map(p => p.player_position).join(',')}
<Dropdown data={positions} name=position value=player_position label=player_position multiple=true defaultValue={['All']} />
{/key}

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
        <div class="h-2.5 rounded-full bg-amber-400" style="width:{lc.attacking_pct}%"></div>
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
        <div class="h-2.5 rounded-full bg-orange-400" style="width:{lc.physicality_pct}%"></div>
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
    colorPalette={['#fbbf24','#94a3b8']}
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
    colorPalette={['#fb923c','#94a3b8']}
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
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
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
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
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