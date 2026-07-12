---
sidebar: never
hide_toc: true
title: Upcoming Fixtures
---

```sql teams
select distinct team_name from (
    select home_team as team_name from scotland.mart_upcoming where home_team is not null
    union
    select away_team as team_name from scotland.mart_upcoming where away_team is not null
) order by team_name asc
```

```sql rounds
select distinct cast(match_round_number as int) as round_number, round
from scotland.mart_upcoming
where home_team is not null
order by round_number asc
```

{#if teams.length > 0}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Filter by team or round to narrow the fixtures. Click any match to open its preview — head-to-head history and recent form for both sides.</p>

<Dropdown data={teams} name=team value=team_name label=team_name order="team_name asc" multiple=true selectAllByDefault=true />
{#key rounds[0]?.round_number}
<Dropdown data={rounds} name=round value=round_number label=round_number title="Round" order="round_number asc" multiple=true defaultValue={rounds[0]?.round_number} />
{/key}

```sql upcoming
select
    cast(cast(match_id as bigint) as varchar)   as match_key,
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
    stadium,
    referee,
    season,
    home_win_prob,
    draw_prob,
    away_win_prob
from scotland.mart_upcoming
where home_team is not null
  and match_round_number in ${inputs.round.value}
  and (home_team in ${inputs.team.value}
       or away_team in ${inputs.team.value})
order by match_date asc, kick_off_time asc
```

```sql round_title
select string_agg(round_number::varchar, ', ' order by round_number) as label
from (
    select distinct cast(match_round_number as int) as round_number
    from scotland.mart_upcoming
    where home_team is not null
      and match_round_number in ${inputs.round.value}
)
```

## Upcoming Fixtures — Round {round_title[0]?.label}

{#each upcoming as m, i}
{#if i === 0 || m.match_date !== upcoming[i-1].match_date}
<div class="text-xs font-bold text-gray-500 uppercase tracking-widest mt-6 mb-2">{m.match_day}</div>
{/if}
<a href="/upcoming-match-analysis?match={m.match_key}" style="text-decoration:none;color:inherit;display:block;">
<div class="rounded-xl border border-gray-200 bg-white px-4 py-3 mb-3 transition hover:shadow-md hover:border-gray-300 cursor-pointer">
  <div class="flex items-center gap-3">
    <div class="flex-1 flex items-center justify-end gap-2 min-w-0">
      <span class="font-semibold text-gray-800 truncate md:hidden">{m.home_team_short}</span>
      <span class="font-semibold text-gray-800 truncate hidden md:inline">{m.home_team}</span>
      <img src={m.home_team_logo} alt="" class="h-8 w-8 object-contain shrink-0" onerror="this.style.display='none'" />
    </div>
    <div class="shrink-0 px-3 text-center">
      <div class="text-sm font-black text-gray-300">VS</div>
    </div>
    <div class="flex-1 flex items-center gap-2 min-w-0">
      <img src={m.away_team_logo} alt="" class="h-8 w-8 object-contain shrink-0" onerror="this.style.display='none'" />
      <span class="font-semibold text-gray-800 truncate md:hidden">{m.away_team_short}</span>
      <span class="font-semibold text-gray-800 truncate hidden md:inline">{m.away_team}</span>
    </div>
  </div>
  {#if m.home_win_prob != null}
  <div class="mt-3 max-w-md mx-auto">
    <div class="flex h-1.5 rounded-full overflow-hidden gap-[2px]">
      <div class="bg-[#3b82f6] rounded-l-full" style="width:{(m.home_win_prob*100).toFixed(1)}%"></div>
      <div class="bg-[#94a3b8]" style="width:{(m.draw_prob*100).toFixed(1)}%"></div>
      <div class="bg-[#f97316] rounded-r-full" style="width:{(m.away_win_prob*100).toFixed(1)}%"></div>
    </div>
    <div class="flex justify-between text-[10px] text-gray-500 mt-1">
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#3b82f6] mr-1"></span>{m.home_team_short} {Math.round(m.home_win_prob*100)}%</span>
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#94a3b8] mr-1"></span>Draw {Math.round(m.draw_prob*100)}%</span>
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#f97316] mr-1"></span>{m.away_team_short} {Math.round(m.away_win_prob*100)}%</span>
    </div>
  </div>
  {/if}
  <div class="text-[11px] text-gray-400 text-center mt-2 uppercase tracking-wide">{m.stadium} &middot; {m.kick_off_time}</div>
</div>
</a>
{/each}

<p style="font-size:0.7rem;color:#9ca3af;margin:1.5rem 0 0 0;font-style:italic;">Win probabilities are produced by our data science team's model before each round. See how it scores against reality on the <a href="/prediction-tracker" style="color:#6b7280;">Prediction Tracker</a>.</p>

{:else}

<div class="flex flex-col items-center justify-center py-24 text-center">
  <div class="text-5xl mb-4">📅</div>
  <div class="text-xl font-bold text-gray-700 mb-2">No Upcoming Fixtures</div>
  <div class="text-gray-400 text-sm">There are no scheduled matches at the moment. Check back soon.</div>
</div>

{/if}
