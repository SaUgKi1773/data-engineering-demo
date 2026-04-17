---
title: Team Analytics
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql seasons
select distinct season from superligaen.team_analytics_kpis
order by season desc
```

```sql teams
select distinct team_name as team from superligaen.team_analytics_kpis
order by team_name
```

<Dropdown data={seasons} name=season value=season label=season>
    <DropdownOption value=2025 valueLabel="2025"/>
</Dropdown>

<Dropdown data={teams} name=team value=team label=team>
    <DropdownOption value="FC Copenhagen" valueLabel="FC Copenhagen"/>
</Dropdown>

```sql kpis
select * from superligaen.team_analytics_kpis
where team_name = '${inputs.team.value}'
  and season = ${inputs.season.value}
```

```sql form
select * from superligaen.team_analytics_form
where team_name = '${inputs.team.value}'
  and season = ${inputs.season.value}
order by match_date asc
```

```sql home_away
select * from superligaen.team_analytics_home_away
where team_name = '${inputs.team.value}'
  and season = ${inputs.season.value}
order by side desc
```

---

## {inputs.team.value} — Season Overview

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=total_points     title="Points"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=wins             title="Wins"            /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=draws            title="Draws"           /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=losses           title="Losses"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=goals_for        title="Goals Scored"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=goals_against    title="Goals Conceded"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=goal_difference  title="Goal Difference" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=win_rate_pct     title="Win Rate"        fmt=pct0 /></div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_possession       title="Avg Possession"    fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_pass_accuracy    title="Pass Accuracy"     fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=shot_conversion_pct  title="Shot Conversion"   fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=on_target_conversion_pct title="On-Target Conv." fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=total_xg             title="Total xG"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=xg_overperformance   title="xG Overperformance" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=aggression_index     title="Aggression Index"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_saves            title="Avg Saves/Match"   /></div>
</div>

---

## Points Progression

```sql points_trend
select match_date, cumulative_points, result, opponent, gf, ga
from superligaen.team_analytics_form
where team_name = '${inputs.team.value}'
  and season = ${inputs.season.value}
order by match_date asc
```

<LineChart
    data={points_trend}
    x=match_date
    y=cumulative_points
    title="Cumulative Points over Time"
    xAxisTitle="Date"
    yAxisTitle="Points"
    lineColor="#3b82f6"
/>

---

## Form Guide

```sql recent_form
select
    match_date, round, opponent, side,
    gf, ga, result, xg, shots_on_goal, possession, fouls,
    yellow_cards, red_cards
from superligaen.team_analytics_form
where team_name = '${inputs.team.value}'
  and season = ${inputs.season.value}
