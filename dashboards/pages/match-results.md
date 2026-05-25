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
    referee_name as referee,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(match_round_number as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_name       || '</a>' as match_link,
    '<a href="/match-analysis?match=' || cast(match_id as varchar) || '&season=' || season || '&round=' || cast(cast(match_round_number as integer) as varchar) || '" style="color:#2563eb;font-weight:600;text-decoration:none;">' || match_short_name || '</a>' as match_short_link
from superligaen.mart_match_results
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) = ${inputs.round.value ?? -1}
order by match_date desc
```

```sql round_kpis
select
    sum(total_goals)                                                                        as total_goals,
    round(sum(total_goals)::double / count(distinct match_id), 2)                          as avg_goals_per_match,
    round(sum(total_shots_on_goal)::double / count(distinct match_id), 1)                  as avg_shots_on_goal,
    round(sum(total_goals)::double / nullif(sum(total_big_chances), 0), 2)                   as goals_per_big_chance
from ${results}
```

## Match Results — {inputs.season.value} — Round {inputs.round.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_goals          title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_goals_per_match   title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_shots_on_goal     title="Avg Shots on Goal / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=goals_per_big_chance   title="Goals / Big Chance"  fmt="0.00" /></div>
</div>

<div class="block md:hidden">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_short_link    title="Match"          contentType=html wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Ch."        contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_link          title="Match"          contentType=html wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Chances"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
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
