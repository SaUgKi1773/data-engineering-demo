---
sidebar: never
hide_toc: true
title: Upcoming Fixtures
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql upcoming
select
    strftime(match_date, '%Y-%m-%d')                                              as match_date,
    round,
    match_round_number,
    match_name,
    home_team,
    away_team,
    match_key,
    kick_off_time,
    CASE WHEN stadium LIKE '%Unknown%' OR stadium LIKE '%Applicable%'
         THEN 'TBD' ELSE stadium END                                               as stadium,
    season
from superligaen.upcoming_matches
order by match_date asc, kick_off_time asc
```

## Upcoming Fixtures

<DataTable data={upcoming} rows=10>
    <Column id=match_date    title="Date"        />
    <Column id=round         title="Round"       />
    <Column id=match_name    title="Match"       wrap=true />
    <Column id=stadium       title="Stadium"     />
    <Column id=kick_off_time title="Kick-Off Time" />
</DataTable>

---

## Match Analysis

<Dropdown data={upcoming} name=match value=match_key label=match_name order="match_round_number desc, match_date asc" />

```sql match_info
select
    home_team,
    away_team,
    strftime(match_date, '%d %b %Y')                          as match_date,
    round,
    kick_off_time,
    CASE WHEN stadium LIKE '%Unknown%' OR stadium LIKE '%Applicable%'
         THEN 'TBD' ELSE stadium END                          as stadium
from superligaen.upcoming_matches
where match_key = '${inputs.match.value}'
limit 1
```

```sql h2h
select
    season,
    match_date,
    round,
    match_short_name    as match,
    score,
    total_goals         as goals,
    total_shots_on_goal as shots_on_goal,
    total_xg            as xg
from superligaen.match_results_by_match
where
    (match_name = SPLIT_PART('${inputs.match.value}', '|||', 1) || ' - ' || SPLIT_PART('${inputs.match.value}', '|||', 2))
 or (match_name = SPLIT_PART('${inputs.match.value}', '|||', 2) || ' - ' || SPLIT_PART('${inputs.match.value}', '|||', 1))
order by match_date desc
```

```sql h2h_stats
select
    SUM(CASE WHEN (team_name = SPLIT_PART('${inputs.match.value}', '|||', 1) AND result = 'Win')
              OR  (team_name = SPLIT_PART('${inputs.match.value}', '|||', 2) AND result = 'Loss') THEN 1 ELSE 0 END) as team1_wins,
    SUM(CASE WHEN result = 'Draw' THEN 1 ELSE 0 END)                                                                as draws,
    SUM(CASE WHEN (team_name = SPLIT_PART('${inputs.match.value}', '|||', 2) AND result = 'Win')
              OR  (team_name = SPLIT_PART('${inputs.match.value}', '|||', 1) AND result = 'Loss') THEN 1 ELSE 0 END) as team2_wins
from superligaen.team_analytics_form
where side = 'Home'
  and (
      (team_name = SPLIT_PART('${inputs.match.value}', '|||', 1) and opponent = SPLIT_PART('${inputs.match.value}', '|||', 2))
   or (team_name = SPLIT_PART('${inputs.match.value}', '|||', 2) and opponent = SPLIT_PART('${inputs.match.value}', '|||', 1))
  )
```

```sql home_form
select
    strftime(match_date, '%d %b') as match_date,
    opponent,
    gf,
    ga,
    result
from superligaen.team_analytics_form
where team_name = SPLIT_PART('${inputs.match.value}', '|||', 1)
order by epoch(match_date) desc
limit 5
```

```sql away_form
select
    strftime(match_date, '%d %b') as match_date,
    opponent,
    gf,
    ga,
    result
