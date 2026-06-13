---
sidebar: never
hide_toc: true
title: Match Preview
---

<script>
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';

  const pageInputs = getInputContext();

  onMount(() => {
    const sp = new URLSearchParams(window.location.search);
    const m = sp.get('match');
    if (!m) return;
    pageInputs.update(($i) => ({
      ...$i,
      match: { value: m, label: m, rawValues: [{ value: m, label: m, selected: true }] }
    }));
  });
</script>

```sql match_info
select
    home_team,
    away_team,
    home_team_short,
    away_team_short,
    home_team_logo,
    away_team_logo,
    strftime(match_date, '%Y-%m-%d')  as match_date,
    round,
    kick_off_time,
    stadium
from superligaen.mart_upcoming
where match_id = cast('${inputs.match.value}' as bigint)
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
    cast(mc.match_round_number as int)                                      as round_no,
    mc.home_team_short || ' - ' || mc.away_team_short                       as match,
    case
        when mc.home_goals = mc.away_goals then '<span style="color:#9ca3af;font-weight:600;">Draw</span>'
        when (case when mc.home_goals > mc.away_goals then mc.home_team else mc.away_team end) = mi.home_team
            then '<span style="color:#2563eb;font-weight:600;">'
                 || (case when mc.home_goals > mc.away_goals then mc.home_team_short else mc.away_team_short end)
                 || '</span>'
        else '<span style="color:#ef4444;font-weight:600;">'
             || (case when mc.home_goals > mc.away_goals then mc.home_team_short else mc.away_team_short end)
             || '</span>'
    end                                                                     as winner,
    mc.score,
    (mc.home_goals + mc.away_goals)::int                                    as total_goals,
    (mc.home_sog   + mc.away_sog)::int                                      as total_shots_on_goal,
    (mc.home_big_chances + mc.away_big_chances)::int                        as total_big_chances
from superligaen.mart_match_card mc
join ${match_info} mi
    on (mc.home_team = mi.home_team and mc.away_team = mi.away_team)
    or (mc.home_team = mi.away_team  and mc.away_team = mi.home_team)
where mc.season in ${inputs.h2h_season.value}
  and mc.home_goals is not null
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
  and mc.home_goals is not null
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

<a href="/upcoming-matches" style="display:inline-flex;align-items:center;gap:6px;font-size:0.8125rem;font-weight:600;color:#6b7280;text-decoration:none;margin-bottom:16px;">← Upcoming Fixtures</a>

{#if match_info.length > 0}

<div class="rounded-2xl border border-gray-200 bg-gray-50 p-4 md:p-6 mb-6 text-center">
  <div class="text-xs text-gray-400 uppercase tracking-widest mb-3">{match_info[0].round} &middot; {match_info[0].match_date}</div>
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
  <div class="text-xs text-gray-400 uppercase tracking-widest mt-3">{match_info[0].stadium} &middot; {match_info[0].kick_off_time}</div>
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
    <Column id=season              title="Season"      />
    <Column id=round_no            title="Round"       align=center />
    <Column id=match               title="Match"       />
    <Column id=winner              title="Winner"      contentType=html />
    <Column id=score               title="Score"       align=center />
    <Column id=total_goals         title="Goals"       contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_big_chances   title="Big Chances" contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_shots_on_goal title="SoG"         contentType=bar colorPalette={['#6366f1']} />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={h2h} rows=20>
    <Column id=season              title="Season"      />
    <Column id=round               title="Round"       />
    <Column id=match               title="Match"       />
    <Column id=winner              title="Winner"      contentType=html />
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

<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2 text-center text-gray-400 text-sm">
  Loading match preview…
</div>

{/if}
