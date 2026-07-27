---
sidebar: never
hide_toc: true
title: League Intelligence
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
  import TeamRadar from '../../components/TeamRadar.svelte';

  const scatterPalette = ['#3b82f6','#ef4444','#22c55e','#f59e0b','#8b5cf6','#ec4899','#14b8a6','#f97316','#6366f1','#84cc16','#06b6d4','#a855f7'];
  let selectedTeam    = null;
  let radarHighlighted = null;
  function toggleTeam(name) { selectedTeam = selectedTeam === name ? null : name; }
</script>

<style>
  @media (min-width: 768px) {
    .md\:two-col-radar { grid-template-columns: repeat(2, 1fr) !important; }
    .md\:order-reset   { order: 0 !important; }
  }
</style>

```sql seasons
select tournament from (
  select tournament, max(is_current_tournament::int) as is_current
  from ligamx.mart_match_facts
  where result in ('Win', 'Draw', 'Loss')
  group by tournament
)
order by is_current desc, tournament desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from ligamx.mart_match_facts
  where tournament = '${inputs.season.value}'
    and result in ('Win', 'Draw', 'Loss')
) order by ord, team_name
```

```sql rounds
select round, round_label from (
  select 'All Rounds' as round, 'All Rounds' as round_label, -1 as ord
  union all
  select distinct round_order::varchar as round, round_label, round_order as ord
  from ligamx.mart_match_facts
  where tournament = '${inputs.season.value}'
) order by ord
```

```sql phases
select match_round_type from (
  select distinct match_round_type,
    case match_round_type
      when 'Regular Season'  then 1
      when 'Reclasificación' then 2
      when 'Play-offs'       then 3
      when 'Quarter-finals'  then 4
      when 'Semi-finals'     then 5
      when 'Final'           then 6
      else 7
    end as ord
  from ligamx.mart_match_facts
) order by ord
```

```sql venues
select distinct team_side from ligamx.mart_match_facts order by team_side
```

```sql results
select result from (
  select distinct result,
    case result when 'Win' then 1 when 'Draw' then 2 when 'Loss' then 3 else 4 end as ord
  from ligamx.mart_match_facts
) order by ord
```

```sql opponents
select opponent_team_name from (
  select 'All Opponents' as opponent_team_name, 0 as ord
  union all
  select distinct opponent_team_name, 1 as ord
  from ligamx.mart_match_facts
  where tournament = '${inputs.season.value}'
) order by ord, opponent_team_name
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Slice the league any way you like — by tournament, team, round, phase, home/away, result or opponent. Every section below updates to the selection, except the league table and cumulative points race, which always reflect the full regular season. Advanced measures begin at 2024/25 Clausura, so charts that rely on them are empty for earlier tournaments.</p>

<div class="flex flex-wrap gap-3 items-end mb-2">
  {#key seasons[0]?.tournament}
  <Dropdown data={seasons} name=season value=tournament label=tournament order="tournament desc" defaultValue={seasons[0]?.tournament} title="Season" />
  {/key}
  <Dropdown data={teams} name=team value=team_name label=team_name multiple=true defaultValue={['All Teams']} title="Team" />
</div>

<details class="mb-4">
  <summary class="cursor-pointer inline-flex items-center gap-1.5 text-sm font-medium text-gray-600 hover:text-gray-900 select-none w-fit">
    <span class="text-xs">⚙</span> Additional filters
  </summary>
  <div class="flex flex-wrap gap-3 items-end mt-3">
    {#key inputs.season.value}
    <Dropdown data={rounds} name=round value=round label=round_label multiple=true defaultValue={['All Rounds']} order="try_cast(value as double) nulls first" title="Round" />
    {/key}
    <Dropdown data={phases} name=phase value=match_round_type multiple=true selectAllByDefault=true title="Phase" />
    <Dropdown data={venues} name=venue value=team_side multiple=true selectAllByDefault=true title="Home / Away" />
    <Dropdown data={results} name=result value=result multiple=true selectAllByDefault=true title="Result" />
    {#key inputs.season.value}
    <Dropdown data={opponents} name=opponent value=opponent_team_name multiple=true defaultValue={['All Opponents']} title="Opponent" />
    {/key}
  </div>
</details>

```sql league_kpis
with curr as (
    select
        count(distinct match_id)                                                                        as total_matches,
        sum(goals_scored)                                                                               as total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as goals_per_match,
        round(100.0 * count(*) filter (where team_side='Home' and result='Win')
              / nullif(count(*) filter (where team_side='Home'), 0), 1)                                 as home_win_pct,
        round(100.0 * sum(shots_on_goal) / nullif(sum(total_shots), 0), 1)                              as shot_accuracy,
        round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                               as shot_conversion,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as pass_accuracy,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as yc_per_match,
        case when count(penalty_missed) = 0 then null else
             round(100.0 * sum(penalty_scored)
                   / nullif(sum(penalty_scored) + sum(penalty_missed), 0), 1) end                   as penalty_success,
        round(sum(shots_on_goal)::double / count(distinct match_id), 1)                                as sot_per_match
    from ligamx.mart_match_facts
    where tournament = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ${inputs.result.value}
      and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
),
prev as (
    select
        sum(goals_scored)                                                                               as prev_total_goals,
        round(sum(goals_scored)::double / count(distinct match_id), 2)                                  as prev_goals_per_match,
        round(100.0 * sum(shots_on_goal) / nullif(sum(total_shots), 0), 1)                              as prev_shot_accuracy,
        round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                               as prev_shot_conversion,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                           as prev_pass_accuracy,
        round(sum(yellow_cards)::double / count(distinct match_id), 2)                                  as prev_yc_per_match,
        case when count(penalty_missed) = 0 then null else
             round(100.0 * sum(penalty_scored)
                   / nullif(sum(penalty_scored) + sum(penalty_missed), 0), 1) end                   as prev_penalty_success,
        round(sum(shots_on_goal)::double / count(distinct match_id), 1)                                as prev_sot_per_match
    from ligamx.mart_match_facts
    where tournament = (
        select max(tournament) from ligamx.mart_match_facts
        where tournament < '${inputs.season.value}'
          and result in ('Win','Draw','Loss')
    )
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ${inputs.result.value}
      and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
)
select
    curr.*,
    prev.*,
    round(curr.total_goals       / nullif(prev.prev_total_goals,       0), 2) as total_goals_ratio,
    round(curr.goals_per_match   / nullif(prev.prev_goals_per_match,   0), 2) as goals_ratio,
    round(curr.shot_accuracy     / nullif(prev.prev_shot_accuracy,     0), 2) as shot_acc_ratio,
    round(curr.shot_conversion   / nullif(prev.prev_shot_conversion,   0), 2) as shot_conv_ratio,
    round(curr.pass_accuracy     / nullif(prev.prev_pass_accuracy,     0), 2) as pass_ratio,
    round(curr.yc_per_match      / nullif(prev.prev_yc_per_match,      0), 2) as yc_ratio,
    round(curr.penalty_success   / nullif(prev.prev_penalty_success,   0), 2) as penalty_success_ratio,
    round(curr.sot_per_match     / nullif(prev.prev_sot_per_match,     0), 2) as sot_ratio
