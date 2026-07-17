---
sidebar: never
hide_toc: true
title: Team Intelligence
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';
  const pageInputs = getInputContext();

  $: if (teams?.length > 0) {
    pageInputs.update(($i) => {
      const currentIsValid = teams.some(t => t.team_name === $i.team?.value);
      if (currentIsValid) return $i;
      const first = teams[0];
      return { ...$i, team: { value: first.team_name, label: first.team_name, rawValues: [{ value: first.team_name, label: first.team_name, selected: true }] } };
    });
  }
</script>

```sql seasons
select distinct season
from superligaen.mart_team_season
order by season desc
```

```sql teams
select distinct team_name, team_logo
from superligaen.mart_team_season
where season = '${inputs.season.value}'
order by team_name
```

```sql rounds
select distinct match_round_number as round
from superligaen.mart_team_match
where season = '${inputs.season.value}'
order by round
```

```sql phases
select match_round_type from (
  select distinct match_round_type,
    case match_round_type
      when 'Regular Season'     then 1
      when 'Championship Round' then 2
      when 'Relegation Round'   then 3
      else 4
    end as ord
  from superligaen.mart_team_match
) order by ord
```

```sql venues
select distinct team_side from superligaen.mart_team_match order by team_side
```

```sql results
select result from (
  select distinct result,
    case result when 'Win' then 1 when 'Draw' then 2 when 'Loss' then 3 else 4 end as ord
  from superligaen.mart_team_match
) order by ord
```

