---
sidebar: never
hide_toc: true
title: Superliga Analytics — Danish football intelligence
hide_title: true
description: Free, open analytics for Superligaen, the Danish premier football league — standings, match results, player, referee and transfer intelligence, refreshed every night. A Krogvad Analytics Hub platform.
---

<script>
  import SiteFooter from '../components/SiteFooter.svelte';
</script>

```sql league
select * from superligaen.league_info
```

```sql last_updated
select * from superligaen.last_updated
```

```sql summary
select * from superligaen.mart_home_summary
```

<!-- ══ HERO — Apple-style clean tile (mirrors the Krogvad Hub platform card) ══ -->
<!-- mobile: centered stack · desktop: compact horizontal row so the page fits the window -->
<div class="rounded-3xl px-6 py-7 md:px-12 md:py-6 mb-8 text-center md:text-left flex flex-col md:flex-row items-center md:justify-between gap-4 md:gap-6" style="background:#f5f5f7; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

  <!-- left: league identity -->
  <div class="flex flex-col md:flex-row items-center md:items-center gap-3 md:gap-5">
    <img src="{league[0].league_logo}" alt="Superligaen" class="h-12 md:h-14 w-auto flex-shrink-0" onerror="this.style.display='none'" />
    <div>
      <div class="flex items-center justify-center md:justify-start gap-2 mb-1">
        <img src="{league[0].league_country_flag}" alt="Denmark" class="h-3.5 rounded" onerror="this.style.display='none'" />
        <span class="text-gray-400 text-[11px] uppercase" style="letter-spacing: 0.14em;">Denmark</span>
      </div>
      <div class="text-3xl md:text-4xl font-bold tracking-tight text-gray-900 leading-none">Superligaen</div>
      <div class="text-gray-400 text-[13px] mt-1.5">
        <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{new Date() > new Date(summary[0].season_end) ? '#a1a1a6' : '#30b14e'};"></span>{summary[0].season} · {new Date() > new Date(summary[0].season_end) ? 'Ended' : 'Live'}
      </div>
    </div>
  </div>

  <!-- right: stats + leader -->
  <div class="flex flex-col items-center md:items-end gap-2">
    <div class="text-gray-500 text-sm md:text-base">
      <span class="font-semibold text-gray-900">{summary[0].total_goals}</span> goals · <span class="font-semibold text-gray-900">{summary[0].total_matches}</span> matches · <span class="font-semibold text-gray-900">{summary[0].total_teams}</span> teams
    </div>

    <div class="inline-flex items-center gap-2 text-[15px]">
      <span class="leading-none">{new Date() > new Date(summary[0].season_end) ? '👑' : '🥇'}</span>
      <span class="text-gray-400 text-[11px] font-semibold uppercase" style="letter-spacing: 0.12em;">{new Date() > new Date(summary[0].season_end) ? 'Champion' : 'Leader'}</span>
      <span class="font-semibold text-gray-900"><span class="md:hidden">{summary[0]?.leader_short}</span><span class="hidden md:inline">{summary[0]?.leader_name}</span></span>
    </div>
  </div>
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
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Scorelines, round KPIs &amp; players of the week</div>
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
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Season KPIs, points race, team radar &amp; domain rankings</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-emerald-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/team-analytics" class="flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-sky-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <div class="rounded-xl bg-sky-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">👥</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-sky-600 transition-colors">Team Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Season KPIs, goals timeline, formation &amp; home/away splits</div>
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

<a href="/transfer-intelligence" class="relative overflow-hidden flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-purple-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <!-- "New" corner ribbon -->
  <span class="pointer-events-none absolute -right-8 top-3 rotate-45 bg-red-500 px-8 py-0.5 text-[9px] font-bold uppercase tracking-wider text-white shadow">New</span>
  <div class="rounded-xl bg-purple-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">🔁</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-purple-600 transition-colors">Transfer Intelligence</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Net spend, ins &amp; outs, record fees &amp; per-club ledgers</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-purple-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
</a>

<a href="/predictions" class="relative overflow-hidden flex items-center no-underline rounded-xl border border-gray-200 bg-white p-4 hover:border-fuchsia-300 hover:shadow-md transition-all duration-200 group shadow-sm">
  <!-- "New" corner ribbon -->
  <span class="pointer-events-none absolute -right-8 top-3 rotate-45 bg-red-500 px-8 py-0.5 text-[9px] font-bold uppercase tracking-wider text-white shadow">New</span>
  <div class="rounded-xl bg-fuchsia-50 w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4">🔮</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-bold text-gray-800 group-hover:text-fuchsia-600 transition-colors">Prediction Module</div>
    <div class="text-gray-400 text-xs mt-0.5 leading-snug">Win probabilities for every fixture &amp; the model's track record</div>
  </div>
  <div class="shrink-0 text-gray-300 group-hover:text-fuchsia-400 group-hover:translate-x-1 transition-all duration-200 ml-3">→</div>
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

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
