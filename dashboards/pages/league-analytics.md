---
sidebar: never
hide_toc: true
title: League Analysis
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql seasons
select distinct season from superligaen.team_analytics_kpis
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql league_table
select
    row_number() over (order by total_points desc, goal_difference desc, goals_for desc) as pos,
    team_name,
    matches_played  as mp,
    wins            as w,
    draws           as d,
    losses          as l,
    goals_for       as gf,
    goals_against   as ga,
    goal_difference as gd,
    total_points    as pts,
    win_rate_pct,
    total_xg,
    xg_overperformance
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by pos
```

```sql league_kpis
select
    sum(goals_for)                                                          as total_goals,
    round(sum(goals_for)::double / (sum(matches_played) / 2), 2)           as avg_goals_per_match,
    round(avg(shot_conversion_pct), 1)                                     as avg_shot_conversion,
    sum(yellow_cards)                                                       as total_yellow_cards,
    sum(red_cards)                                                          as total_red_cards
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
```

```sql attack_rankings
select
    team_name,
    goals_for,
    total_xg,
    xg_overperformance,
    avg_shots_on_goal,
    shot_conversion_pct,
    on_target_conversion_pct
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by goals_for desc
```

```sql defence_rankings
select
    team_name,
    goals_against,
    clean_sheets,
    avg_saves,
    avg_goals_conceded
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by clean_sheets desc
```

```sql possession_rankings
select
    team_name,
    avg_possession,
    avg_pass_accuracy,
    avg_corners,
    avg_offsides
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by avg_possession desc
```

```sql discipline_rankings
select
    team_name,
    yellow_cards,
    red_cards,
    avg_fouls,
    aggression_index
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by aggression_index desc
```

```sql xg_vs_goals
select
    team_name,
    goals_for,
    round(total_xg, 2) as expected_goals,
    xg_overperformance
from superligaen.team_analytics_kpis
where season = '${inputs.season.value}'
order by goals_for desc
```

## {inputs.season.value} — League Analysis

<div class="grid grid-cols-2 md:grid-cols-5 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_goals           title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=avg_goals_per_match   title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=avg_shot_conversion   title="Shot Conversion %"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_yellow_cards    title="Yellow Cards"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_red_cards       title="Red Cards"          /></div>
</div>

---

## League Table

<DataTable data={league_table} rows=20>
    <Column id=pos              title="#"            align=center />
    <Column id=team_name        title="Team"         />
    <Column id=mp               title="MP"           align=center />
    <Column id=w                title="W"            align=center />
    <Column id=d                title="D"            align=center />
    <Column id=l                title="L"            align=center />
    <Column id=gf               title="GF"           align=center />
    <Column id=ga               title="GA"           align=center />
    <Column id=gd               title="GD"           contentType=delta align=center />
    <Column id=pts              title="Pts"          contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=win_rate_pct     title="Win %"        contentType=colorscale colorPalette={['white','#22c55e']} fmt='0.0"%"' />
    <Column id=total_xg         title="xG"           contentType=colorscale colorPalette={['white','#6366f1']} />
    <Column id=xg_overperformance title="xG OP"      contentType=delta />
</DataTable>

---

## Attack — Who's Scoring?

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<BarChart
    data={attack_rankings}
    x=team_name
    y=goals_for
    title="Goals Scored"
    xAxisTitle="Team"
    yAxisTitle="Goals"
    colorPalette={['#22c55e']}
    swapXY=true
/>

</div>

<div>

<BarChart
    data={attack_rankings}
    x=team_name
    y=shot_conversion_pct
    title="Shot Conversion %"
    xAxisTitle="Team"
    yAxisTitle="Conversion %"
    colorPalette={['#f59e0b']}
    swapXY=true
/>

</div>

</div>

### Goals vs Expected Goals

<BarChart
    data={xg_vs_goals}
    x=team_name
    y={['goals_for', 'expected_goals']}
    title="Goals Scored vs xG — Overperformers & Underperformers"
    xAxisTitle="Team"
    yAxisTitle="Goals / xG"
    colorPalette={['#22c55e','#6366f1']}
    swapXY=true
/>

---

## Defence — Who's Keeping Clean Sheets?

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<BarChart
    data={defence_rankings}
    x=team_name
    y=clean_sheets
    title="Clean Sheets"
    xAxisTitle="Team"
    yAxisTitle="Clean Sheets"
    colorPalette={['#14b8a6']}
    swapXY=true
/>

</div>

<div>

<BarChart
    data={defence_rankings}
    x=team_name
    y=goals_against
    title="Goals Conceded"
    xAxisTitle="Team"
    yAxisTitle="Goals Conceded"
    colorPalette={['#ef4444']}
    swapXY=true
/>

</div>

</div>

---

## Possession & Passing

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

<BarChart
    data={possession_rankings}
    x=team_name
    y=avg_possession
    title="Average Possession %"
    xAxisTitle="Team"
    yAxisTitle="Possession %"
    colorPalette={['#8b5cf6']}
    swapXY=true
/>

</div>

<div>

<BarChart
    data={possession_rankings}
    x=team_name
    y=avg_pass_accuracy
    title="Average Pass Accuracy %"
    xAxisTitle="Team"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#0ea5e9']}
    swapXY=true
/>

</div>

</div>

---

## Discipline

<BarChart
    data={discipline_rankings}
    x=team_name
    y=aggression_index
    title="Aggression Index — Fouls + Cards Weighted"
    xAxisTitle="Team"
    yAxisTitle="Aggression Index"
    colorPalette={['#f97316']}
    swapXY=true
/>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">

<div>

<BarChart
    data={discipline_rankings}
    x=team_name
    y=yellow_cards
    title="Yellow Cards"
    xAxisTitle="Team"
    yAxisTitle="Yellow Cards"
    colorPalette={['#eab308']}
    swapXY=true
/>

</div>

<div>

<BarChart
    data={discipline_rankings}
    x=team_name
    y=red_cards
    title="Red Cards"
    xAxisTitle="Team"
    yAxisTitle="Red Cards"
    colorPalette={['#dc2626']}
    swapXY=true
/>

</div>

</div>
