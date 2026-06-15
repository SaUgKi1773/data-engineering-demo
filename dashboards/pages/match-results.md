---
sidebar: never
hide_toc: true
title: Match Results
---

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_results
  group by season
) order by is_current desc, season desc
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a season and round to browse all matches. Click any match in the table to open the full match analysis page.</p>

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

```sql rounds
select distinct cast(match_round_number as integer) as round_number
from superligaen.mart_match_results
where season = '${inputs.season.value}'
order by 1 desc
```

{#key `${inputs.season.value}|${rounds[0]?.round_number}`}
<Dropdown data={rounds} name=round value=round_number label=round_number defaultValue={rounds[0]?.round_number} order="round_number desc" />
{/key}

```sql results
select *,
    round(100.0 * total_goals / nullif(total_shots, 0), 1)         as shot_conversion,
    round(100.0 * total_shots_on_goal / nullif(total_shots, 0), 1) as shot_accuracy,
    referee_name as referee,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(match_round_number as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_name       || '</a>' as match_link,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(match_round_number as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_short_name || '</a>' as match_short_link
from superligaen.mart_match_results
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) = ${inputs.round.value ?? -1}
order by match_date desc
```

```sql round_kpis
with curr as (
    select
        sum(total_goals)                                                                      as total_goals,
        round(100.0 * sum(total_goals) / nullif(sum(total_shots), 0), 1)                     as shot_conversion_pct,
        round(100.0 * sum(total_shots_on_goal) / nullif(sum(total_shots), 0), 1)             as shot_accuracy_pct,
        round(sum(total_goals)::double / nullif(sum(total_big_chances), 0), 2)               as goals_per_big_chance
    from ${results}
),
prev as (
    select
        sum(total_goals)                                                                      as prev_total_goals,
        round(100.0 * sum(total_goals) / nullif(sum(total_shots), 0), 1)                     as prev_shot_conversion_pct,
        round(100.0 * sum(total_shots_on_goal) / nullif(sum(total_shots), 0), 1)             as prev_shot_accuracy_pct,
        round(sum(total_goals)::double / nullif(sum(total_big_chances), 0), 2)               as prev_goals_per_big_chance
    from superligaen.mart_match_results
    where season = '${inputs.season.value}'
      and cast(match_round_number as integer) = ${(inputs.round.value ?? 1) - 1}
)
select curr.*, prev.*
from curr cross join prev
```

## Match Results — {inputs.season.value} — Round {inputs.round.value}

{#each round_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals Scored</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.total_goals}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_total_goals ?? '—'}</span>
      {#if k.prev_total_goals != null}<span class="text-sm font-bold {k.total_goals >= k.prev_total_goals ? 'text-green-600' : 'text-red-500'}">{k.total_goals >= k.prev_total_goals ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Conversion %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_conversion_pct}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_shot_conversion_pct != null ? k.prev_shot_conversion_pct + '%' : '—'}</span>
      {#if k.prev_shot_conversion_pct != null}<span class="text-sm font-bold {k.shot_conversion_pct >= k.prev_shot_conversion_pct ? 'text-green-600' : 'text-red-500'}">{k.shot_conversion_pct >= k.prev_shot_conversion_pct ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_accuracy_pct}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_shot_accuracy_pct != null ? k.prev_shot_accuracy_pct + '%' : '—'}</span>
      {#if k.prev_shot_accuracy_pct != null}<span class="text-sm font-bold {k.shot_accuracy_pct >= k.prev_shot_accuracy_pct ? 'text-green-600' : 'text-red-500'}">{k.shot_accuracy_pct >= k.prev_shot_accuracy_pct ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals / Big Chance</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_big_chance}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_goals_per_big_chance ?? '—'}</span>
      {#if k.prev_goals_per_big_chance != null}<span class="text-sm font-bold {k.goals_per_big_chance >= k.prev_goals_per_big_chance ? 'text-green-600' : 'text-red-500'}">{k.goals_per_big_chance >= k.prev_goals_per_big_chance ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
</div>
{/each}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Click on a match to open the detailed analysis page.</p>

<div class="block md:hidden">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_short_link    title="Match"          contentType=html wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=shot_conversion      title="Shot Conv %"    fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=shot_accuracy        title="Shot Acc %"     fmt='0.0"%"' contentType=colorscale colorPalette={['white','#0ea5e9']} align=center />
    <Column id=total_big_chances    title="Big Chances"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_red_cards      title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_link          title="Match"          contentType=html wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=shot_conversion      title="Shot Conv %"    fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=shot_accuracy        title="Shot Acc %"     fmt='0.0"%"' contentType=colorscale colorPalette={['white','#0ea5e9']} align=center />
    <Column id=total_big_chances    title="Big Chances"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_red_cards      title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>


```sql potw
select category, icon, player_name, player_photo, team_name, team_logo,
       stat_value, stat_label, sort_order
from superligaen.mart_round_potw
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) = ${inputs.round.value ?? -1}
order by sort_order
```

{#if potw.length > 0}
## Players of the Week

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Standout performers from this round — one player recognised per category based on the highest single-match stat.</p>

<div class="grid grid-cols-3 md:grid-cols-6 gap-3 mb-6">
  {#each potw as p}
  <div style="background:white;border:1px solid #e5e7eb;border-radius:12px;padding:12px 8px;text-align:center;display:flex;flex-direction:column;align-items:center;">
    <div style="font-size:16px;height:22px;display:flex;align-items:center;justify-content:center;">{p.icon}</div>
    <div style="font-size:10px;font-weight:700;color:#6b7280;height:28px;display:flex;align-items:center;justify-content:center;line-height:1.3;margin-bottom:6px;">{p.category}</div>
    <img src={p.player_photo} alt={p.player_name}
      style="width:48px;height:48px;border-radius:50%;object-fit:cover;flex-shrink:0;margin-bottom:8px;"
      onerror="this.style.display='none'" />
    <div style="font-weight:800;font-size:11px;color:#111827;height:16px;line-height:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.player_name}</div>
    <div style="font-size:10px;color:#9ca3af;height:14px;line-height:14px;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.team_name}</div>
    <div style="font-size:20px;font-weight:900;color:#111827;margin-top:8px;line-height:1;">{p.stat_value}</div>
    <div style="font-size:10px;color:#9ca3af;margin-top:2px;">{p.stat_label}</div>
  </div>
  {/each}
</div>
{/if}