```sql opponents
select opponent_team_name from (
  select 'All Opponents' as opponent_team_name, 0 as ord
  union all
  select distinct opponent_team_name, 1 as ord
  from superligaen.mart_team_match
  where season = '${inputs.season.value}'
    and team_name = '${inputs.team.value}'
) order by ord, opponent_team_name
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Pick a season and team to explore their profile. Everything responds to the additional filters — the header, KPIs, goals timeline, opponents, home/away, formation, scheduling and match log — benchmarked against the previous season sliced the same way. Only three season-level references stay fixed: Last 5 results, Ranking and Avg Squad Age (none can be derived from a filtered set of matches).</p>

<div class="flex flex-wrap gap-3 items-end mb-2">
  {#key seasons[0]?.season}
  <Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} title="Season" />
  {/key}
  {#key teams[0]?.team_name}
  <Dropdown data={teams} name=team value=team_name label=team_name defaultValue={teams[0]?.team_name} title="Team" />
  {/key}
</div>

<details class="mb-4">
  <summary class="cursor-pointer inline-flex items-center gap-1.5 text-sm font-medium text-gray-600 hover:text-gray-900 select-none w-fit">
    <span class="text-xs">⚙</span> Additional filters
  </summary>
  <div class="flex flex-wrap gap-3 items-end mt-3">
    {#key inputs.season.value}
    <Dropdown data={rounds} name=round value=round multiple=true selectAllByDefault=true title="Round" />
    {/key}
    <Dropdown data={phases} name=phase value=match_round_type multiple=true selectAllByDefault=true title="Phase" />
    <Dropdown data={venues} name=venue value=team_side multiple=true selectAllByDefault=true title="Home / Away" />
    <Dropdown data={results} name=result value=result multiple=true selectAllByDefault=true title="Result" />
    {#key `${inputs.season.value}:${inputs.team.value}`}
    <Dropdown data={opponents} name=opponent value=opponent_team_name multiple=true defaultValue={['All Opponents']} title="Opponent" />
    {/key}
  </div>
</details>

```sql team_header
select
    '${inputs.team.value}'                                          as team_name,
    max(team_logo)                                                  as team_logo,
    (select coach_name from superligaen.mart_team_season s
       where s.season = '${inputs.season.value}' and s.team_name = '${inputs.team.value}') as coach_name,
    coalesce(sum(points_earned), 0)::int                           as points,
    sum(case when result='Win'  then 1 else 0 end)::int            as wins,
    sum(case when result='Draw' then 1 else 0 end)::int            as draws,
    sum(case when result='Loss' then 1 else 0 end)::int            as losses,
    coalesce(sum(goals_scored), 0)::int                            as gf,
    coalesce(sum(goals_conceded), 0)::int                          as ga,
    coalesce(sum(goals_scored) - sum(goals_conceded), 0)::int      as gd
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
```

```sql team_kpis
-- Performance metrics are recomputed from match-grain data so they respond to the
-- additional filters, benchmarked against the previous season sliced the same way.
-- Ranking is season-only (it needs the whole league table) and stays unaffected by
-- the additional filters, as does Avg Squad Age.
with cur as (
    select
        count(distinct match_id)                                            as matches,
        round(sum(goals_scored)::double   / nullif(count(distinct match_id), 0), 2) as goals_per_match,
        round(sum(goals_conceded)::double / nullif(count(distinct match_id), 0), 2) as conceded_per_match,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)       as pass_accuracy,
        round(avg(possession_pct), 1)                                       as avg_possession,
        round(100.0 * sum(case when result='Win' then 1 else 0 end) / nullif(count(distinct match_id), 0), 1) as win_rate,
        sum(red_cards)::int                                                 as total_red_cards
    from superligaen.mart_team_match
    where season = '${inputs.season.value}'
      and team_name = '${inputs.team.value}'
      and result in ${inputs.result.value}
      and match_round_number in ${inputs.round.value}
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
),
prev_season as (
    select max(season) as season from superligaen.mart_team_match
    where season < '${inputs.season.value}'
      and team_name = '${inputs.team.value}'
),
prev as (
    select
        round(sum(goals_scored)::double   / nullif(count(distinct match_id), 0), 2) as goals_per_match,
        round(sum(goals_conceded)::double / nullif(count(distinct match_id), 0), 2) as conceded_per_match,
        round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1)       as pass_accuracy,
        round(avg(possession_pct), 1)                                       as avg_possession,
        round(100.0 * sum(case when result='Win' then 1 else 0 end) / nullif(count(distinct match_id), 0), 1) as win_rate,
        sum(red_cards)::int                                                 as total_red_cards
    from superligaen.mart_team_match
    where season = (select season from prev_season)
      and team_name = '${inputs.team.value}'
      and result in ${inputs.result.value}
      and match_round_number in ${inputs.round.value}
      and match_round_type in ${inputs.phase.value}
      and team_side in ${inputs.venue.value}
      and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
),
rank_cur as (
    select season_rank as current_rank
    from superligaen.mart_team_season
    where season = '${inputs.season.value}' and team_name = '${inputs.team.value}'
),
rank_prev as (
    select season_rank as prev_rank
    from superligaen.mart_team_season
    where season = (select season from prev_season) and team_name = '${inputs.team.value}'
)
select
    cur.goals_per_match,
    cur.conceded_per_match,
    cur.pass_accuracy,
    cur.avg_possession,
    cur.win_rate,
    cur.total_red_cards,
    rank_cur.current_rank,
    rank_prev.prev_rank,
    prev.goals_per_match                                                        as prev_goals_per_match,
    prev.conceded_per_match                                                     as prev_conceded_per_match,
    prev.pass_accuracy                                                          as prev_pass_accuracy,
    prev.avg_possession                                                         as prev_avg_possession,
    prev.win_rate                                                               as prev_win_rate,
    prev.total_red_cards                                                        as prev_total_red_cards,
    round(cur.goals_per_match    / nullif(prev.goals_per_match,    0), 2)       as goals_ratio,
    round(cur.conceded_per_match / nullif(prev.conceded_per_match, 0), 2)       as conceded_ratio,
    round(cur.pass_accuracy      / nullif(prev.pass_accuracy,      0), 2)       as pass_ratio,
    round(cur.win_rate           / nullif(prev.win_rate,           0), 2)       as win_rate_ratio,
    round(cur.avg_possession     / nullif(prev.avg_possession,     0), 2)       as possession_ratio
from cur
left join prev on true
left join rank_cur on true
left join rank_prev on true
```

```sql avg_age
with prev_season as (
    select max(season) as season from superligaen.mart_team_season
    where season < '${inputs.season.value}'
)
select
    cur.avg_age,
    prev.avg_age as prev_avg_age
from superligaen.mart_team_season cur
left join superligaen.mart_team_season prev
    on prev.season = (select season from prev_season)
    and prev.team_name = '${inputs.team.value}'
where cur.season = '${inputs.season.value}'
  and cur.team_name = '${inputs.team.value}'