from curr cross join prev
```

```sql scorers
-- Built from the event stream, the only place Liga MX names a player. Assists
-- and player ratings are not published at all, so the Danish page's other two
-- awards have no counterpart here.
with ranked as (
    select
        player_name, team_name, max(team_logo) as team_logo,
        sum(goals_scored)::int                              as goals,
        row_number() over (order by sum(goals_scored) desc, player_name) as rn
    from ligamx.mart_scorers
    where tournament = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ${inputs.result.value}
      and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
    group by player_name, team_name
    having sum(goals_scored) > 0
)
select * from ranked where rn <= 3 order by rn
```

```sql current_standings
select
    team_name,
    team_short_name,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_name       || '</span></div>' as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_short_name || '</span></div>' as team_col_mobile,
    count(distinct match_id)                          as mp,
    sum(points_earned)                                as pts,
    sum(goals_scored) - sum(goals_conceded)           as gd,
    sum(goals_scored)                                 as gf,
    sum(goals_conceded)                               as ga
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ('Win', 'Draw', 'Loss')
  and match_round_type = 'Regular Season'
group by team_name, team_short_name, team_logo
order by pts desc, gd desc, gf desc
```

```sql team_landscape
select
    team_name,
    team_logo,
    sum(goals_scored)::int                                                                   as goals_for,
    sum(goals_conceded)::int                                                                 as goals_against,
    sum(points_earned)::int                                                                  as points,
    round(100.0 * count(*) filter (where result='Win') / count(*), 1)                       as win_pct,
    round(100.0 * sum(goals_scored) / nullif(sum(total_shots), 0), 1)                       as shot_conv,
    count(distinct match_id) filter (where goals_conceded = 0)::int                         as clean_sheets,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)                   as pass_accuracy
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by team_name, team_logo
order by team_name
```

```sql team_landscape_bounds
select
    floor(min(goals_for)  * 0.9)  as x_min,
    ceil(max(goals_for)   * 1.1)  as x_max,
    floor(min(goals_against) * 0.9) as y_min,
    ceil(max(goals_against)  * 1.1) as y_max
from (
    select
        sum(goals_scored)::int   as goals_for,
        sum(goals_conceded)::int as goals_against
    from ligamx.mart_match_facts
    where tournament = '${inputs.season.value}'
      and result in ${inputs.result.value}
      and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
    group by team_name
)
```

```sql points_progression
-- Regular rounds only: the liguilla puts nothing on the table, so a race that
-- ran through it would flatline for five rounds at the end of every tournament.
select round_order as round, team_name, cumulative_points, cumulative_gd, cumulative_gf
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ('Win', 'Draw', 'Loss')
  and match_round_type = 'Regular Season'
