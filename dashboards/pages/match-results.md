---
sidebar: never
hide_toc: true
title: Match Results
---

```sql seasons
select distinct season from superligaen.match_results_by_match
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql rounds
select distinct CAST(match_round_number AS INTEGER) as round_number
from superligaen.match_results_by_match
where season = '${inputs.season.value}'
order by 1 desc
```

{#key `${inputs.season.value}|${rounds[0]?.round_number}`}
<Dropdown data={rounds} name=round value=round_number label=round_number multiple=true defaultValue={[rounds[0]?.round_number]} order="round_number desc" />
{/key}

```sql results
select
    match_date, round, match_name, score,
    total_goals, total_shots_on_goal, total_xg,
    total_yellow_cards, total_red_cards, total_corners
from superligaen.match_results_by_match
where season = '${inputs.season.value}'
  and CAST(match_round_number AS INTEGER) in ${inputs.round.value}
order by match_date desc
```

```sql round_kpis
select
    sum(total_goals)                    as total_goals,
    round(avg(total_goals), 2)          as avg_goals_per_match,
    round(avg(total_shots_on_goal), 1)  as avg_shots_on_goal,
    round(sum(total_xg::double), 2)     as total_xg
from superligaen.match_results_by_match
where season = '${inputs.season.value}'
  and CAST(match_round_number AS INTEGER) in ${inputs.round.value}
```

## Match Results — {inputs.season.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_goals         title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_goals_per_match  title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_shots_on_goal    title="Avg Shots on Goal"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_xg             title="Total xG"           /></div>
</div>

<DataTable data={results} rows=20>
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

---

## Match Analysis

```sql match_options
select
    match_name || '|' || cast(match_date as varchar) as match_key,
    match_name || '  (' || score || ')'              as match_label,
    match_date
from superligaen.match_results_by_match
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) in ${inputs.round.value}
order by match_date desc
```

{#key match_options[0]?.match_key}
<Dropdown data={match_options} name=match value=match_key label=match_label defaultValue={match_options[0]?.match_key} />
{/key}

```sql mc
select
    max(case when side = 'Home' then team_name end)                              as home_team,
    max(case when side = 'Away' then team_name end)                              as away_team,
    max(score)                                                                   as score,
    max(case when side = 'Home' then goals end)                                  as home_goals,
    max(case when side = 'Away' then goals end)                                  as away_goals,
    round(max(case when side = 'Home' then xg end)::double, 2)                   as home_xg,
    round(max(case when side = 'Away' then xg end)::double, 2)                   as away_xg,
    max(case when side = 'Home' then shots_on_goal end)                          as home_sog,
    max(case when side = 'Away' then shots_on_goal end)                          as away_sog,
    max(case when side = 'Home' then total_shots end)                            as home_shots,
    max(case when side = 'Away' then total_shots end)                            as away_shots,
    max(case when side = 'Home' then possession end)                             as home_possession,
    max(case when side = 'Away' then possession end)                             as away_possession,
    max(case when side = 'Home' then pass_accuracy end)                          as home_pass_accuracy,
    max(case when side = 'Away' then pass_accuracy end)                          as away_pass_accuracy,
    max(case when side = 'Home' then corners end)                                as home_corners,
    max(case when side = 'Away' then corners end)                                as away_corners,
    max(case when side = 'Home' then fouls end)                                  as home_fouls,
    max(case when side = 'Away' then fouls end)                                  as away_fouls,
    max(case when side = 'Home' then offsides end)                               as home_offsides,
    max(case when side = 'Away' then offsides end)                               as away_offsides,
    max(case when side = 'Home' then yellow_cards end)                           as home_yc,
    max(case when side = 'Away' then yellow_cards end)                           as away_yc,
    max(case when side = 'Home' then red_cards end)                              as home_rc,
    max(case when side = 'Away' then red_cards end)                              as away_rc,
    max(case when side = 'Home' then saves end)                                  as home_saves,
    max(case when side = 'Away' then saves end)                                  as away_saves
from superligaen.match_analysis
where match_name            = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and season                = '${inputs.season.value}'
```

<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2">

  <div class="grid grid-cols-3 text-center border-b border-gray-200 pb-4 mb-2">
    <div class="text-left font-bold text-lg text-blue-600">{mc[0]?.home_team}<div class="text-xs font-normal text-gray-400">Home</div></div>
    <div class="text-center text-2xl font-bold text-gray-700">{mc[0]?.score}</div>
    <div class="text-right font-bold text-lg text-orange-500">{mc[0]?.away_team}<div class="text-xs font-normal text-gray-400">Away</div></div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_goals}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Goals</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_goals}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0) > 0 ? (mc[0]?.home_goals ?? 0) / ((mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_xg}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">xG</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_xg}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_xg ?? 0) + (mc[0]?.away_xg ?? 0) > 0 ? (mc[0]?.home_xg ?? 0) / ((mc[0]?.home_xg ?? 0) + (mc[0]?.away_xg ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_sog}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Shots on Goal</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_sog}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0) > 0 ? (mc[0]?.home_sog ?? 0) / ((mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_shots}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Total Shots</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_shots}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_shots ?? 0) + (mc[0]?.away_shots ?? 0) > 0 ? (mc[0]?.home_shots ?? 0) / ((mc[0]?.home_shots ?? 0) + (mc[0]?.away_shots ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_possession}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Possession</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_possession}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{mc[0]?.home_possession || 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_pass_accuracy}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Pass Accuracy</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_pass_accuracy}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0) > 0 ? (mc[0]?.home_pass_accuracy ?? 0) / ((mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_corners}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Corners</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_corners}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0) > 0 ? (mc[0]?.home_corners ?? 0) / ((mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_fouls}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Fouls</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_fouls}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0) > 0 ? (mc[0]?.home_fouls ?? 0) / ((mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_offsides}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Offsides</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_offsides}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0) > 0 ? (mc[0]?.home_offsides ?? 0) / ((mc[0]?.home_offsides ?? 0) + (mc[0]?.away_offsides ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_yc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Yellow Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_yc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0) > 0 ? (mc[0]?.home_yc ?? 0) / ((mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_rc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Red Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_rc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0) > 0 ? (mc[0]?.home_rc ?? 0) / ((mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_saves}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Saves</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_saves}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0) > 0 ? (mc[0]?.home_saves ?? 0) / ((mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

</div>