```

```sql goals_per_round
select
    match_round_number  as round,
    goals_scored,
    goals_conceded,
    opponent_team_name  as opponent,
    result
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
order by match_round_number
```

```sql goals_vs_opponent
select
    opponent_team_name                                          as opponent,
    count(distinct match_id)::int                               as matches,
    sum(goals_scored)::int                                      as goals_scored,
    sum(goals_conceded)::int                                    as goals_conceded
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by opponent_team_name
order by goals_scored desc
```

```sql match_results
select
    match_date,
    match_round_name                                                as round,
    team_side                                                       as home_away,
    opponent_team_name                                              as opponent,
    goals_scored                                                    as gf,
    goals_conceded                                                  as ga,
    result,
    case result
        when 'Win'  then '<span style="background:#22c55e;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="background:#eab308;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">D</span>'
        when 'Loss' then '<span style="background:#ef4444;color:white;padding:2px 10px;border-radius:9999px;font-size:12px;font-weight:700;">L</span>'
    end                                                             as result_badge,
    points_earned                                                   as pts,
    possession_pct                                                  as possession,
    shots_on_goal,
    total_shots,
    round(100.0 * passes_accurate / nullif(total_passes, 0), 1)    as pass_accuracy,
    round(100.0 * goals_scored    / nullif(total_shots,   0), 1)    as shot_conv,
    yellow_cards
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
order by match_date desc
```

```sql form_last5
select * from (
    select
        match_date,
        result,
        goals_scored       as gf,
        goals_conceded     as ga,
        opponent_team_name as opponent
    from superligaen.mart_team_match
    where season = '${inputs.season.value}'
      and team_name = '${inputs.team.value}'
      and result in ('Win', 'Draw', 'Loss')
    order by match_date desc
    limit 5
) order by match_date asc
```

```sql home_away_split
select
    team_side                                                            as venue,
    count(distinct match_id)::int                                        as matches,
    sum(case when result='Win'  then 1 else 0 end)::int                  as wins,
    sum(case when result='Draw' then 1 else 0 end)::int                  as draws,
    sum(case when result='Loss' then 1 else 0 end)::int                  as losses,
    sum(points_earned)::int                                              as points,
    round(sum(goals_scored)::double   / count(distinct match_id), 2)     as goals_per_match,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)     as conceded_per_match,
    round(avg(possession_pct), 1)                                        as avg_possession,
    round(100.0 * sum(passes_accurate) / nullif(sum(total_passes), 0), 1) as pass_accuracy
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by team_side
order by venue desc
```

```sql formation_performance
select
    formation,
    count(distinct match_id)::int                                           as matches,
    sum(case when result='Win'  then 1 else 0 end)::int                     as wins,
    sum(case when result='Draw' then 1 else 0 end)::int                     as draws,
    sum(case when result='Loss' then 1 else 0 end)::int                     as losses,
    round(sum(points_earned)::double  / count(distinct match_id), 2)        as points_per_match,
    round(sum(goals_scored)::double   / count(distinct match_id), 2)        as goals_per_match,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)        as conceded_per_match
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by formation
order by points_per_match desc
```

```sql kickoff_performance
select
    period_of_day,
    count(distinct match_id)::int                                           as matches,
    sum(case when result='Win'  then 1 else 0 end)::int                     as wins,
    sum(case when result='Draw' then 1 else 0 end)::int                     as draws,
    sum(case when result='Loss' then 1 else 0 end)::int                     as losses,
    round(sum(points_earned)::double  / count(distinct match_id), 2)        as points_per_match,
    round(sum(goals_scored)::double   / count(distinct match_id), 2)        as goals_per_match,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)        as conceded_per_match
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by period_of_day
order by case period_of_day
    when 'Morning'   then 1
    when 'Noon'      then 2
    when 'Afternoon' then 3
    when 'Evening'   then 4
    when 'Night'     then 5
    else 6
end
```

```sql matchday_performance
select
    day_name,
    count(distinct match_id)::int                                           as matches,
    sum(case when result='Win'  then 1 else 0 end)::int                     as wins,
    sum(case when result='Draw' then 1 else 0 end)::int                     as draws,
    sum(case when result='Loss' then 1 else 0 end)::int                     as losses,
    round(sum(points_earned)::double  / count(distinct match_id), 2)        as points_per_match,
    round(sum(goals_scored)::double   / count(distinct match_id), 2)        as goals_per_match,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)        as conceded_per_match
from superligaen.mart_team_match
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
group by day_name
order by case day_name
    when 'Monday'    then 1
    when 'Tuesday'   then 2
    when 'Wednesday' then 3
    when 'Thursday'  then 4
    when 'Friday'    then 5
    when 'Saturday'  then 6
    when 'Sunday'    then 7
