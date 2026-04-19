---
sidebar: never
hide_toc: true
title: Referee Analysis
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql seasons
select distinct season from superligaen.referee_analytics
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql season_stats
select * from superligaen.referee_analytics
where season = '${inputs.season.value}'
order by matches_managed desc
```

```sql season_totals
select
    count(distinct referee_name)                        as total_referees,
    sum(matches_managed)                                as total_match_slots,
    round(avg(avg_yellows_per_match), 2)                as league_avg_yellows,
    round(avg(avg_reds_per_match), 3)                   as league_avg_reds,
    round(avg(avg_fouls_per_match), 1)                  as league_avg_fouls
from superligaen.referee_analytics
where season = '${inputs.season.value}'
```

## Referee Analysis — {inputs.season.value}

<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_totals} value=total_referees      title="Referees Active"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_totals} value=league_avg_yellows  title="Avg YC / Match"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_totals} value=league_avg_reds     title="Avg RC / Match"     /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={season_totals} value=league_avg_fouls    title="Avg Fouls / Match"  /></div>
</div>

---

## Season Leaderboard

<DataTable data={season_stats} rows=20>
    <Column id=referee_name         title="Referee"             wrap=true />
    <Column id=matches_managed      title="Games"               contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=total_yellow_cards   title="Yellow Cards"        contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards      title="Red Cards"           contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=total_fouls          title="Total Fouls"         contentType=colorscale colorPalette={['white','#f97316']} align=center />
    <Column id=avg_yellows_per_match title="Avg YC / Match"     contentType=colorscale colorPalette={['white','#eab308']} />
    <Column id=avg_reds_per_match    title="Avg RC / Match"     contentType=colorscale colorPalette={['white','#ef4444']} />
    <Column id=avg_fouls_per_match   title="Avg Fouls / Match"  contentType=bar        colorPalette={['#f97316']} />
    <Column id=card_severity_index   title="Card Severity"      contentType=colorscale colorPalette={['white','#dc2626']} />
</DataTable>

---

## Cards per Match — All Referees

<BarChart
    data={season_stats}
    x=referee_name
    y={['avg_yellows_per_match', 'avg_reds_per_match']}
    title="Average Cards per Match — {inputs.season.value}"
    xAxisTitle="Referee"
    yAxisTitle="Cards per Match"
    colorPalette={['#eab308','#ef4444']}
    swapXY=true
/>

---

## Fouls Called per Match

<BarChart
    data={season_stats}
    x=referee_name
    y=avg_fouls_per_match
    title="Average Fouls per Match — {inputs.season.value}"
    xAxisTitle="Referee"
    yAxisTitle="Fouls per Match"
    colorPalette={['#f97316']}
    swapXY=true
/>

---

## Referee Deep Dive

<Dropdown data={season_stats} name=referee value=referee_name label=referee_name />

```sql referee_team_exposure
select team_name, matches
from superligaen.referee_team_exposure
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
order by matches desc
```

```sql referee_match_log
select match_date, round, match_name, score, yellow_cards, red_cards, total_fouls
from superligaen.referee_match_log
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
order by match_date desc
```

```sql referee_kpis
select * from superligaen.referee_analytics
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
```

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6 mt-4">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={referee_kpis} value=matches_managed       title="Games"              /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={referee_kpis} value=total_yellow_cards    title="Yellow Cards"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={referee_kpis} value=total_red_cards       title="Red Cards"          /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={referee_kpis} value=avg_fouls_per_match   title="Avg Fouls / Match"  /></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

### Team Exposure

<BarChart
    data={referee_team_exposure}
    x=team_name
    y=matches
    title="Matches per Team — {inputs.referee.value}"
    xAxisTitle="Team"
    yAxisTitle="Matches"
    colorPalette={['#6366f1']}
    swapXY=true
/>

</div>

<div>

### Match Log

<DataTable data={referee_match_log} rows=10>
    <Column id=match_date    title="Date"   />
    <Column id=round         title="Round"  />
    <Column id=match_name    title="Match"  wrap=true />
    <Column id=score         title="Score"  align=center />
    <Column id=yellow_cards  title="YC"     contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards     title="RC"     contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=total_fouls   title="Fouls"  contentType=bar colorPalette={['#f97316']} />
</DataTable>

</div>

</div>
