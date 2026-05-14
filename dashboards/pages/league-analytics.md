---
sidebar: never
hide_toc: true
title: League Analysis
---

```sql seasons
select distinct season from superligaen.mart_match_facts
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql current_standings
select
    team_name,
    count(distinct match_id)                          as mp,
    sum(points_earned)                                as pts,
    sum(goals_scored) - sum(goals_conceded)           as gd,
    sum(goals_scored)                                 as gf,
    standings_type                                    as round_group
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name, standings_type
order by
    case standings_type
        when 'Championship Round' then 1
        when 'Relegation Round'   then 2
        else                           3
    end,
    pts desc, gd desc, gf desc
```

```sql points_progression
select match_round_number as round, team_name, cumulative_points, cumulative_gd, cumulative_gf
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by max(cumulative_points) over (partition by team_name) desc, team_name, match_round_number
```

```sql league_kpis
select
    sum(goals_scored)                                                                       as total_goals,
    round(sum(goals_scored)::double / count(distinct match_id), 2)                         as avg_goals_per_match,
    sum(yellow_cards)                                                                       as total_yellow_cards,
    sum(red_cards)                                                                          as total_red_cards
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

```sql team_season_stats
select
    team_name,
    sum(goals_scored)                                                                       as goals_for,
    sum(goals_conceded)                                                                     as goals_against,
    count(distinct match_id) filter (where goals_conceded = 0)                              as clean_sheets,
    round(sum(goals_conceded)::double / count(distinct match_id), 2)                        as avg_goals_conceded,
    round(sum(possession_pct)::double / count(distinct match_id), 1)                        as avg_possession,
    round(sum(corner_kicks)::double / count(distinct match_id), 1)                          as avg_corners,
    sum(yellow_cards)                                                                       as yellow_cards,
    sum(red_cards)                                                                          as red_cards
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name
```

```sql attack_rankings
select
    team_name,
    goals_for
from ${team_season_stats}
order by goals_for desc
```

```sql defence_rankings
select
    team_name,
    goals_against,
    clean_sheets,
    avg_goals_conceded
from ${team_season_stats}
order by clean_sheets desc
```

```sql possession_rankings
select
    team_name,
    avg_possession,
    avg_corners
from ${team_season_stats}
order by avg_possession desc
```

```sql discipline_rankings
select
    team_name,
    yellow_cards,
    red_cards
from ${team_season_stats}
order by yellow_cards desc
```

## {inputs.season.value} — League Analysis

<div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_goals           title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=avg_goals_per_match   title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_yellow_cards    title="Yellow Cards"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={league_kpis} value=total_red_cards       title="Red Cards"          /></div>
</div>

---

## Points Progression

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-start">

<div>

<LineChart
    data={points_progression}
    x=round
    y=cumulative_points
    series=team_name
    xAxisTitle="Round"
    yAxisTitle="Cumulative Points"
    title="Points Progression by Round"
    echartsOptions={{tooltip: {formatter: (function() { const lookup = {}; for (const row of points_progression) { if (!lookup[row.round]) lookup[row.round] = {}; lookup[row.round][row.team_name] = {gd: row.cumulative_gd, gf: row.cumulative_gf}; } return function(params) { const round = params[0].value[0]; const roundData = lookup[round] || {}; const sorted = [...params].sort((a, b) => { if (b.value[1] !== a.value[1]) return b.value[1] - a.value[1]; const pa = roundData[a.seriesName] || {gd: 0, gf: 0}; const pb = roundData[b.seriesName] || {gd: 0, gf: 0}; if (pb.gd !== pa.gd) return pb.gd - pa.gd; return pb.gf - pa.gf; }); let out = '<span style="font-weight:600;">Round ' + round + '</span>'; for (const p of sorted) { out += '<br><span style="font-size:11px;">' + p.marker + ' ' + p.seriesName + '</span><span style="float:right;margin-left:10px;font-size:12px;">' + p.value[1] + '</span>'; } return out; }; })()}}}
    legend=false
    chartAreaHeight=300
/>

</div>

<div>

#### League Table

<DataTable data={current_standings} rows=20>
    <Column id=team_name  title="Team"  />
    <Column id=round_group title="Group" />
    <Column id=mp         title="MP"   align=center />
    <Column id=pts        title="Pts"  align=center contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>

</div>

</div>

---

## Attack — Who's Scoring?

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

## Possession

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

---

## Discipline

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
