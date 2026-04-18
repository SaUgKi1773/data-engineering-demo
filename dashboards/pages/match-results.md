---
sidebar: never
hide_toc: true
title: Match Results
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql seasons
select distinct season from superligaen.match_results_by_match
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season>
    <DropdownOption value=2025 valueLabel="2025"/>
</Dropdown>

```sql results
select
    match_date, round, match_name, score,
    total_goals, total_shots_on_goal, total_xg,
    total_yellow_cards, total_red_cards, total_corners
from superligaen.match_results_by_match
where season = ${inputs.season.value}
order by match_date desc
```

```sql season_kpis
select
    count(*)                            as total_matches,
    sum(total_goals)                    as total_goals,
    round(avg(total_goals), 2)          as avg_goals_per_match,
    round(avg(total_xg), 2)             as avg_xg_per_match,
    sum(total_yellow_cards)             as total_yellow_cards,
    sum(total_red_cards)                as total_red_cards,
    round(avg(total_shots_on_goal), 1)  as avg_shots_on_goal
from superligaen.match_results_by_match
where season = ${inputs.season.value}
```

```sql goals_over_time
select
    match_round_number,
    sum(total_goals) as goals,
    round(sum(total_xg::double), 2) as xg
from superligaen.match_results_by_match
where season = ${inputs.season.value}
group by match_round_number
order by match_round_number asc
```

---

## Season {inputs.season.value} at a Glance

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_matches       title="Matches Played"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_goals          title="Goals Scored"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=avg_goals_per_match  title="Avg Goals / Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=avg_xg_per_match     title="Avg xG / Match"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=avg_shots_on_goal    title="Avg Shots on Goal" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_yellow_cards   title="Yellow Cards"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_kpis} value=total_red_cards      title="Red Cards"         /></div>
</div>

---

## Goals & xG Over the Season

<LineChart
    data={goals_over_time}
    x=match_round_number
    y={['goals','xg']}
    title="Goals vs xG — {inputs.season.value}"
    xAxisTitle="Round"
    yAxisTitle="Goals"
    colorPalette={['#22c55e','#3b82f6']}
/>

---

## Match Results — {inputs.season.value}

<DataTable data={results} rows=20 search=true>
    <Column id=match_date          title="Date"           />
    <Column id=round               title="Round"          />
    <Column id=match_name          title="Match"          wrap=true />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots_on_goal title="Shots on Goal"  contentType=bar       colorPalette={['#6366f1']} />
    <Column id=total_xg            title="xG"             contentType=colorscale colorPalette={['white','#3b82f6']} />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=total_corners       title="Corners"        contentType=colorscale colorPalette={['white','#a855f7']} align=center />
</DataTable>