order by max(cumulative_points) over (partition by team_name) desc, team_name, round_order
```

```sql team_domain_stats
-- Domain measures, substituted where Liga MX has no equivalent of the Danish
-- one. Creativity trades chances created (not published) for expected assists;
-- Defending trades errors, balls recovered and times dribbled past for
-- interceptions, clearances and saves; Physicality trades duels and fouls
-- drawn for aerial volume and fouls committed. Everything outside Attacking,
-- Possession and Winning belongs to the deep-stat era from 2024/25 Clausura
-- and is NULL before it — the charts render empty rather than claiming zero.
select
    team_name,
    -- Attacking (higher = better)
    sum(goals_scored)::double           / count(distinct match_id)                     as goals_pm,
    sum(shots_on_goal)::double          / count(distinct match_id)                     as sog_pm,
    sum(shots_on_goal)::double          / nullif(sum(total_shots), 0)                  as shot_acc_pct,
    sum(corner_kicks)::double           / count(distinct match_id)                     as corners_pm,
    -- Creativity & Playmaking (higher = better)
    sum(expected_assists)::double       / count(distinct match_id)                     as xa_pm,
    sum(big_chances_created)::double    / count(distinct match_id)                     as big_chances_pm,
    sum(key_passes)::double             / count(distinct match_id)                     as key_passes_pm,
    sum(crosses_accurate)::double       / nullif(sum(crosses_total), 0)                as cross_acc_pct,
    sum(passes_final_third)::double     / count(distinct match_id)                     as passes_final_third_pm,
    -- Possession & Control (higher = better)
    avg(possession_pct)::double         / 100.0                                        as possession_pct,
    sum(passes_accurate)::double        / nullif(sum(total_passes), 0)                 as pass_acc_pct,
    sum(dribbles_completed)::double     / nullif(sum(dribbles_attempts), 0)            as dribble_success_pct,
    -- Defending (mixed — see chart ordering)
    sum(goals_conceded)::double         / count(distinct match_id)                     as conceded_pm,
    sum(tackles_won)::double            / nullif(sum(tackles), 0)                      as tackle_success_pct,
    sum(interceptions)::double          / count(distinct match_id)                     as interceptions_pm,
    sum(clearances)::double             / count(distinct match_id)                     as clearances_pm,
    sum(saves)::double                  / count(distinct match_id)                     as saves_pm,
    -- Physicality (mixed — fewer fouls is better)
    sum(aerials_won)::double            / nullif(sum(aerial_duels), 0)                 as aerial_success_pct,
    sum(aerial_duels)::double           / count(distinct match_id)                     as aerial_duels_pm,
    sum(fouls)::double                  / count(distinct match_id)                     as fouls_pm,
    -- Winning (higher = better)
    sum(case when result = 'Win' then 1 else 0 end)::double / count(distinct match_id)      as win_pct,
    sum(points_earned)::double          / count(distinct match_id)                     as points_pm,
    sum(case when goals_conceded = 0 then 1 else 0 end)::double / count(distinct match_id)  as clean_sheet_pct
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by team_name
order by team_name
```

```sql radar_data
-- Same six composites as the Danish radar, over the measures Liga MX has.
--
-- A domain scores only when every measure feeding it exists for the selected
-- slice; otherwise it is NULL and the radar draws that axis at the centre with
-- an em dash. This guard matters: percent_rank over an all-NULL column returns
-- 0 for every team, and the row_number scoring below would then spread those
-- identical zeroes across 0-100 by tie-break order — inventing a ranking, with
-- a confident 100/100 for whichever club sorted first. Attacking and Winning
-- need no guard; their inputs run from 2020/21 Apertura.
with all_teams as (
    select
        team_name,
        -- Attacking
        sum(goals_scored)::double                   / count(distinct match_id)               as goals_pm,
        sum(shots_on_goal)::double                  / count(distinct match_id)               as sog_pm,
        100.0 * sum(shots_on_goal)  / nullif(sum(total_shots), 0)                           as shot_acc_pct,
        sum(corner_kicks)::double                   / count(distinct match_id)               as corners_pm,
        -- Creativity & Playmaking
        sum(expected_assists)::double               / count(distinct match_id)               as xa_pm,
        sum(big_chances_created)::double            / count(distinct match_id)               as big_chances_pm,
        sum(key_passes)::double                     / count(distinct match_id)               as key_passes_pm,
        100.0 * sum(crosses_accurate)    / nullif(sum(crosses_total), 0)                    as cross_acc_pct,
        sum(passes_final_third)::double             / count(distinct match_id)               as passes_final_third_pm,
        -- Possession & Control
        avg(possession_pct)                                                                  as avg_possession,
        100.0 * sum(passes_accurate)     / nullif(sum(total_passes), 0)                     as pass_acc_pct,
        100.0 * sum(dribbles_completed)  / nullif(sum(dribbles_attempts), 0)                as dribble_success_pct,
        -- Defending
        sum(goals_conceded)::double                 / count(distinct match_id)               as conceded_pm,
        100.0 * sum(tackles_won)         / nullif(sum(tackles), 0)                          as tackle_success_pct,
        sum(interceptions)::double                  / count(distinct match_id)               as interceptions_pm,
        sum(clearances)::double                     / count(distinct match_id)               as clearances_pm,
        sum(saves)::double                          / count(distinct match_id)               as saves_pm,
        -- Physicality
        100.0 * sum(aerials_won)         / nullif(sum(aerial_duels), 0)                     as aerial_success_pct,
        sum(aerial_duels)::double                   / count(distinct match_id)               as aerial_duels_pm,
        sum(fouls)::double                          / count(distinct match_id)               as fouls_pm,
        -- Winning
        sum(case when result = 'Win' then 1 else 0 end)::double / count(distinct match_id)  as win_rate
    from ligamx.mart_match_facts
    where tournament = '${inputs.season.value}'
      and result in ${inputs.result.value}
      and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
    group by team_name
),
availability as (
    -- Whether each domain's measures were recorded at all in this slice.
    select
        count(xa_pm) > 0 and count(big_chances_pm) > 0 and count(key_passes_pm) > 0
            and count(cross_acc_pct) > 0 and count(passes_final_third_pm) > 0   as has_creativity,
        count(dribble_success_pct) > 0                                          as has_possession,
        count(tackle_success_pct) > 0 and count(interceptions_pm) > 0
            and count(clearances_pm) > 0                                        as has_defending,
        count(aerial_success_pct) > 0 and count(aerial_duels_pm) > 0            as has_physicality
    from all_teams
),
ranked as (
    select
        team_name,
        -- Attacking
        percent_rank() over (order by goals_pm)            as r_goals,
        percent_rank() over (order by sog_pm)              as r_sog,
        percent_rank() over (order by shot_acc_pct)        as r_shot_acc,
        percent_rank() over (order by corners_pm)          as r_corners,
        -- Creativity
        percent_rank() over (order by xa_pm)                    as r_xa,
        percent_rank() over (order by big_chances_pm)           as r_big_chances,
        percent_rank() over (order by key_passes_pm)            as r_key_passes,
        percent_rank() over (order by cross_acc_pct)            as r_cross_acc,
        percent_rank() over (order by passes_final_third_pm)    as r_passes_final_third,
        -- Possession
        percent_rank() over (order by avg_possession)      as r_possession,
        percent_rank() over (order by pass_acc_pct)        as r_pass_acc,
        percent_rank() over (order by dribble_success_pct) as r_dribble_success,
        -- Defending (fewer conceded = better → rank desc)
        percent_rank() over (order by conceded_pm desc)          as r_conceded,
        percent_rank() over (order by tackle_success_pct)        as r_tackle_success,
        percent_rank() over (order by interceptions_pm)          as r_interceptions,
        percent_rank() over (order by clearances_pm)             as r_clearances,
        percent_rank() over (order by saves_pm)                  as r_saves,
        -- Physicality (fewer fouls = better → rank desc)
        percent_rank() over (order by aerial_success_pct)  as r_aerial_success,
        percent_rank() over (order by aerial_duels_pm)     as r_aerial_duels,
        percent_rank() over (order by fouls_pm desc)       as r_fouls,
        -- Winning
        percent_rank() over (order by win_rate)            as r_wins
    from all_teams
),
composites as (
    select
        team_name,
        (2 * r_goals + r_sog + r_shot_acc + r_corners) / 5                                              as raw_attacking,
        case when a.has_creativity then
            (r_xa + 2 * r_big_chances + r_key_passes + r_cross_acc + r_passes_final_third) / 6 end      as raw_creativity,
        case when a.has_possession then
            (r_possession + 2 * r_pass_acc + r_dribble_success) / 4 end                                 as raw_possession,
        case when a.has_defending then
            (2 * r_conceded + r_tackle_success + r_interceptions + r_clearances + r_saves) / 6 end      as raw_defending,
        case when a.has_physicality then
            (2 * r_aerial_success + r_aerial_duels + r_fouls) / 4 end                                   as raw_physicality,
        r_wins                                                                                          as raw_winning
    from ranked cross join availability a
),
scores as (
    select
        team_name,
        round((row_number() over (order by raw_attacking)   - 1) * 100.0 / nullif(count(*) over () - 1, 0)) as attacking_score,
        case when raw_creativity  is null then null else
            round((row_number() over (order by raw_creativity)  - 1) * 100.0 / nullif(count(*) over () - 1, 0)) end as creativity_score,
        case when raw_possession  is null then null else
            round((row_number() over (order by raw_possession)  - 1) * 100.0 / nullif(count(*) over () - 1, 0)) end as possession_score,
        case when raw_defending   is null then null else
            round((row_number() over (order by raw_defending)   - 1) * 100.0 / nullif(count(*) over () - 1, 0)) end as defending_score,
        case when raw_physicality is null then null else
            round((row_number() over (order by raw_physicality) - 1) * 100.0 / nullif(count(*) over () - 1, 0)) end as physicality_score,
        round((row_number() over (order by raw_winning)     - 1) * 100.0 / nullif(count(*) over () - 1, 0)) as winning_score
    from composites
)
select * from scores
where ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
order by team_name
```

```sql match_log
select distinct
    tournament,
    match_date,
    month_name,
    day_name,
    is_weekend,
    kick_off_time,
    period_of_day,
    cast(round_order as integer) as round_order,
    round_display,
    match_round_type,
    match_name,
    score,
    match_status,
    team_name,
    team_side,
    result,
    opponent_team_name,
    referee_name,
    stadium_name,
    stadium_city,
    goals_scored
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
order by match_date desc, team_name
```

```sql match_schedule
select
    day_name,
    period_of_day,
    count(distinct match_id)::int as matches
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by day_name, period_of_day
order by case day_name
    when 'Monday'    then 1 when 'Tuesday'  then 2 when 'Wednesday' then 3
    when 'Thursday'  then 4 when 'Friday'   then 5 when 'Saturday'  then 6
    when 'Sunday'    then 7 end,
    case period_of_day
    when 'Morning' then 1 when 'Noon' then 2 when 'Afternoon' then 3 when 'Evening' then 4 when 'Night' then 5 else 6 end
