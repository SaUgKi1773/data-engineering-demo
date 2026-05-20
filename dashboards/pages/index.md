---
sidebar: never
hide_toc: true
title: " "
---

```sql league
select * from superligaen.league_info
```

```sql last_updated
select * from superligaen.last_updated
```

```sql kpis
select
    count(distinct match_id)    as total_matches,
    sum(goals_scored)           as total_goals,
    count(distinct team_name)   as total_teams,
    max(season)                 as season
from superligaen.mart_match_facts
where is_current_season = true
  and result in ('Win', 'Draw', 'Loss')
```

```sql leader
select team_name, team_short_name, pts
from (
    select
        team_name,
        team_short_name,
        standings_type,
        sum(points_earned)                      as pts,
        sum(goals_scored) - sum(goals_conceded) as gd,
        sum(goals_scored)                       as gf
    from superligaen.mart_match_facts
    where is_current_season = true
      and result in ('Win', 'Draw', 'Loss')
    group by team_name, team_short_name, standings_type
)
order by
    case standings_type
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        when 'Regular Season'     then 3
    end,
    pts desc, gd desc, gf desc
limit 1
```

<div class="relative rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-10 mb-6 shadow-xl overflow-hidden">
  <div class="absolute inset-0 opacity-[0.06]" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 22px 22px;"></div>
  <div class="absolute top-4 right-4 bg-white/10 rounded-xl p-2 backdrop-blur">
    <img src="{league[0].league_logo}" alt="Superligaen" class="h-8 md:h-12" />
  </div>
  <div class="flex items-center justify-center gap-4 md:gap-6 relative">
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-7 md:h-10 rounded-lg shadow-lg opacity-90" />
    <div class="text-center">
      <div class="text-3xl md:text-5xl font-extrabold tracking-tight text-white">Superligaen</div>
      <div class="text-gray-400 text-xs md:text-sm mt-2 md:mt-3 uppercase tracking-widest">Danish Premier Football League</div>
      <div class="flex items-center justify-center gap-2 mt-3">
        <div class="inline-block px-3 py-1 rounded-full bg-blue-500/20 border border-blue-400/30 text-blue-300 text-sm font-semibold">{kpis[0].season}</div>
        <div class="inline-block px-3 py-1 rounded-full bg-green-500/20 border border-green-400/30 text-green-300 text-xs font-semibold uppercase tracking-wide">Live</div>
      </div>
    </div>
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-7 md:h-10 rounded-lg shadow-lg opacity-90" />
  </div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={leader} value=team_short_name title="Season Leader" /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}   value=total_teams   title="Teams"          /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}   value=total_matches title="Matches Played"  /></div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 text-center"><BigValue data={kpis}   value=total_goals   title="Goals Scored"    /></div>
</div>

<div class="flex items-center gap-3 mb-4">
  <span class="text-xs font-semibold text-gray-400 uppercase tracking-widest">Explore</span>
  <div class="flex-1 h-px bg-gray-200"></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-3">

<a href="/standings" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-amber-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-amber-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">🏆</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-amber-600 transition-colors">Standings</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Championship, Relegation &amp; Regular Season tables</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-amber-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/match-results" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-blue-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-blue-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">⚽</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-blue-600 transition-colors">Match Results</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Full match history, scorelines and analytics by round</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-blue-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/upcoming-matches" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-violet-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-violet-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">📅</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-violet-600 transition-colors">Upcoming Fixtures</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Head-to-head history &amp; form guide for upcoming matches</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-violet-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/league-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-emerald-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-emerald-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">📈</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-emerald-600 transition-colors">League Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Standings, points race, team radar &amp; discipline rankings</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/team-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-sky-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-sky-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">👥</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-sky-600 transition-colors">Team Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Points race, match log, squad depth &amp; home/away splits</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-sky-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/player-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-indigo-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-indigo-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">👟</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-indigo-600 transition-colors">Player Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Percentile radar, performance timeline &amp; match-by-match log</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-indigo-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/stadium-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-orange-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-orange-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">🏟️</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-orange-600 transition-colors">Stadium Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Stadium map, surface effects and home fortress rankings</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-orange-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/referee-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-red-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-red-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">🟨</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-red-600 transition-colors">Referee Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Cards, fouls, home/away bias and discipline trends</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-red-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/glossary" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-slate-400 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-slate-100 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">📖</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-slate-600 transition-colors">Data Glossary</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Definitions and formulas for all KPIs and abbreviations</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-slate-500 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/about" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-gray-400 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-gray-100 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">👤</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-gray-600 transition-colors">About This Project</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">The story behind this project, the blog &amp; the author</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

</div>

<div class="mt-8 text-center text-xs text-gray-400">Data last updated: {last_updated[0]?.last_updated}</div>