end
```

---

## Team Intelligence

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Season summary for the selected team — points, goal difference, last 5 results, and head-to-head record against each opponent.</p>

{#each team_header as h}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{h.team_logo}" alt="{h.team_name}" class="h-20 w-20 object-contain drop-shadow-xl" onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl md:text-4xl font-extrabold text-white tracking-tight">{h.team_name}</div>
      {#if h.coach_name}
      <div class="text-gray-400 text-sm mt-1">Coach: <span class="text-gray-200 font-semibold">{h.coach_name}</span></div>
      {/if}
      <div class="flex flex-wrap justify-center md:justify-start gap-6 mt-4">
        <div class="text-center"><div class="text-2xl font-black text-white">{h.points}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Points</div></div>
        <div class="text-center"><div class="text-2xl font-black text-green-400">{h.wins}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Wins</div></div>
        <div class="text-center"><div class="text-2xl font-black text-yellow-400">{h.draws}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Draws</div></div>
        <div class="text-center"><div class="text-2xl font-black text-red-400">{h.losses}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Losses</div></div>
        <div class="text-center"><div class="text-2xl font-black text-white">{h.gf}–{h.ga}</div><div class="text-xs text-gray-400 uppercase tracking-widest">Goals</div></div>
        <div class="text-center"><div class="text-2xl font-black {h.gd >= 0 ? 'text-green-400' : 'text-red-400'}">{h.gd > 0 ? '+' : ''}{h.gd}</div><div class="text-xs text-gray-400 uppercase tracking-widest">GD</div></div>
      </div>
    </div>
  </div>
</div>
{/each}

<div class="mb-6">
  <div class="text-sm font-semibold text-gray-500 uppercase tracking-widest mb-3">Last 5 Results</div>
  <div class="flex gap-2 flex-wrap">
    {#each form_last5 as m}
      <div class="relative group">
        <div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-extrabold shadow-md {m.result === 'Win' ? 'bg-green-500 text-white' : m.result === 'Draw' ? 'bg-yellow-400 text-gray-800' : 'bg-red-500 text-white'}">
          {m.result === 'Win' ? 'W' : m.result === 'Draw' ? 'D' : 'L'}
        </div>
        <div class="absolute bottom-11 left-0 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity z-10 pointer-events-none">
          {m.gf}–{m.ga} vs {m.opponent}
        </div>
      </div>
    {/each}
  </div>
</div>

---

## Season Overview

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Key performance indicators for the selected season, each compared against the previous season to show whether the team has improved or declined.</p>

{#each team_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Ranking</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">#{k.current_rank}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_rank != null ? '#' + k.prev_rank : '—'}</span>
      {#if k.prev_rank != null}
      <span class="text-sm font-bold {k.current_rank <= k.prev_rank ? 'text-green-600' : 'text-red-500'}">{k.current_rank <= k.prev_rank ? '▲' : '▼'}</span>
      {/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals Scored / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_goals_per_match ?? '—'}</span>
      <span class="text-sm font-bold {k.goals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.goals_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals Conceded / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.conceded_per_match}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_conceded_per_match ?? '—'}</span>
      <span class="text-sm font-bold {k.conceded_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.conceded_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Win Rate %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.win_rate}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_win_rate != null ? k.prev_win_rate + '%' : '—'}</span>
      {#if k.win_rate_ratio != null}
      <span class="text-sm font-bold {k.win_rate_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.win_rate_ratio >= 1 ? '▲' : '▼'}</span>
      {/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Avg Possession %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.avg_possession}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_avg_possession != null ? k.prev_avg_possession + '%' : '—'}</span>
      <span class="text-sm font-bold {k.possession_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.possession_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.pass_accuracy}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_pass_accuracy != null ? k.prev_pass_accuracy + '%' : '—'}</span>
      <span class="text-sm font-bold {k.pass_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{k.pass_ratio >= 1 ? '▲' : '▼'}</span>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Avg Squad Age</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{avg_age[0]?.avg_age ?? '—'}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {avg_age[0]?.prev_avg_age ?? '—'}</span>
      {#if avg_age[0]?.prev_avg_age != null && avg_age[0]?.avg_age != null}
      <span class="text-sm font-bold {avg_age[0].avg_age >= avg_age[0].prev_avg_age ? 'text-green-600' : 'text-red-500'}">{avg_age[0].avg_age >= avg_age[0].prev_avg_age ? '▲' : '▼'}</span>
      {/if}
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Red Cards</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.total_red_cards}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev season: {k.prev_total_red_cards ?? '—'}</span>
      {#if k.prev_total_red_cards != null}
      <span class="text-sm font-bold {k.total_red_cards >= k.prev_total_red_cards ? 'text-green-600' : 'text-red-500'}">{k.total_red_cards >= k.prev_total_red_cards ? '▲' : '▼'}</span>
      {/if}
    </div>
  </div>

</div>
{/each}

---

## Goals per Round

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Goals scored and conceded per match across the season. Hover a round to see the opponent.</p>

<LineChart
    data={goals_per_round}
    x=round
    y={['goals_scored','goals_conceded']}
    xAxisTitle="Round"
    yAxisTitle="Goals"
    colorPalette={['#3b82f6','#f97316']}
    markers=true
    chartAreaHeight=280
    echartsOptions={{tooltip: {formatter: (function() { const lu = {}; for (const r of goals_per_round) { lu[r.round] = {opponent: r.opponent, result: r.result}; } return function(params) { const round = params[0].value[0]; const info = lu[round] || {}; let out = '<span style="font-weight:600;">Round ' + round + '</span>'; if (info.opponent) out += '<br><span style="font-size:11px;color:#9ca3af;">vs ' + info.opponent + ' · ' + info.result + '</span>'; for (const p of params) { out += '<br>' + p.marker + ' ' + p.seriesName + ': <b>' + p.value[1] + '</b>'; } return out; }; })()}, series: [{markLine: {silent: true, symbol: ['none','none'], label: {show: false}, data: goals_per_round.map(r => ([{coord: [r.round, r.goals_scored]}, {coord: [r.round, r.goals_conceded], lineStyle: {color: r.goals_scored >= r.goals_conceded ? '#3b82f6' : '#f97316', width: 2, opacity: 0.5}}]))}}]}}
/>

## Goals against Opponent

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Total goals scored and conceded against each opponent across all meetings in the selected season.</p>

<BarChart
    data={goals_vs_opponent}
    x=opponent
    y={['goals_scored','goals_conceded']}
    type=grouped
    swapXY=true
    colorPalette={['#3b82f6','#f97316']}
    seriesOptions={{"barGap": "0%"}}
    xAxisTitle="Goals"
    yAxisTitle="Opponent"
    chartAreaHeight=400
    sort=false
/>

---

## Home vs Away

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Results, goals, possession, and pass accuracy split by home and away fixtures.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={home_away_split}
    x=venue
    y={['wins','draws','losses']}
    title="W/D/L Split"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=grouped
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y={['goals_per_match','conceded_per_match']}
    title="Goals Scored vs Conceded per Match"
    colorPalette={['#3b82f6','#f97316']}
    type=grouped
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y=avg_possession
    title="Avg Possession %"
    colorPalette={['#8b5cf6']}
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y=pass_accuracy
    title="Pass Accuracy %"
    colorPalette={['#3b82f6']}
    sort=false
/>

</div>

---

## Formation

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Win/draw/loss record and goals per match broken down by the formation used in each game.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={formation_performance}
    x=formation
    y={['wins','draws','losses']}
    title="W/D/L by Formation"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=stacked
    sort=false
/>

<BarChart
    data={formation_performance}
    x=formation
    y={['goals_per_match','conceded_per_match']}
    title="Goals per Match by Formation"
    colorPalette={['#3b82f6','#f97316']}
    type=grouped
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

</div>

---

## When We Play Best

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Results split by day of the week and time of day to reveal any scheduling patterns in performance.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={matchday_performance}
    x=day_name
    y={['wins','draws','losses']}
    title="W/D/L by Day"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=stacked
    sort=false
/>

<BarChart
    data={kickoff_performance}
    x=period_of_day
    y={['wins','draws','losses']}
    title="W/D/L by Time of Day"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=stacked
    sort=false
/>

</div>

---

## When Goals Happen

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Match events by 15-minute interval — when this team scores and concedes, and when the bench makes its moves. Stoppage time (45+, 90+) counted separately.</p>

```sql team_event_timing
select
    minute_bucket,
    minute_bucket_sort,
    sum(goals_for)      as goals_for,
    sum(goals_against)  as goals_against,
    sum(substitutions)  as substitutions
