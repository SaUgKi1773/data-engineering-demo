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
    match_name,
    home_team,
    away_team,
    match_key,
    CASE WHEN stadium LIKE '%Unknown%' OR stadium LIKE '%Applicable%'
         THEN 'TBD' ELSE stadium END                                               as stadium,
    season
from superligaen.upcoming_matches
order by match_date asc
```

## Upcoming Fixtures

<DataTable data={upcoming} rows=10>
    <Column id=match_date  title="Date"    />
    <Column id=round       title="Round"   />
    <Column id=home_team   title="Home"    />
    <Column id=away_team   title="Away"    />
    <Column id=stadium     title="Stadium" />
</DataTable>

---

## Match Analysis

<Dropdown data={upcoming} name=match value=match_key label=match_name />

```sql match_info
select
    home_team,
    away_team,
    strftime(match_date, '%d %b %Y')                          as match_date,
    round,
    CASE WHEN stadium LIKE '%Unknown%' OR stadium LIKE '%Applicable%'
         THEN 'TBD' ELSE stadium END                          as stadium
from superligaen.upcoming_matches
where match_key = '${inputs.match.value}'
limit 1
```

```sql h2h
select
    season::INTEGER::VARCHAR as season,
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
    strftime(match_date, '%Y-%m-%d') as match_date,
    match_name                       as match,
    score
from superligaen.match_results_by_match
where match_name LIKE SPLIT_PART('${inputs.match.value}', '|||', 1) || ' - %'
   or match_name LIKE '% - ' || SPLIT_PART('${inputs.match.value}', '|||', 1)
order by match_date desc
limit 5
```

```sql away_form
select
    strftime(match_date, '%Y-%m-%d') as match_date,
    match_name                       as match,
    score
from superligaen.match_results_by_match
where match_name LIKE SPLIT_PART('${inputs.match.value}', '|||', 2) || ' - %'
   or match_name LIKE '% - ' || SPLIT_PART('${inputs.match.value}', '|||', 2)
order by match_date desc
limit 5
```

<div class="rounded-2xl border border-gray-200 bg-gray-50 p-4 md:p-6 mb-6 text-center">
  <div class="text-xs text-gray-400 uppercase tracking-widest mb-3">{match_info[0].round} &middot; {match_info[0].match_date} &middot; {match_info[0].stadium}</div>
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
  <DataTable data={home_form} rows=5>
      <Column id=match_date  title="Date"  />
      <Column id=match       title="Match" />
      <Column id=score       title="Score" align=center />
  </DataTable>
</div>

<div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
  <div class="text-base font-bold text-gray-700 mb-3">{match_info[0].away_team}</div>
  <DataTable data={away_form} rows=5>
      <Column id=match_date  title="Date"  />
      <Column id=match       title="Match" />
      <Column id=score       title="Score" align=center />
  </DataTable>
</div>

</div>