order by match_date desc
limit 10
```

<DataTable data={recent_form} rows=10>
    <Column id=match_date   title="Date"       />
    <Column id=round        title="Round"      />
    <Column id=opponent     title="Opponent"   />
    <Column id=side         title="Side"       />
    <Column id=gf           title="GF"         />
    <Column id=ga           title="GA"         />
    <Column id=result       title="Result"     />
    <Column id=xg           title="xG"         />
    <Column id=shots_on_goal title="SoG"       />
    <Column id=possession   title="Poss %"     />
    <Column id=fouls        title="Fouls"      />
    <Column id=yellow_cards title="YC"         />
    <Column id=red_cards    title="RC"         />
</DataTable>

---

## Attack

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_xg_per_match      title="xG per Match"        /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_shots_on_goal     title="Shots on Goal/Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_goals_scored      title="Goals Scored/Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=shot_conversion_pct   title="Shot Conversion %"   fmt=pct0 /></div>
</div>

<BarChart
    data={form}
    x=match_date
    y=gf
    title="Goals Scored per Match"
    xAxisTitle="Date"
    yAxisTitle="Goals"
    colorPalette={['#22c55e']}
/>

<BarChart
    data={form}
    x=match_date
    y=xg
    title="xG per Match"
    xAxisTitle="Date"
    yAxisTitle="xG"
    colorPalette={['#3b82f6']}
/>

```sql shot_location
select 'Inside Box' as location, shots_insidebox as shots
from superligaen.team_analytics_kpis
where team_name = '${inputs.team.value}' and season = ${inputs.season.value}
union all
select 'Outside Box', shots_outsidebox
from superligaen.team_analytics_kpis
where team_name = '${inputs.team.value}' and season = ${inputs.season.value}
```

<BarChart
    data={shot_location}
    x=location
    y=shots
    title="Shot Locations — Season Total"
    xAxisTitle="Location"
    yAxisTitle="Shots"
    colorPalette={['#f59e0b', '#ef4444']}
    swapXY=true
/>

---

## Defence

<div class="grid grid-cols-2 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_goals_conceded title="Goals Conceded/Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_saves          title="Saves/Match"          /></div>
</div>

<BarChart
    data={form}
    x=match_date
    y=ga
    title="Goals Conceded per Match"
    xAxisTitle="Date"
    yAxisTitle="Goals Conceded"
    colorPalette={['#ef4444']}
/>

<BarChart
    data={form}
    x=match_date
    y=saves
    title="Goalkeeper Saves per Match"
    xAxisTitle="Date"
    yAxisTitle="Saves"
    colorPalette={['#6366f1']}
/>

---

## Passing & Possession

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_possession     title="Avg Possession %"  fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_pass_accuracy  title="Avg Pass Accuracy" fmt=pct0 /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_corners        title="Corners/Match"               /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_offsides       title="Offsides/Match"              /></div>
</div>

<BarChart
    data={form}
    x=match_date
    y=possession
    title="Possession % per Match"
    xAxisTitle="Date"
    yAxisTitle="Possession %"
    colorPalette={['#14b8a6']}
/>

<BarChart
    data={form}
    x=match_date
    y=pass_accuracy
    title="Pass Accuracy % per Match"
    xAxisTitle="Date"
    yAxisTitle="Pass Accuracy %"
    colorPalette={['#8b5cf6']}
/>

---

## Discipline

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=avg_fouls        title="Fouls/Match"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=yellow_cards     title="Yellow Cards"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=red_cards        title="Red Cards"        /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={kpis} value=aggression_index title="Aggression Index" /></div>
</div>

<BarChart
    data={form}
    x=match_date
    y=fouls
    title="Fouls per Match"
    xAxisTitle="Date"
    yAxisTitle="Fouls"
    colorPalette={['#f97316']}
/>

<BarChart
    data={form}
    x=match_date
    y={['yellow_cards', 'red_cards']}
    title="Cards per Match"
    xAxisTitle="Date"
    yAxisTitle="Cards"
    colorPalette={['#eab308', '#dc2626']}
/>

---

## Home vs Away

<DataTable data={home_away}>
    <Column id=side               title="Side"             />
    <Column id=matches            title="MP"               />
    <Column id=wins               title="W"                />
    <Column id=draws              title="D"                />
    <Column id=losses             title="L"                />
    <Column id=goals_for          title="GF"               />
    <Column id=goals_against      title="GA"               />
    <Column id=win_rate_pct       title="Win %"            />
    <Column id=avg_possession     title="Avg Poss %"       />
    <Column id=avg_shots_on_goal  title="Avg SoG"          />
    <Column id=avg_xg             title="Avg xG"           />
    <Column id=shot_conversion_pct title="Shot Conv %"     />
    <Column id=avg_fouls          title="Avg Fouls"        />
    <Column id=yellow_cards       title="YC"               />
    <Column id=red_cards          title="RC"               />
    <Column id=avg_saves          title="Avg Saves"        />
</DataTable>

```sql home_away_chart
select side, avg_shots_on_goal as "Shots on Goal", avg_xg as "xG", avg_possession / 10 as "Possession / 10", win_rate_pct / 10 as "Win Rate / 10"
from superligaen.team_analytics_home_away
where team_name = '${inputs.team.value}' and season = ${inputs.season.value}
```

<BarChart
    data={home_away_chart}
    x=side
    y={['Shots on Goal', 'xG', 'Possession / 10', 'Win Rate / 10']}
    title="Home vs Away — Key Metrics"
    xAxisTitle="Side"
    swapXY=false
/>