```

```sql goals_by_slot
select
    period_of_day,
    count(distinct match_id)::int                                              as matches,
    round(sum(goals_scored)::double / count(distinct match_id), 2)             as goals_per_match
from ligamx.mart_match_facts
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by period_of_day
order by case period_of_day
    when 'Morning' then 1 when 'Noon' then 2 when 'Afternoon' then 3 when 'Evening' then 4 when 'Night' then 5 else 6 end
```

---

## League Intelligence — {inputs.season.value}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Top-line KPIs for the selected season, each compared against the previous season. Applies to the team filter if set.</p>

{#each league_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Total Goals</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.total_goals}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_total_goals ?? '—'}</span>
      {#if k.total_goals_ratio != null}<span class="text-sm font-bold {k.total_goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.total_goals_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_goals_per_match ?? '—'}</span>
      {#if k.goals_ratio != null}<span class="text-sm font-bold {k.goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.goals_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shots on Target / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.sot_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_sot_per_match ?? '—'}</span>
      {#if k.sot_ratio != null}<span class="text-sm font-bold {k.sot_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.sot_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_shot_accuracy != null ? k.prev_shot_accuracy + '%' : '—'}</span>
      {#if k.shot_acc_ratio != null}<span class="text-sm font-bold {k.shot_acc_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.shot_acc_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Conversion %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_conversion}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_shot_conversion != null ? k.prev_shot_conversion + '%' : '—'}</span>
      {#if k.shot_conv_ratio != null}<span class="text-sm font-bold {k.shot_conv_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.shot_conv_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.pass_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_pass_accuracy != null ? k.prev_pass_accuracy + '%' : '—'}</span>
      {#if k.pass_ratio != null}<span class="text-sm font-bold {k.pass_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.pass_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Penalty Success %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.penalty_success}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_penalty_success != null ? k.prev_penalty_success + '%' : '—'}</span>
      {#if k.penalty_success_ratio != null}<span class="text-sm font-bold {k.penalty_success_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.penalty_success_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">YC / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.yc_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_yc_per_match ?? '—'}</span>
      {#if k.yc_ratio != null}<span class="text-sm font-bold {k.yc_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.yc_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>

</div>
{/each}

---

## Season Awards

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Top scorer for the selected tournament, with the runners-up stacked below. Liga MX publishes no assists or player ratings, so the goalscorer is the one award the data supports — it is read off the match event stream, which names the scorer on every goal.</p>

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">

{#if scorers.length > 0}
<div style="position: relative;">

  <!-- Scorer rank 1 -->
  <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow-lg p-5" style="position: relative; z-index: 3;">
    <div class="text-xs uppercase tracking-widest text-amber-600 font-bold mb-3">⚽ Top Scorer</div>
    <div class="flex items-center gap-4">
      <img src="{scorers[0].team_logo}" alt="{scorers[0].team_name}" class="w-16 h-16 object-contain" onerror="this.style.display='none'" />
      <div>
        <div class="text-xl font-extrabold text-gray-800 leading-tight">{scorers[0].player_name}</div>
        <div class="text-sm text-gray-500 mt-0.5">{scorers[0].team_name}</div>
      </div>
    </div>
    <div class="mt-3 text-3xl font-black text-amber-500 text-right">{scorers[0].goals} <span class="text-base font-normal text-gray-500">goals</span></div>
  </div>

  {#if scorers.length > 1}
  <!-- Scorer rank 2 peek -->
  <div style="position: relative; z-index: 2; margin-top: -10px; overflow: hidden; height: 60px; margin-left: 8px; margin-right: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.12); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow p-3" style="opacity: 0.88;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-amber-400 flex-shrink-0">2</span>
          <span class="text-sm font-bold text-gray-800 truncate">{scorers[1].player_name}</span>
        </div>
        <span class="text-sm font-black text-amber-500 flex-shrink-0">{scorers[1].goals} <span class="text-xs font-normal text-gray-400">goals</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{scorers[1].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #fde68a;"></div>
  </div>
  {/if}

  {#if scorers.length > 2}
  <!-- Scorer rank 3 peek -->
  <div style="position: relative; z-index: 1; margin-top: -10px; overflow: hidden; height: 52px; margin-left: 24px; margin-right: 8px; box-shadow: 0 3px 8px rgba(0,0,0,0.08); border-radius: 0 0 0.75rem 0.75rem;">
    <div class="rounded-2xl bg-gradient-to-br from-amber-50 to-yellow-100 border border-amber-200 shadow-sm p-3" style="opacity: 0.72;">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-baseline gap-1.5 min-w-0">
          <span class="text-xs font-black text-amber-300 flex-shrink-0">3</span>
          <span class="text-sm font-bold text-gray-700 truncate">{scorers[2].player_name}</span>
        </div>
        <span class="text-sm font-black text-amber-400 flex-shrink-0">{scorers[2].goals} <span class="text-xs font-normal text-gray-400">goals</span></span>
      </div>
      <div class="text-xs text-gray-400 mt-0.5 ml-4">{scorers[2].team_name}</div>
    </div>
    <div style="position: absolute; bottom: 0; left: 0; right: 0; height: 1.5px; background: #fde68a;"></div>
  </div>
  {/if}

</div>
{:else}
<div class="rounded-2xl border border-gray-200 bg-white p-5 text-center text-gray-400 text-sm">
  No goals in the selected slice.
</div>
{/if}

</div>

---

## Standings & Points Race

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Cumulative points race round by round alongside the current league table. Hover a round on the line chart to see the full ranking.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-start">

<div>

#### Points Race

<!-- chartAreaHeight is taller than the Danish page's 300: Liga MX fields 18
     clubs, so the league table beside this chart is six rows deeper, and the
     two columns only finish level at roughly this height. -->
<LineChart
    data={points_progression}
    x=round
    y=cumulative_points
    series=team_name
    xAxisTitle="Round"
    yAxisTitle="Cumulative Points"
    echartsOptions={{tooltip: {formatter: (function() { const lookup = {}; for (const row of points_progression) { if (!lookup[row.round]) lookup[row.round] = {}; lookup[row.round][row.team_name] = {gd: row.cumulative_gd, gf: row.cumulative_gf}; } return function(params) { const round = params[0].value[0]; const roundData = lookup[round] || {}; const sorted = [...params].sort((a, b) => { if (b.value[1] !== a.value[1]) return b.value[1] - a.value[1]; const pa = roundData[a.seriesName] || {gd: 0, gf: 0}; const pb = roundData[b.seriesName] || {gd: 0, gf: 0}; if (pb.gd !== pa.gd) return pb.gd - pa.gd; return pb.gf - pa.gf; }); let out = '<span style="font-weight:600;">Round ' + round + '</span>'; for (const p of sorted) { out += '<br><span style="font-size:11px;">' + p.marker + ' ' + p.seriesName + '</span><span style="float:right;margin-left:10px;font-size:12px;">' + p.value[1] + '</span>'; } return out; }; })()}}}
    legend=false
    chartAreaHeight=470
/>

</div>

<div>

#### League Table

<div class="block md:hidden">
<DataTable data={current_standings} rows=20>
    <Column id=team_col_mobile title="Team"  contentType=html />
    <Column id=mp              title="MP"   align=center />
    <Column id=gd              title="GD"   align=center />
    <Column id=pts             title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={current_standings} rows=20>
    <Column id=team_col    title="Team"  contentType=html />
    <Column id=mp          title="MP"   align=center />
    <Column id=gf          title="GF"   align=center />
    <Column id=ga          title="GA"   align=center />
    <Column id=gd          title="GD"   align=center />
    <Column id=pts         title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>
</div>

</div>

</div>

---

## Team Landscape & Radar

<div style="display:grid;grid-template-columns:repeat(1,1fr);gap:0 1.5rem;margin-bottom:1.5rem;" class="md:two-col-radar">

<!-- Titles: order 1 & 5 on mobile, reset to DOM order on desktop -->
<p style="order:1;font-size:0.875rem;font-weight:600;color:#374151;margin:1rem 0 0.25rem 0;" class="md:order-reset">Attack vs Defence — {inputs.season.value}</p>
<p style="order:5;font-size:0.875rem;font-weight:600;color:#374151;margin:1rem 0 0.25rem 0;" class="md:order-reset">Performance Radar</p>

<!-- Explanations: order 2 & 6 on mobile, reset to DOM order on desktop -->
<p style="order:2;font-size:0.75rem;color:#6b7280;margin:0 0 0.5rem 0;font-style:italic;" class="md:order-reset">Where does each team sit on the attack vs defence spectrum? Teams to the right score more, teams lower down concede less. The bottom-right corner is where champions live.</p>
<p style="order:6;font-size:0.75rem;color:#6b7280;margin:0 0 0.5rem 0;font-style:italic;" class="md:order-reset">How does a team rank across six dimensions relative to the rest of the league? Each axis is a score from 0 to 100 — 100 means best in the league. Click a team in the legend to isolate it.</p>

<!-- Charts: order 3 & 7 on mobile -->
<div style="order:3;" class="md:order-reset">
<ScatterPlot
    data={team_landscape}
    x=goals_for
    y=goals_against
    series=team_name
    xAxisTitle="Goals Scored"
    yAxisTitle="Goals Conceded"
    tooltipColumns={[{id: 'team_name', title: 'Team'}, {id: 'goals_for', title: 'Goals For'}, {id: 'goals_against', title: 'Goals Against'}, {id: 'points', title: 'Points'}, {id: 'win_pct', title: 'Win %', fmt: '0.0"%"'}]}
    chartAreaHeight=320
    legend=false
    xMin={team_landscape_bounds[0].x_min}
    xMax={team_landscape_bounds[0].x_max}
    yMin={team_landscape_bounds[0].y_min}
    yMax={team_landscape_bounds[0].y_max}
    echartsOptions={{series: team_landscape.map((row, i) => ({name: row.team_name, symbolSize: 16, itemStyle: {color: selectedTeam === null || row.team_name === selectedTeam ? scatterPalette[i % 12] : '#d1d5db', borderWidth: 2, borderColor: selectedTeam === null || row.team_name === selectedTeam ? scatterPalette[i % 12] : '#d1d5db'}}))}}
/>
</div>
<div style="order:7;" class="md:order-reset">
<TeamRadar data={radar_data} showLegend={false} bind:highlighted={radarHighlighted} />
</div>

<!-- Legends: order 4 & 8 on mobile -->
<div style="order:4;display:flex;flex-wrap:wrap;gap:6px 14px;justify-content:center;margin-top:4px;" class="md:order-reset">
  {#each team_landscape as row, i}
  <div
    on:click={() => toggleTeam(row.team_name)}
    style="display:flex;align-items:center;gap:5px;font-size:11px;cursor:pointer;transition:opacity 0.15s;
           opacity:{selectedTeam === null || selectedTeam === row.team_name ? 1 : 0.35};
           color:{selectedTeam === row.team_name ? scatterPalette[i % 12] : '#374151'};
           font-weight:{selectedTeam === row.team_name ? '700' : '400'};"
  >
    <div style="width:10px;height:10px;border-radius:50%;background:{scatterPalette[i % 12]};flex-shrink:0;"></div>
    {row.team_name}
  </div>
  {/each}
</div>
<div style="order:8;display:flex;flex-wrap:wrap;gap:6px 14px;justify-content:center;margin-top:4px;" class="md:order-reset">
  {#each radar_data as row, i}
  <div
    on:click={() => radarHighlighted = radarHighlighted === row.team_name ? null : row.team_name}
    style="display:flex;align-items:center;gap:5px;font-size:11px;cursor:pointer;transition:opacity 0.15s;
           opacity:{radarHighlighted === null || radarHighlighted === row.team_name ? 1 : 0.35};
           color:{radarHighlighted === row.team_name ? scatterPalette[i % scatterPalette.length] : '#374151'};
           font-weight:{radarHighlighted === row.team_name ? '700' : '400'};"
  >
    <div style="width:10px;height:10px;border-radius:50%;background:{scatterPalette[i % scatterPalette.length]};flex-shrink:0;"></div>
    {row.team_name}
  </div>
  {/each}
</div>

</div>

---

## Team Rankings by Domain

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">All teams ranked within each performance dimension. Pick the measure that matters to you from each dropdown. Sorted best to worst so the strongest performers are always at the top — for goals conceded and fouls, lower is better, so the tightest teams lead. Every measure outside Attacking, Possession and Winning starts at 2024/25 Clausura and is empty for earlier tournaments.</p>

```sql attacking_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on goals_pm, sog_pm, shot_acc_pct, corners_pm
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.attack_measure.value}'
order by val desc
```

```sql creativity_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on xa_pm, big_chances_pm, key_passes_pm, cross_acc_pct, passes_final_third_pm
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.creativity_measure.value}'
order by val desc
```

```sql possession_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on possession_pct, pass_acc_pct, dribble_success_pct
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.possession_measure.value}'
order by val desc
```

```sql defending_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on conceded_pm, tackle_success_pct, interceptions_pm, clearances_pm, saves_pm
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.defense_measure.value}'
order by case when measure = 'conceded_pm' then val else -val end asc
```

```sql physicality_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on aerial_success_pct, aerial_duels_pm, fouls_pm
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.physicality_measure.value}'
order by case when measure = 'fouls_pm' then val else -val end asc
```

```sql winning_ranked
with wide as ( select * from ${team_domain_stats} ),
up as (
    unpivot wide
    on win_pct, points_pm, clean_sheet_pct
    into name measure value val
)
select team_name, measure, val from up
where measure = '${inputs.winning_measure.value}'
order by val desc
```

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<Dropdown name=attack_measure title="Measure" defaultValue="goals_pm">
    <DropdownOption value="goals_pm" valueLabel="Goals per Match" />
    <DropdownOption value="sog_pm" valueLabel="Shots on Goal per Match" />
    <DropdownOption value="shot_acc_pct" valueLabel="Shot Accuracy %" />
    <DropdownOption value="corners_pm" valueLabel="Corners per Match" />
</Dropdown>

<BarChart
    data={attacking_ranked}
    x=team_name
    y=val
    title={'Attacking — ' + (inputs.attack_measure.label || '')}
    yAxisTitle={inputs.attack_measure.label}
    colorPalette={['#3b82f6']}
    swapXY=true
    sort=false
    fmt={(inputs.attack_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

<div>

<Dropdown name=creativity_measure title="Measure" defaultValue="big_chances_pm">
    <DropdownOption value="xa_pm" valueLabel="Expected Assists per Match" />
    <DropdownOption value="big_chances_pm" valueLabel="Big Chances Created per Match" />
    <DropdownOption value="key_passes_pm" valueLabel="Key Passes per Match" />
    <DropdownOption value="cross_acc_pct" valueLabel="Cross Accuracy %" />
    <DropdownOption value="passes_final_third_pm" valueLabel="Passes into Final Third per Match" />
</Dropdown>

<BarChart
    data={creativity_ranked}
    x=team_name
    y=val
    title={'Creativity — ' + (inputs.creativity_measure.label || '')}
    yAxisTitle={inputs.creativity_measure.label}
    colorPalette={['#06b6d4']}
    swapXY=true
    sort=false
    fmt={(inputs.creativity_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<Dropdown name=possession_measure title="Measure" defaultValue="pass_acc_pct">
    <DropdownOption value="possession_pct" valueLabel="Average Possession %" />
    <DropdownOption value="pass_acc_pct" valueLabel="Pass Accuracy %" />
    <DropdownOption value="dribble_success_pct" valueLabel="Dribble Success %" />
</Dropdown>

<BarChart
    data={possession_ranked}
    x=team_name
    y=val
    title={'Possession & Control — ' + (inputs.possession_measure.label || '')}
    yAxisTitle={inputs.possession_measure.label}
    colorPalette={['#8b5cf6']}
    swapXY=true
    sort=false
    fmt={(inputs.possession_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

<div>

<Dropdown name=defense_measure title="Measure" defaultValue="conceded_pm">
    <DropdownOption value="conceded_pm" valueLabel="Goals Conceded per Match" />
    <DropdownOption value="tackle_success_pct" valueLabel="Tackle Success %" />
    <DropdownOption value="interceptions_pm" valueLabel="Interceptions per Match" />
    <DropdownOption value="clearances_pm" valueLabel="Clearances per Match" />
    <DropdownOption value="saves_pm" valueLabel="Saves per Match" />
</Dropdown>

<BarChart
    data={defending_ranked}
    x=team_name
    y=val
    title={'Defending — ' + (inputs.defense_measure.label || '')}
    yAxisTitle={inputs.defense_measure.label}
    colorPalette={['#f97316']}
    swapXY=true
    sort=false
    fmt={(inputs.defense_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<Dropdown name=physicality_measure title="Measure" defaultValue="aerial_success_pct">
    <DropdownOption value="aerial_success_pct" valueLabel="Aerial Success %" />
    <DropdownOption value="aerial_duels_pm" valueLabel="Aerial Duels per Match" />
    <DropdownOption value="fouls_pm" valueLabel="Fouls per Match" />
</Dropdown>

<BarChart
    data={physicality_ranked}
    x=team_name
    y=val
    title={'Physicality — ' + (inputs.physicality_measure.label || '')}
    yAxisTitle={inputs.physicality_measure.label}
    colorPalette={['#14b8a6']}
    swapXY=true
    sort=false
    fmt={(inputs.physicality_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

<div>

<Dropdown name=winning_measure title="Measure" defaultValue="win_pct">
    <DropdownOption value="win_pct" valueLabel="Win Rate %" />
    <DropdownOption value="points_pm" valueLabel="Points per Match" />
    <DropdownOption value="clean_sheet_pct" valueLabel="Clean Sheet %" />
</Dropdown>

<BarChart
    data={winning_ranked}
    x=team_name
    y=val
    title={'Winning — ' + (inputs.winning_measure.label || '')}
    yAxisTitle={inputs.winning_measure.label}
    colorPalette={['#22c55e']}
    swapXY=true
    sort=false
    fmt={(inputs.winning_measure.value || '').endsWith('_pct') ? '0.0%' : '0.00'}
/>

</div>

</div>

---

## The Rhythm of a Match

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">League-wide event timing by 15-minute interval — when goals go in, when referees reach for cards, and when benches turn. Stoppage time (45+, 90+) counted separately.</p>

```sql league_event_timing
select
    minute_bucket,
    minute_bucket_sort,
    sum(goals)                                          as goals,
    sum(goals) filter (where team_side = 'Home')        as home_goals,
    sum(goals) filter (where team_side = 'Away')        as away_goals,
    sum(cards)                                          as cards,
    sum(substitutions)                                  as substitutions
