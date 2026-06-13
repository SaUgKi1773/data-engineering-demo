---
sidebar: never
hide_toc: true
title: Upcoming Fixtures
---

```sql teams
select distinct team_name from (
    select home_team as team_name from superligaen.mart_upcoming where home_team is not null
    union
    select away_team as team_name from superligaen.mart_upcoming where away_team is not null
) order by team_name asc
```

```sql rounds
select distinct match_round_number as round_number, round
from superligaen.mart_upcoming
where home_team is not null
order by match_round_number asc
```

{#if teams.length > 0}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Filter by team to see only relevant fixtures. Select a match in the section below to explore head-to-head history and recent form for both sides.</p>

<Dropdown data={teams} name=team value=team_name label=team_name order="team_name asc" multiple=true selectAllByDefault=true />
<Dropdown data={rounds} name=round value=round_number label=round_number title="Round" order="round_number asc" multiple=true defaultValue={rounds[0]?.round_number} />

```sql upcoming
select
    cast(match_id as varchar)                   as match_key,
    home_team || ' - ' || away_team             as match_name,
    round,
    match_round_number,
    home_team,
    away_team,
    home_team_short,
    away_team_short,
    match_short_name,
    home_team_logo,
    away_team_logo,
    strftime(match_date, '%Y-%m-%d')            as match_date,
    strftime(match_date, '%A %d %B')            as match_day,
    kick_off_time,
    '<span style="color:#94a3b8;">' || stadium || '</span>'                  as stadium_muted,
    '<span style="color:#94a3b8;">' || coalesce(referee, '—') || '</span>'  as referee_muted,
    stadium,
    referee,
    season
from superligaen.mart_upcoming
where home_team is not null
  and match_round_number in ${inputs.round.value}
  and (home_team in ${inputs.team.value}
       or away_team in ${inputs.team.value})
order by match_date asc, kick_off_time asc
```

## Upcoming Fixtures

{#each upcoming as m, i}
{#if i === 0 || m.match_date !== upcoming[i-1].match_date}
<div class="text-xs font-bold text-gray-500 uppercase tracking-widest mt-6 mb-2">{m.match_day}</div>
{/if}
<div class="rounded-xl border border-gray-200 bg-white px-4 py-3 mb-3">
  <div class="flex items-center gap-3">
    <div class="flex-1 flex items-center justify-end gap-2 min-w-0">
      <span class="font-semibold text-gray-800 truncate">{m.home_team}</span>
      <img src={m.home_team_logo} alt="" class="h-8 w-8 object-contain shrink-0" onerror="this.style.display='none'" />
    </div>
    <div class="shrink-0 px-3 text-center">
      <div class="text-base md:text-lg font-black text-gray-800 whitespace-nowrap">{m.kick_off_time}</div>
    </div>
    <div class="flex-1 flex items-center gap-2 min-w-0">
      <img src={m.away_team_logo} alt="" class="h-8 w-8 object-contain shrink-0" onerror="this.style.display='none'" />
      <span class="font-semibold text-gray-800 truncate">{m.away_team}</span>
    </div>
  </div>
  <div class="text-[11px] text-gray-400 text-center mt-2 uppercase tracking-wide">{m.round} &middot; {m.stadium} &middot; {m.referee || 'TBD'}</div>
</div>
{/each}

---

## Match Analysis

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a fixture to see the all-time head-to-head record between the two clubs and the last 5 results for each side going into the match.</p>

<Dropdown data={upcoming} name=match value=match_key label=match_short_name order="match_date asc, kick_off_time asc" />

```sql match_info
select
    home_team,
    away_team,
    home_team_short,
    away_team_short,
    home_team_logo,
    away_team_logo,
    match_date,
    round,
    kick_off_time,
    stadium
from ${upcoming}
where match_key = '${inputs.match.value}'
limit 1
```

```sql h2h_seasons
select distinct mc.season
from superligaen.mart_match_card mc
join ${match_info} mi
    on (mc.home_team = mi.home_team and mc.away_team = mi.away_team)
    or (mc.home_team = mi.away_team  and mc.away_team = mi.home_team)
order by mc.season desc
```

```sql h2h
select
    mc.season,
    mc.match_date,
    mc.match_round_name                                                     as round,
    mc.home_team_short || ' - ' || mc.away_team_short                       as match,
    mc.score,
    (mc.home_goals + mc.away_goals)::int                                    as total_goals,
    (mc.home_sog   + mc.away_sog)::int                                      as total_shots_on_goal,
    (mc.home_big_chances + mc.away_big_chances)::int                        as total_big_chances
from superligaen.mart_match_card mc
join ${match_info} mi
    on (mc.home_team = mi.home_team and mc.away_team = mi.away_team)
    or (mc.home_team = mi.away_team  and mc.away_team = mi.home_team)
where mc.season in ${inputs.h2h_season.value}
order by mc.match_date desc
```

```sql h2h_stats
select
    sum(case when (mc.home_team = mi.home_team and mc.home_goals > mc.away_goals)
              or  (mc.away_team = mi.home_team and mc.away_goals > mc.home_goals) then 1 else 0 end)  as team1_wins,
    sum(case when mc.home_goals = mc.away_goals then 1 else 0 end)                                    as draws,
    sum(case when (mc.home_team = mi.away_team  and mc.home_goals > mc.away_goals)
              or  (mc.away_team = mi.away_team  and mc.away_goals > mc.home_goals) then 1 else 0 end) as team2_wins
from superligaen.mart_match_card mc
join ${match_info} mi
    on (mc.home_team = mi.home_team and mc.away_team = mi.away_team)
    or (mc.home_team = mi.away_team  and mc.away_team = mi.home_team)
where mc.season in ${inputs.h2h_season.value}
```

```sql home_form
select
    strftime(tm.match_date, '%d %b')    as match_date,
    tm.opponent_team_short_name         as opponent,
    tm.goals_scored                     as gf,
    tm.goals_conceded                   as ga,
    tm.result
from superligaen.mart_team_match tm
join ${match_info} mi on tm.team_name = mi.home_team
where tm.result in ('Win', 'Draw', 'Loss')
order by tm.match_date desc
limit 5
```

```sql away_form
select
    strftime(tm.match_date, '%d %b')    as match_date,
    tm.opponent_team_short_name         as opponent,
    tm.goals_scored                     as gf,
    tm.goals_conceded                   as ga,
    tm.result
from superligaen.mart_team_match tm
join ${match_info} mi on tm.team_name = mi.away_team
where tm.result in ('Win', 'Draw', 'Loss')
order by tm.match_date desc
limit 5
```

<div class="rounded-2xl border border-gray-200 bg-gray-50 p-4 md:p-6 mb-6 text-center">
  <div class="text-xs text-gray-400 uppercase tracking-widest mb-3">{match_info[0].round} &middot; {match_info[0].match_date} &middot; {match_info[0].kick_off_time} &middot; {match_info[0].stadium}</div>
  <div class="flex items-center justify-center gap-4 md:gap-6">
    <div class="flex-1 min-w-0 flex flex-col items-center">
      <img src={match_info[0].home_team_logo} alt="" class="h-12 w-12 md:h-16 md:w-16 object-contain mb-2" onerror="this.style.display='none'" />
      <div class="text-base md:text-xl font-bold text-gray-800 truncate w-full">{match_info[0].home_team_short}</div>
      <div class="text-xs text-blue-400 font-semibold uppercase tracking-widest mt-1">Home</div>
    </div>
    <div class="text-xl md:text-2xl font-black text-gray-300 shrink-0">vs</div>
    <div class="flex-1 min-w-0 flex flex-col items-center">
      <img src={match_info[0].away_team_logo} alt="" class="h-12 w-12 md:h-16 md:w-16 object-contain mb-2" onerror="this.style.display='none'" />
      <div class="text-base md:text-xl font-bold text-gray-800 truncate w-full">{match_info[0].away_team_short}</div>
      <div class="text-xs text-red-400 font-semibold uppercase tracking-widest mt-1">Away</div>
    </div>
  </div>
</div>

---

### Head-to-Head History

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">All previous meetings between these two clubs. Filter by season to narrow the comparison.</p>

<Dropdown data={h2h_seasons} name=h2h_season value=season label=season multiple=true selectAllByDefault=true order="season desc" />

<div class="grid grid-cols-3 gap-4 mb-6">
  <div class="rounded-xl border border-blue-200 bg-blue-50 p-4 text-center">
    <div class="text-3xl font-black text-blue-600">{h2h_stats[0].team1_wins}</div>
    <div class="text-xs text-blue-400 mt-1 font-semibold uppercase tracking-wide">{match_info[0].home_team_short} Wins</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-gray-100 p-4 text-center">
    <div class="text-3xl font-black text-gray-500">{h2h_stats[0].draws}</div>
    <div class="text-xs text-gray-400 mt-1 font-semibold uppercase tracking-wide">Draws</div>
  </div>
  <div class="rounded-xl border border-red-200 bg-red-50 p-4 text-center">
    <div class="text-3xl font-black text-red-500">{h2h_stats[0].team2_wins}</div>
    <div class="text-xs text-red-400 mt-1 font-semibold uppercase tracking-wide">{match_info[0].away_team_short} Wins</div>
  </div>
</div>

<div class="block md:hidden">
<DataTable data={h2h} rows=20>
    <Column id=match_date          title="Date"        />
    <Column id=match               title="Match"       />
    <Column id=score               title="Score"       align=center />
    <Column id=total_goals         title="Goals"       contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_big_chances   title="Big Ch."     contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_shots_on_goal title="SoG"         contentType=bar colorPalette={['#6366f1']} />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={h2h} rows=20>
    <Column id=season              title="Season"      />
    <Column id=match_date          title="Date"        />
    <Column id=round               title="Round"       />
    <Column id=match               title="Match"       />
    <Column id=score               title="Score"       align=center />
    <Column id=total_goals         title="Goals"       contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_big_chances   title="Big Chances" contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_shots_on_goal title="SoG"         contentType=bar colorPalette={['#6366f1']} />
</DataTable>
</div>

---

### Form Guide — Last 5 Matches

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Most recent five results for each side across all competitions in the current season.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6">

<div class="rounded-xl border border-gray-200 bg-gray-50 p-4">
  <div class="text-base font-bold text-gray-700 mb-3">{match_info[0].home_team_short}</div>
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
  <div class="text-base font-bold text-gray-700 mb-3">{match_info[0].away_team_short}</div>
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

{:else}

<div class="flex flex-col items-center justify-center py-24 text-center">
  <div class="text-5xl mb-4">📅</div>
  <div class="text-xl font-bold text-gray-700 mb-2">No Upcoming Fixtures</div>
  <div class="text-gray-400 text-sm">There are no scheduled matches at the moment. Check back soon.</div>
</div>

{/if}
