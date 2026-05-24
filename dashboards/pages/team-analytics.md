---
sidebar: never
hide_toc: true
title: Team Intelligence
---

<script>
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

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key teams[0]?.team_name}
<Dropdown data={teams} name=team value=team_name label=team_name defaultValue={teams[0]?.team_name} />
{/key}

```sql team_header
select team_name, team_logo, coach_name, pts as points, matches, wins, draws, losses, gf, ga, gd
from superligaen.mart_team_season
where season = '${inputs.season.value}'
  and team_name = '${inputs.team.value}'
```

```sql team_kpis
with cur as (
    select * from superligaen.mart_team_season
    where season = '${inputs.season.value}'
      and team_name = '${inputs.team.value}'
),
prev_season as (
    select max(season) as season from superligaen.mart_team_season
    where season < '${inputs.season.value}'
),
prev as (
    select * from superligaen.mart_team_season
    where season = (select season from prev_season)
      and team_name = '${inputs.team.value}'
)
select
    cur.goals_per_match,
    cur.conceded_per_match,
    cur.pass_accuracy,
    cur.avg_possession,
    cur.shot_conv,
    cur.yc_per_match,
    cur.win_rate,
    cur.total_red_cards,
    cur.season_rank                                                             as current_rank,
    prev.goals_per_match                                                        as prev_goals_per_match,
    prev.conceded_per_match                                                     as prev_conceded_per_match,
    prev.pass_accuracy                                                          as prev_pass_accuracy,
    prev.avg_possession                                                         as prev_avg_possession,
    prev.shot_conv                                                              as prev_shot_conv,
    prev.yc_per_match                                                           as prev_yc_per_match,
    prev.win_rate                                                               as prev_win_rate,
    prev.total_red_cards                                                        as prev_total_red_cards,
    prev.season_rank                                                            as prev_rank,
    round(cur.goals_per_match    / nullif(prev.goals_per_match,    0), 2)       as goals_ratio,
    round(cur.conceded_per_match / nullif(prev.conceded_per_match, 0), 2)       as conceded_ratio,
    round(cur.pass_accuracy      / nullif(prev.pass_accuracy,      0), 2)       as pass_ratio,
    round(cur.shot_conv          / nullif(prev.shot_conv,          0), 2)       as shot_conv_ratio,
    round(cur.yc_per_match       / nullif(prev.yc_per_match,       0), 2)       as yc_ratio,
    round(cur.win_rate           / nullif(prev.win_rate,           0), 2)       as win_rate_ratio,
    round(cur.avg_possession     / nullif(prev.avg_possession,     0), 2)       as possession_ratio
from cur
left join prev on true
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
  and result in ('Win', 'Draw', 'Loss')
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
  and result in ('Win', 'Draw', 'Loss')
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
  and result in ('Win', 'Draw', 'Loss')
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
select 'Home' as venue, home_matches as matches, home_wins as wins, home_draws as draws,
       home_losses as losses, home_pts as points, home_goals_per_match as goals_per_match,
       home_conceded_per_match as conceded_per_match, home_avg_possession as avg_possession,
       home_pass_accuracy as pass_accuracy
from superligaen.mart_team_season
where season = '${inputs.season.value}' and team_name = '${inputs.team.value}'
union all
select 'Away' as venue, away_matches as matches, away_wins as wins, away_draws as draws,
       away_losses as losses, away_pts as points, away_goals_per_match as goals_per_match,
       away_conceded_per_match as conceded_per_match, away_avg_possession as avg_possession,
       away_pass_accuracy as pass_accuracy
from superligaen.mart_team_season
where season = '${inputs.season.value}' and team_name = '${inputs.team.value}'
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
  and result in ('Win', 'Draw', 'Loss')
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
  and result in ('Win', 'Draw', 'Loss')
group by period_of_day
order by case period_of_day
    when 'Morning'   then 1
    when 'Noon'      then 2
    when 'Evening'   then 3
    when 'Night'     then 4
    else 5
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
  and result in ('Win', 'Draw', 'Loss')
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

{#each team_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Current Ranking</div>
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

<LineChart
    data={goals_per_round}
    x=round
    y={['goals_scored','goals_conceded']}
    xAxisTitle="Round"
    yAxisTitle="Goals"
    colorPalette={['#3b82f6','#f97316']}
    markers=true
    chartAreaHeight=280
    echartsOptions={{series: [{markLine: {silent: true, symbol: ['none','none'], label: {show: false}, data: goals_per_round.map(r => ([{coord: [r.round, r.goals_scored]}, {coord: [r.round, r.goals_conceded], lineStyle: {color: r.goals_scored >= r.goals_conceded ? '#3b82f6' : '#f97316', width: 2, opacity: 0.5}}]))}}]}}
/>

## Goals by Opponent

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

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={home_away_split}
    x=venue
    y={['wins','draws','losses']}
    title="W/D/L Split"
    colorPalette={['#22c55e','#eab308','#ef4444']}
    type=grouped
    sort=false
/>

<BarChart
    data={home_away_split}
    x=venue
    y={['goals_per_match','conceded_per_match']}
    title="Goals Scored vs Conceded per Match"
    colorPalette={['#3b82f6','#f97316']}
    type=grouped
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
    sort=false
/>

</div>

---

## When We Play Best

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

## Match Log

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
