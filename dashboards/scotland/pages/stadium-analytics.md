---
sidebar: never
hide_toc: true
title: Stadium Intelligence
---

```sql season_options
select distinct season
from scotland.mart_stadium_season
order by season desc
```

```sql stadiums
select stadium_name from (
  select 'All Stadiums' as stadium_name, 0 as ord
  union all
  select distinct stadium_name, 1 as ord
  from scotland.mart_stadium_season
  where season = '${inputs.season.value}'
) order by ord, stadium_name
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a season to explore stadium and surface data — fortress rankings, home win rates, and how grass vs. artificial turf affects the way the game is played.</p>

<div class="flex flex-wrap gap-3 items-end mb-4">
  {#key season_options[0]?.season}
  <Dropdown data={season_options} name=season value=season label=season order="season desc" defaultValue={season_options[0]?.season} title="Season" />
  {/key}
  {#key inputs.season.value}
  <Dropdown data={stadiums} name=stadium value=stadium_name multiple=true defaultValue={['All Stadiums']} title="Stadium" />
  {/key}
</div>

```sql stadium_stats
select *
from scotland.mart_stadium_season
where season = '${inputs.season.value}'
  and ('All Stadiums' in ${inputs.stadium.value} OR stadium_name in ${inputs.stadium.value})
order by home_win_pct desc
```

```sql surface_analysis
select *
from scotland.mart_surface_season
where season = '${inputs.season.value}'
```

```sql fortress_ranking
select
    *,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || home_team       || '</span></div>' as home_team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || home_team_short || '</span></div>' as home_team_col_mobile
from scotland.mart_stadium_season
where season = '${inputs.season.value}'
  and ('All Stadiums' in ${inputs.stadium.value} OR stadium_name in ${inputs.stadium.value})
order by home_win_pct desc
```

```sql fortress_podium
select * from ${fortress_ranking} limit 3
```

```sql stadium_kpis
with s as (
    select distinct stadium_name, stadium_capacity, total_goals
    from scotland.mart_stadium_season
    where season = '${inputs.season.value}'
      and ('All Stadiums' in ${inputs.stadium.value} OR stadium_name in ${inputs.stadium.value})
)
select
    count(*)                                     as total_stadiums,
    sum(stadium_capacity)                        as total_capacity,
    arg_max(stadium_name, stadium_capacity)      as max_cap_stadium,
    max(stadium_capacity)                        as max_capacity,
    arg_min(stadium_name, stadium_capacity)      as min_cap_stadium,
    min(stadium_capacity)                        as min_capacity,
    sum(total_goals)                             as total_goals,
    arg_max(stadium_name, total_goals)           as top_goals_stadium,
    max(total_goals)                             as top_goals,
    arg_min(stadium_name, total_goals)           as low_goals_stadium,
    min(total_goals)                             as low_goals
from s
```

```sql surface_breakdown
with s as (
    select distinct stadium_name, stadium_surface
    from scotland.mart_stadium_season
    where season = '${inputs.season.value}'
      and ('All Stadiums' in ${inputs.stadium.value} OR stadium_name in ${inputs.stadium.value})
)
select
    case
        when stadium_surface ilike '%grass%' or stadium_surface ilike '%natural%' then 'Grass'
        when stadium_surface ilike '%artif%' or stadium_surface ilike '%turf%'    then 'Artificial'
        else 'Other'
    end                                          as surface,
    count(*)                                     as n