from superligaen.mart_team_event_timing
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
group by minute_bucket, minute_bucket_sort
order by minute_bucket_sort
```

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={team_event_timing}
    x=minute_bucket
    y={['goals_for','goals_against']}
    title="Goals Scored vs Conceded by Minute"
    xAxisTitle="Match Minute"
    yAxisTitle="Goals"
    colorPalette={['#3b82f6','#f97316']}
    type=grouped
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={team_event_timing}
    x=minute_bucket
    y=substitutions
    title="Substitutions by Minute"
    xAxisTitle="Match Minute"
    yAxisTitle="Substitutions"
    colorPalette={['#8b5cf6']}
    sort=false
/>

</div>

---

## Game State & Comebacks

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">How the season went when things got hard: points rescued after falling behind, and leads that slipped away. "Trailing" means behind at any point in the match.</p>

```sql game_state
select
    count(*) filter (where trailed and result = 'Win')  as comeback_wins,
    coalesce(sum(points_earned) filter (where trailed), 0) as points_from_trailing,
    count(*) filter (where ht_state = 'Behind' and result = 'Win')  as ht_comeback_wins,
    count(*) filter (where led and result = 'Loss')     as leads_lost
from superligaen.mart_team_game_state
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
```

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Comeback Wins</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{game_state[0]?.comeback_wins ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Points From Trailing</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{game_state[0]?.points_from_trailing ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">HT-Deficit Wins</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{game_state[0]?.ht_comeback_wins ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Leads Lost</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{game_state[0]?.leads_lost ?? '—'}</div>
  </div>
</div>

```sql game_state_outcomes
select 'Trailed at Some Point' as game_state, 1 as ord,
    count(*) filter (where trailed and result = 'Win')  as wins,
    count(*) filter (where trailed and result = 'Draw') as draws,
    count(*) filter (where trailed and result = 'Loss') as losses
