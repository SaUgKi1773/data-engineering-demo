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

```sql summary
select * from superligaen.mart_home_summary
```

<div class="relative rounded-2xl overflow-hidden mb-6 shadow-lg" style="background: linear-gradient(135deg, #1e3a5f 0%, #1a5276 40%, #1a6b4a 100%);">
  <!-- pitch lines overlay -->
  <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <!-- center circle hint -->
  <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
    <div class="rounded-full border border-white opacity-[0.06]" style="width:320px;height:320px;"></div>
  </div>

  <div class="relative px-6 py-8 md:px-12 md:py-10 flex flex-col md:flex-row items-center justify-between gap-6">
    <!-- left: league identity -->
    <div class="flex items-center gap-5">
      <div class="bg-white/10 backdrop-blur rounded-2xl p-3 shadow-inner flex-shrink-0">
        <img src="{league[0].league_logo}" alt="Superligaen" class="h-14 md:h-20 w-auto" onerror="this.style.display='none'" />
      </div>
      <div>
        <div class="flex items-center gap-2 mb-1">
          <img src="{league[0].league_country_flag}" alt="Denmark" class="h-4 rounded opacity-90" onerror="this.style.display='none'" />
          <span class="text-white/50 text-xs uppercase tracking-widest">Denmark</span>
        </div>
        <div class="text-3xl md:text-4xl font-extrabold tracking-tight text-white leading-tight">Superligaen</div>
        <div class="text-white/50 text-xs mt-1 tracking-wide italic">Powered by data. Built for football.</div>
      </div>
    </div>

    <!-- right: live stats pills -->
    <div class="flex flex-wrap justify-center md:justify-end gap-3">
      <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-4 py-3 text-center min-w-[80px]">
        <div class="text-white text-xl font-black leading-none">{summary[0].total_goals}</div>
        <div class="text-white/50 text-xs mt-1 uppercase tracking-wide">Goals</div>
      </div>
      <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-4 py-3 text-center min-w-[80px]">
        <div class="text-white text-xl font-black leading-none">{summary[0].total_matches}</div>
        <div class="text-white/50 text-xs mt-1 uppercase tracking-wide">Matches</div>
      </div>
      <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-4 py-3 text-center min-w-[80px]">
        <div class="text-white text-xl font-black leading-none">{summary[0].total_teams}</div>
        <div class="text-white/50 text-xs mt-1 uppercase tracking-wide">Teams</div>
      </div>
      <div class="rounded-xl backdrop-blur px-4 py-3 text-center min-w-[80px]"
           style="{new Date() > new Date(summary[0].season_end) ? 'background:rgba(100,116,139,0.2);border:1px solid rgba(148,163,184,0.3)' : 'background:rgba(74,222,128,0.2);border:1px solid rgba(74,222,128,0.3)'}">
        <div class="text-sm font-black leading-none"
             style="{new Date() > new Date(summary[0].season_end) ? 'color:rgb(203,213,225)' : 'color:rgb(134,239,172)'}">{summary[0].season}</div>
        <div class="text-xs mt-1 uppercase tracking-wide"
             style="{new Date() > new Date(summary[0].season_end) ? 'color:rgba(148,163,184,0.7)' : 'color:rgba(74,222,128,0.7)'}">{new Date() > new Date(summary[0].season_end) ? 'Ended' : 'Live'}</div>
      </div>
    </div>
  </div>
</div>

<div class="rounded-xl border border-amber-200 bg-amber-50 shadow-sm p-4 mb-8 flex items-center gap-3">
  <div class="text-amber-400 text-2xl">{new Date() > new Date(summary[0].season_end) ? '👑' : '🥇'}</div>
  <div class="text-xs font-semibold text-amber-600 uppercase tracking-widest flex-shrink-0">{new Date() > new Date(summary[0].season_end) ? 'Champion' : 'Current Leader'}</div>
  <div class="flex-1 h-px bg-amber-200"></div>
  <div class="text-sm font-bold text-amber-800">{summary[0]?.leader_name}</div>
  <div class="text-xs text-amber-600 font-semibold">{summary[0]?.leader_pts} pts</div>
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
