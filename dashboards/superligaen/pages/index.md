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
<!-- phone & tablet (incl. iPad landscape): centered stack · laptop/desktop (>=1280px): compact horizontal row -->
<div class="rounded-3xl px-6 py-7 xl:px-12 xl:py-6 mb-8 text-center xl:text-left flex flex-col xl:flex-row items-center xl:justify-between gap-4 xl:gap-6" style="background:#f5f5f7; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

  <!-- left: league identity -->
  <div class="flex flex-col xl:flex-row items-center xl:items-center gap-3 xl:gap-5">
    <img src="{league[0].league_logo}" alt="Superligaen" class="h-12 xl:h-14 w-auto flex-shrink-0" onerror="this.style.display='none'" />
    <div>
      <div class="flex items-center justify-center xl:justify-start gap-2 mb-1">
        <img src="{league[0].league_country_flag}" alt="Denmark" class="h-3.5 rounded" onerror="this.style.display='none'" />
        <span class="text-gray-400 text-[11px] uppercase" style="letter-spacing: 0.14em;">Denmark</span>
      </div>
      <div class="text-3xl xl:text-4xl font-bold tracking-tight text-gray-900 leading-none">Superligaen</div>
      <div class="text-gray-400 text-[13px] mt-1.5">
        <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{new Date() > new Date(summary[0].season_end) ? '#a1a1a6' : '#30b14e'};"></span>{summary[0].season} · {new Date() > new Date(summary[0].season_end) ? 'Ended' : 'Live'}
      </div>
    </div>
  </div>

  <!-- right: stats + leader -->
  <div class="flex flex-col items-center xl:items-end gap-2">
    <div class="text-gray-500 text-sm xl:text-base">
      <span class="font-semibold text-gray-900">{summary[0].total_goals}</span> goals · <span class="font-semibold text-gray-900">{summary[0].total_matches}</span> matches · <span class="font-semibold text-gray-900">{summary[0].total_teams}</span> teams
    </div>

    <div class="inline-flex items-center gap-2 text-[15px]">
      <span class="leading-none">{new Date() > new Date(summary[0].season_end) ? '👑' : '🥇'}</span>
      <span class="text-gray-400 text-[11px] font-semibold uppercase" style="letter-spacing: 0.12em;">{new Date() > new Date(summary[0].season_end) ? 'Champion' : 'Leader'}</span>
      <span class="font-semibold text-gray-900"><span class="xl:hidden">{summary[0]?.leader_short}</span><span class="hidden xl:inline">{summary[0]?.leader_name}</span></span>
    </div>
  </div>
</div>

<div class="flex items-center gap-3 mb-4">
  <span class="text-xs font-semibold text-gray-400 uppercase tracking-widest">Explore</span>
  <div class="flex-1 h-px bg-gray-200"></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-3" style="font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

<a href="/standings" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">🏆</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Standings</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Championship, Relegation &amp; Regular Season tables</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/match-results" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">⚽</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Match Results</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Scorelines, round KPIs &amp; players of the week</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/upcoming-matches" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">📅</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Upcoming Fixtures</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Head-to-head history &amp; form guide for upcoming matches</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/league-analytics" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">📈</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">League Intelligence</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Season KPIs, points race, team radar &amp; domain rankings</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/team-analytics" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">👥</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Team Intelligence</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Season KPIs, goals timeline, formation &amp; home/away splits</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/player-analytics" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">👟</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Player Intelligence</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Percentile radar, performance timeline &amp; match-by-match log</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/stadium-analytics" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">🏟️</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Stadium Intelligence</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Stadium map, surface effects and home fortress rankings</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/referee-analytics" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">🟨</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Referee Intelligence</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Cards, fouls, home/away bias and discipline trends</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/transfer-intelligence" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">🔁</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Transfer Intelligence <span class="align-middle ml-1 rounded-full px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-white" style="background:#c8102e;">New</span></div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Net spend, ins &amp; outs, record fees &amp; per-club ledgers</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/predictions" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">🔮</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Prediction Module <span class="align-middle ml-1 rounded-full px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-white" style="background:#c8102e;">New</span></div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Win probabilities for every fixture &amp; the model's track record</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/glossary" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">📖</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">Data Glossary</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">Definitions and formulas for all KPIs and abbreviations</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

<a href="/about" class="group flex items-center no-underline rounded-2xl px-5 py-4 transition-transform duration-200 hover:scale-[1.01]" style="background:#f5f5f7;">
  <div class="rounded-xl bg-white w-11 h-11 flex items-center justify-center text-xl flex-shrink-0 mr-4 shadow-sm">👤</div>
  <div class="flex-1 min-w-0">
    <div class="text-sm font-semibold text-gray-900">About This Project</div>
    <div class="text-gray-500 text-xs mt-0.5 leading-snug">The story behind this project, the blog &amp; the author</div>
  </div>
  <div class="shrink-0 text-lg leading-none text-gray-300 group-hover:text-gray-500 group-hover:translate-x-1 transition-all duration-200 ml-3">›</div>
</a>

</div>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