from ligamx.mart_league_event_timing
where tournament = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and result in ${inputs.result.value}
  and ('All Rounds' in ${inputs.round.value} OR round_order::varchar in ${inputs.round.value})
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by minute_bucket, minute_bucket_sort
order by minute_bucket_sort
```

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={league_event_timing}
    x=minute_bucket
    y={['home_goals','away_goals']}
    title="Goals by Minute — Home vs Away"
    xAxisTitle="Match Minute"
    yAxisTitle="Goals"
    colorPalette={['#3b82f6','#f97316']}
    type=stacked
    chartAreaHeight=260
    sort=false
/>

<BarChart
    data={league_event_timing}
    x=minute_bucket
    y={['cards','substitutions']}
    title="Cards & Substitutions by Minute"
    xAxisTitle="Match Minute"
    yAxisTitle="Events"
    colorPalette={['#eab308','#8b5cf6']}
    type=grouped
    chartAreaHeight=260
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

</div>

---

## Match Schedule

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">When are Liga MX matches played? The left chart breaks down fixtures by day of week and time of day; the right shows whether kick-off time influences scoring. Time slots: Morning 05:00–10:59 · Noon 11:00–13:59 · Afternoon 14:00–17:59 · Evening 18:00–20:59 · Night 21:00–04:59.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={match_schedule}
    x=day_name
    y=matches
    series=period_of_day
    title="Matches by Day & Time of Day"
    xAxisTitle="Day"
    yAxisTitle="Matches"
    colorPalette={['#fbbf24','#3b82f6','#6366f1','#f97316','#10b981']}
    type=stacked
    sort=false
    echartsOptions={{xAxis: {data: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']}}}
/>

<BarChart
    data={goals_by_slot}
    x=period_of_day
    y=goals_per_match
    series=period_of_day
    title="Goals per Match by Time of Day"
    xAxisTitle="Time of Day"
    yAxisTitle="Goals / Match"
    legend=false
    sort=false
    echartsOptions={{
      xAxis: {data: ['Morning', 'Noon', 'Afternoon', 'Evening', 'Night']},
      series: goals_by_slot.map(row => ({
        itemStyle: {
          color: ({Morning:'#10b981', Noon:'#f97316', Afternoon:'#fbbf24', Evening:'#3b82f6', Night:'#6366f1'})[row.period_of_day]
        }
      }))
    }}
/>

</div>

---

## Match Log

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every team appearance for the selected season — one row per team per match. Search by anything: team, opponent, result, referee, stadium, time slot, day, round, etc. Kick-off times are local Mexico City time (CST).</p>

<DataTable data={match_log} search=true rows=6>
    <Column id=tournament          title="Season"           />
    <Column id=match_date          title="Date"             />
    <Column id=month_name          title="Month"            />
    <Column id=day_name            title="Day"              />
    <Column id=is_weekend          title="Weekend"          />
    <Column id=kick_off_time       title="Kick-off"         />
    <Column id=period_of_day       title="Time Slot"        />
    <Column id=round_order         title="Round #"          align=center />
    <Column id=round_display       title="Round"            />
    <Column id=match_round_type    title="Phase"            />
    <Column id=match_name          title="Match"            wrap=true />
    <Column id=score               title="Score"            align=center />
    <Column id=match_status        title="Status"           />
    <Column id=team_name           title="Team"             />
    <Column id=team_side           title="Side"             />
    <Column id=result              title="Result"           />
    <Column id=opponent_team_name  title="Opponent"         />
    <Column id=referee_name        title="Referee"          />
    <Column id=stadium_name        title="Stadium"          />
    <Column id=stadium_city        title="City"             />
    <Column id=goals_scored        title="Goals"            align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>

```sql last_updated
select * from ligamx.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