from s
group by 1
order by n desc
```

---

## Stadium Intelligence — {inputs.season.value}

<div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6 items-stretch">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Stadiums</div>
    <div class="text-4xl font-black text-gray-900 leading-none text-center">{stadium_kpis[0]?.total_stadiums ?? '—'}</div>
    <div class="mt-3 flex items-center justify-center gap-3" style="min-height:64px;">
      <div style="width:56px;height:56px;border-radius:50%;flex-shrink:0;background:conic-gradient({(function(){ const arr = surface_breakdown ?? []; const t = arr.reduce((a, d) => a + d.n, 0) || 1; let acc = 0; return arr.map(d => { const col = d.surface === 'Grass' ? '#22c55e' : d.surface === 'Artificial' ? '#f59e0b' : '#6366f1'; const s = (acc / t * 100).toFixed(2); acc += d.n; const e = (acc / t * 100).toFixed(2); return col + ' ' + s + '% ' + e + '%'; }).join(', '); })()});">
        <div style="width:34px;height:34px;background:#fff;border-radius:50%;margin:11px;"></div>
      </div>
      <div class="text-xs text-gray-500 flex flex-col gap-1">
        {#each surface_breakdown as sf}
        <span class="inline-flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-full" style="background:{sf.surface === 'Grass' ? '#22c55e' : sf.surface === 'Artificial' ? '#f59e0b' : '#6366f1'}"></span>
          {sf.surface} <span class="font-semibold text-gray-700">{sf.n}</span>
        </span>
        {/each}
      </div>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Total Capacity</div>
    <div class="text-4xl font-black text-gray-900 leading-none text-center">{stadium_kpis[0]?.total_capacity != null ? stadium_kpis[0].total_capacity.toLocaleString('en-US') : '—'}</div>
    <div class="mt-3 text-xs text-gray-500 flex flex-col justify-center gap-1" style="min-height:64px;">
      <div class="flex items-center justify-between gap-2">
        <span><span class="text-green-600 font-bold">▲</span> Largest: <span class="font-semibold text-gray-700">{stadium_kpis[0]?.max_cap_stadium ?? '—'}</span></span>
        <span class="font-semibold text-gray-700 whitespace-nowrap">{stadium_kpis[0]?.max_capacity != null ? stadium_kpis[0].max_capacity.toLocaleString('en-US') : '—'}</span>
      </div>
      <div class="flex items-center justify-between gap-2">
        <span><span class="text-red-500 font-bold">▼</span> Smallest: <span class="font-semibold text-gray-700">{stadium_kpis[0]?.min_cap_stadium ?? '—'}</span></span>
        <span class="font-semibold text-gray-700 whitespace-nowrap">{stadium_kpis[0]?.min_capacity != null ? stadium_kpis[0].min_capacity.toLocaleString('en-US') : '—'}</span>
      </div>
    </div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Goals Scored</div>
    <div class="text-4xl font-black text-gray-900 leading-none text-center">{stadium_kpis[0]?.total_goals != null ? stadium_kpis[0].total_goals.toLocaleString('en-US') : '—'}</div>
    <div class="mt-3 text-xs text-gray-500 flex flex-col justify-center gap-1" style="min-height:64px;">
      <div class="flex items-center justify-between gap-2">
        <span><span class="text-green-600 font-bold">▲</span> Most: <span class="font-semibold text-gray-700">{stadium_kpis[0]?.top_goals_stadium ?? '—'}</span></span>
        <span class="font-semibold text-gray-700 whitespace-nowrap">{stadium_kpis[0]?.top_goals ?? '—'}</span>
      </div>
      <div class="flex items-center justify-between gap-2">
        <span><span class="text-red-500 font-bold">▼</span> Fewest: <span class="font-semibold text-gray-700">{stadium_kpis[0]?.low_goals_stadium ?? '—'}</span></span>
        <span class="font-semibold text-gray-700 whitespace-nowrap">{stadium_kpis[0]?.low_goals ?? '—'}</span>
      </div>
    </div>
  </div>

</div>

---

## Stadium Map

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Bubble size = total goals scored. Color = playing surface type.</p>

<BubbleMap
    data={stadium_stats}
    lat=lat
    long=lon
    size=total_goals_scaled
    value=stadium_surface
    pointName=stadium_name
    tooltipType=click
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    legendType=categorical
    legendTitle="Stadium Surface"
    title="Premiership Stadiums — {inputs.season.value}"
    tooltip={[{id: 'stadium_name', showColumnName: false, valueClass: 'font-bold text-sm'}, {id: 'stadium_surface'}, {id: 'total_goals'}, {id: 'goals_per_match'}]}
/>

---

## Top 3 Fortress Stadiums

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The three venues where the home side wins most often — home win %, wins, and total home matches played.</p>

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
  {#each fortress_podium as s, i}
    <div class="rounded-2xl border p-5 shadow-md relative
      {i === 0 ? 'border-amber-300 bg-gradient-to-b from-amber-50 to-yellow-100' :
       i === 1 ? 'border-gray-300 bg-gradient-to-b from-gray-50 to-gray-100' :
       'border-orange-200 bg-gradient-to-b from-orange-50 to-amber-50'}">
      <div class="text-2xl mb-3">{i === 0 ? '🥇' : i === 1 ? '🥈' : '🥉'}</div>
      <div class="flex items-center gap-3 mb-4">
        <img src="{s.team_logo}" alt="{s.home_team}" class="h-10 w-10 object-contain drop-shadow" onerror="this.style.display='none'" />
        <div>
          <div class="font-extrabold text-gray-800 text-sm leading-tight">{s.stadium_name}</div>
          <div class="text-xs text-gray-400">{s.home_team}</div>
        </div>
      </div>
      <div class="flex justify-around">
        <div class="text-center">
          <div class="text-2xl font-black text-green-600">{s.home_win_pct}%</div>
          <div class="text-xs text-gray-400 mt-1">Home Win</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-black text-gray-700">{s.home_wins}</div>
          <div class="text-xs text-gray-400 mt-1">Wins</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-black text-gray-500">{s.home_matches}</div>
          <div class="text-xs text-gray-400 mt-1">Home MP</div>
        </div>
      </div>
      <div class="mt-3 text-center text-xs text-gray-400">{s.stadium_surface} · Cap. {s.stadium_capacity}</div>
    </div>
  {/each}
</div>

---

## Full Fortress Ranking

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Home record at each stadium. A true fortress keeps opponents at bay.</p>

<BarChart
    data={fortress_ranking}
    x=stadium_name
    y=home_win_pct
    title="Home Win Rate by Stadium — {inputs.season.value}"
    yAxisTitle="Home Win %"
    yFmt='0.0'
    sort=true
    swapXY=true
    colorPalette={['#3b82f6']}
/>

<div class="hidden md:block mt-4">
<DataTable data={fortress_ranking} rows=20>
    <Column id=home_team_col            title="Home Team"               contentType=html />
    <Column id=stadium_name             title="Stadium"                 wrap=true />
    <Column id=stadium_capacity         title="Capacity"                align=center />
    <Column id=home_win_pct             title="Win %"                   fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=home_wins                title="W"                       align=center />
    <Column id=home_draws               title="D"                       align=center />
    <Column id=home_losses              title="L"                       align=center />
    <Column id=goals_scored_per_match   title="Goals Scored/Match"      />
    <Column id=goals_conceded_per_match title="Goals Conceded/Match"    />
</DataTable>
</div>
<div class="block md:hidden mt-4">
<DataTable data={fortress_ranking} rows=20>
    <Column id=home_team_col_mobile     title="Home Team"               contentType=html width="max-content" />
    <Column id=stadium_name             title="Stadium"                 wrap=true />
    <Column id=stadium_capacity         title="Capacity"                align=center />
    <Column id=home_win_pct             title="Win %"                   fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=home_wins                title="W"                       align=center />
    <Column id=home_draws               title="D"                       align=center />
    <Column id=home_losses              title="L"                       align=center />
    <Column id=goals_scored_per_match   title="Goals Scored/Match"      />
    <Column id=goals_conceded_per_match title="Goals Conceded/Match"    />
</DataTable>
</div>

---

## Surface Analysis: Grass vs Artificial Turf

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">How does the playing surface shape the way football is played?</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=pass_accuracy
    title="Pass Accuracy % by Surface"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    sort=false
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=cross_accuracy
    title="Cross Accuracy % by Surface"
    yAxisTitle="Cross Accuracy %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    sort=false
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=shot_conversion
    title="Shot Conversion % by Surface"
    yAxisTitle="Shot Conversion %"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    sort=false
/>

<BarChart
    data={surface_analysis}
    x=stadium_surface
    y=fouls_per_match
    title="Fouls per Match by Surface"
    yAxisTitle="Fouls / Match"
    colorPalette={['#22c55e','#6366f1','#f59e0b']}
    sort=false
/>

</div>

<DataTable data={surface_analysis}>
    <Column id=stadium_surface  title="Surface"          />
    <Column id=matches          title="Matches"          align=center />
    <Column id=pass_accuracy    title="Pass Acc %"       fmt='0.0"%"' contentType=colorscale colorPalette={['white','#8b5cf6']} />
    <Column id=cross_accuracy   title="Cross Acc %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=shot_conversion  title="Shot Conv %"      fmt='0.0"%"' contentType=colorscale colorPalette={['white','#22c55e']} />
    <Column id=fouls_per_match  title="Fouls/Match"       contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=goals_per_match  title="Goals/Match"      fmt='0.00'   contentType=colorscale colorPalette={['white','#f59e0b']} />
</DataTable>