from superligaen.team_analytics_form
where team_name = SPLIT_PART('${inputs.match.value}', '|||', 2)
order by epoch(match_date) desc
limit 5
```

<div class="rounded-2xl border border-gray-200 bg-gray-50 p-4 md:p-6 mb-6 text-center">
  <div class="text-xs text-gray-400 uppercase tracking-widest mb-3">{match_info[0].round} &middot; {match_info[0].match_date} &middot; {match_info[0].kick_off_time} &middot; {match_info[0].stadium}</div>
  <div class="flex items-center justify-center gap-4 md:gap-6">
    <div class="flex-1 min-w-0">
      <div class="text-base md:text-xl font-bold text-gray-800 truncate">{match_info[0].home_team}</div>
      <div class="text-xs text-blue-400 font-semibold uppercase tracking-widest mt-1">Home</div>
    </div>
    <div class="text-xl md:text-2xl font-black text-gray-300 shrink-0">vs</div>
    <div class="flex-1 min-w-0">
      <div class="text-base md:text-xl font-bold text-gray-800 truncate">{match_info[0].away_team}</div>
      <div class="text-xs text-red-400 font-semibold uppercase tracking-widest mt-1">Away</div>
    </div>
  </div>
</div>

---

### Head-to-Head History

<div class="grid grid-cols-3 gap-4 mb-6">
  <div class="rounded-xl border border-blue-200 bg-blue-50 p-4 text-center">
    <div class="text-3xl font-black text-blue-600">{h2h_stats[0].team1_wins}</div>
    <div class="text-xs text-blue-400 mt-1 font-semibold uppercase tracking-wide">{match_info[0].home_team} Wins</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-gray-100 p-4 text-center">
    <div class="text-3xl font-black text-gray-500">{h2h_stats[0].draws}</div>
    <div class="text-xs text-gray-400 mt-1 font-semibold uppercase tracking-wide">Draws</div>
  </div>
  <div class="rounded-xl border border-red-200 bg-red-50 p-4 text-center">
    <div class="text-3xl font-black text-red-500">{h2h_stats[0].team2_wins}</div>
    <div class="text-xs text-red-400 mt-1 font-semibold uppercase tracking-wide">{match_info[0].away_team} Wins</div>
  </div>
</div>

<DataTable data={h2h} rows=20>
    <Column id=season         title="Season" />
    <Column id=match_date     title="Date"   />
    <Column id=round          title="Round"  />
    <Column id=match          title="Match"  />
    <Column id=score          title="Score"  align=center />
    <Column id=goals          title="Goals"  contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=shots_on_goal  title="SoG"    contentType=bar colorPalette={['#6366f1']} />
    <Column id=xg             title="xG"     contentType=colorscale colorPalette={['white','#3b82f6']} />
</DataTable>

---

### Form Guide — Last 5 Matches

<div class="grid grid-cols-1 md:grid-cols-2 gap-6">

<div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
  <div class="text-base font-bold text-gray-700 mb-3">{match_info[0].home_team}</div>
  <div class="flex flex-col gap-2">
    {#each home_form as m}
      <div class="flex items-center justify-between rounded-lg bg-white border border-gray-100 px-3 py-2">
        <div class="text-xs text-gray-400 w-14 shrink-0">{m.match_date}</div>
        <div class="text-xs text-gray-600 flex-1 px-2 truncate">vs {m.opponent}</div>
        <div class="text-sm font-bold text-gray-700 w-12 text-center shrink-0">{m.gf}–{m.ga}</div>
        <div class="w-8 text-center shrink-0">
          {#if m.result === 'Win'}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-green-500 text-white">W</span>
          {:else if m.result === 'Draw'}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-yellow-400 text-white">D</span>
          {:else}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-red-500 text-white">L</span>
          {/if}
        </div>
      </div>
    {/each}
  </div>
</div>

<div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
  <div class="text-base font-bold text-gray-700 mb-3">{match_info[0].away_team}</div>
  <div class="flex flex-col gap-2">
    {#each away_form as m}
      <div class="flex items-center justify-between rounded-lg bg-white border border-gray-100 px-3 py-2">
        <div class="text-xs text-gray-400 w-14 shrink-0">{m.match_date}</div>
        <div class="text-xs text-gray-600 flex-1 px-2 truncate">vs {m.opponent}</div>
        <div class="text-sm font-bold text-gray-700 w-12 text-center shrink-0">{m.gf}–{m.ga}</div>
        <div class="w-8 text-center shrink-0">
          {#if m.result === 'Win'}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-green-500 text-white">W</span>
          {:else if m.result === 'Draw'}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-yellow-400 text-white">D</span>
          {:else}
            <span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-red-500 text-white">L</span>
          {/if}
        </div>
      </div>
    {/each}
  </div>
</div>

</div>