from superligaen.mart_team_game_state
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
union all
select 'Led at Some Point', 2,
    count(*) filter (where led and result = 'Win'),
    count(*) filter (where led and result = 'Draw'),
    count(*) filter (where led and result = 'Loss')
from superligaen.mart_team_game_state
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
order by ord
```

```sql ht_ft_outcomes
select
    ht_state || ' at HT' as ht_state,
    case ht_state when 'Ahead' then 1 when 'Level' then 2 else 3 end as ord,
    count(*) filter (where result = 'Win')  as wins,
    count(*) filter (where result = 'Draw') as draws,
    count(*) filter (where result = 'Loss') as losses
from superligaen.mart_team_game_state
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
  and ('All Opponents' in ${inputs.opponent.value} OR opponent_team_name in ${inputs.opponent.value})
  and result in ${inputs.result.value}
  and match_round_number in ${inputs.round.value}
  and match_round_type in ${inputs.phase.value}
  and team_side in ${inputs.venue.value}
group by ht_state
order by ord
```

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={game_state_outcomes}
    x=game_state
    y={['wins','draws','losses']}
    title="Outcomes by Game State"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=stacked
    sort=false
/>

<BarChart
    data={ht_ft_outcomes}
    x=ht_state
    y={['wins','draws','losses']}
    title="Half-Time vs Full-Time"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=stacked
    sort=false
/>

</div>

---

## Match Log

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Full match-by-match record for the selected team and season, including possession, pass accuracy, shots on goal, and shot conversion.</p>

<div class="hidden md:block">
<DataTable data={match_results} rows=20 search=true downloadable=true>
    <Column id=match_date    title="Date"        />
    <Column id=round         title="Round"       />
    <Column id=home_away     title="H/A"         align=center />
    <Column id=opponent      title="Opponent"    />
    <Column id=result_badge  title="Result"      contentType=html align=center />
    <Column id=gf            title="GF"          align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=ga            title="GA"          align=center contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=possession    title="Poss %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=pass_accuracy title="Pass Acc %"  fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shots_on_goal title="SoG"         align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shot_conv     title="Shot Conv %"  fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=yellow_cards  title="YC"          align=center contentType=colorscale colorPalette={['white','#eab308']} />
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={match_results} rows=20 search=true>
    <Column id=match_date    title="Date"        />
    <Column id=opponent      title="Opponent"    />
    <Column id=result_badge  title="Result"      contentType=html align=center />
    <Column id=gf            title="GF"          align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=ga            title="GA"          align=center contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=possession    title="Poss %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=pass_accuracy title="Pass Acc %"  fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shots_on_goal title="SoG"         align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shot_conv     title="Shot Conv %"  fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=yellow_cards  title="YC"          align=center contentType=colorscale colorPalette={['white','#eab308']} />
</DataTable>
</div>

```sql last_updated
select * from superligaen.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
