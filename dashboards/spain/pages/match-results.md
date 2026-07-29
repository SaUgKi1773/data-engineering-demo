---
sidebar: never
hide_toc: true
title: Match Results
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from spain.mart_match_results
  group by season
) order by is_current desc, season desc
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a season and round to browse all matches. Click any match in the table to open the full match analysis page.</p>

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

```sql rounds
select distinct
    season || '|' || cast(round_order as integer) as round_key,
    cast(round_order as integer)                      as round_order,
    round_label
from spain.mart_match_results
where season = '${inputs.season.value}'
order by round_order desc
```

{#key `${inputs.season.value}|${rounds.length > 0}`}
<Dropdown data={rounds} name=round value=round_key label=round_label defaultValue={rounds[0]?.round_key} order="round_order desc" />
{/key}

```sql results
select *,
    round(100.0 * total_goals / nullif(total_shots, 0), 1)         as shot_conversion,
    round(100.0 * total_shots_on_goal / nullif(total_shots, 0), 1) as shot_accuracy,
    coalesce(referee_name, '–')                                    as referee,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(round_order as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_name       || '</a>' as match_link,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(round_order as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_short_name || '</a>' as match_short_link
from spain.mart_match_results
where season = '${inputs.season.value}'
  and cast(round_order as integer) = try_cast(split_part('${inputs.round.value ?? -1}', '|', 2) as integer)
order by match_date desc
```

```sql round_title
select any_value(round_display) as label
from spain.mart_match_results
where season = '${inputs.season.value}'
  and cast(round_order as integer) = try_cast(split_part('${inputs.round.value ?? -1}', '|', 2) as integer)
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
    from spain.mart_match_results
    where season = '${inputs.season.value}'
      and cast(round_order as integer) = try_cast(split_part('${inputs.round.value ?? -1}', '|', 2) as integer) - 1
)
select curr.*, prev.*
from curr cross join prev
```

## Match Results — {inputs.season.value} — {round_title[0]?.label}

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
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_conversion_pct ?? '–'}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_shot_conversion_pct != null ? k.prev_shot_conversion_pct + '%' : '—'}</span>
      {#if k.prev_shot_conversion_pct != null}<span class="text-sm font-bold {k.shot_conversion_pct >= k.prev_shot_conversion_pct ? 'text-green-600' : 'text-red-500'}">{k.shot_conversion_pct >= k.prev_shot_conversion_pct ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shot Accuracy %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.shot_accuracy_pct ?? '–'}%</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-xs text-gray-400">Prev round: {k.prev_shot_accuracy_pct != null ? k.prev_shot_accuracy_pct + '%' : '—'}</span>
      {#if k.prev_shot_accuracy_pct != null}<span class="text-sm font-bold {k.shot_accuracy_pct >= k.prev_shot_accuracy_pct ? 'text-green-600' : 'text-red-500'}">{k.shot_accuracy_pct >= k.prev_shot_accuracy_pct ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals / Big Chance</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.goals_per_big_chance ?? '–'}</div>
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


```sql totr
select category, icon, team_name, team_short_name, team_logo,
       opponent_team_short_name, stat_value, stat_label, sort_order
from spain.mart_round_totr
where season = '${inputs.season.value}'
  and cast(round_order as integer) = try_cast(split_part('${inputs.round.value ?? -1}', '|', 2) as integer)
order by sort_order
```

## Teams of the Round

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Standout clubs from this round — one team recognised per category based on the highest single-match figure.</p>

<div class="grid grid-cols-3 md:grid-cols-6 gap-3 mb-6">
  {#each totr as p}
  <div style="background:white;border:1px solid #e5e7eb;border-radius:12px;padding:12px 8px;text-align:center;display:flex;flex-direction:column;align-items:center;height:100%;box-sizing:border-box;">
    <div style="font-size:16px;height:22px;display:flex;align-items:center;justify-content:center;">{p.icon}</div>
    <div style="font-size:10px;font-weight:700;color:#6b7280;height:28px;display:flex;align-items:center;justify-content:center;line-height:1.3;margin-bottom:6px;">{p.category}</div>
    <!-- A category nothing could win keeps its slot as an empty crest-sized
         box; an <img> with no src would draw the browser's broken-image icon. -->
    {#if p.team_logo}
    <img src={p.team_logo} alt={p.team_name}
      style="width:48px;height:48px;object-fit:contain;flex-shrink:0;margin-bottom:8px;"
      onerror="this.style.display='none'" />
    {:else}
    <div style="width:48px;height:48px;flex-shrink:0;margin-bottom:8px;"></div>
    {/if}
    <div style="font-weight:800;font-size:11px;color:#111827;height:16px;line-height:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.team_short_name ?? '–'}</div>
    <div style="font-size:10px;color:#9ca3af;height:14px;line-height:14px;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.opponent_team_short_name ? 'vs ' + p.opponent_team_short_name : ''}</div>
    <div style="font-size:20px;font-weight:900;color:#111827;margin-top:8px;line-height:1;">{p.stat_value ?? '–'}</div>
    <div style="font-size:10px;color:#9ca3af;margin-top:2px;">{p.stat_label}</div>
  </div>
  {/each}
</div>

```sql last_updated
select * from spain.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
