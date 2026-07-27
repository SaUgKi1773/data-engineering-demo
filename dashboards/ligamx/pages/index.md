---
sidebar: never
hide_toc: true
title: Liga MX Analytics — Mexican football intelligence
hide_title: true
description: Free, open analytics for Liga MX, the Mexican top flight — Apertura and Clausura standings, liguilla results, match, player and referee intelligence, refreshed every night. A Krogvad Analytics Hub platform.
---

<script>
  import SiteFooter from '../components/SiteFooter.svelte';
</script>

```sql league
select * from ligamx.league_info
```

```sql last_updated
select * from ligamx.last_updated
```

```sql summary
select * from ligamx.mart_home_summary
```

<!-- ══ HERO — flag-colored banner with pitch lines (compact layout) ══ -->
<!-- phone & tablet (incl. iPad landscape): centered stack · laptop/desktop (>=1280px): compact horizontal row -->
<div class="relative rounded-3xl overflow-hidden shadow-lg mb-8" style="background: linear-gradient(135deg, #04331f 0%, #006847 45%, #12a05e 100%); font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <!-- pitch lines overlay -->
  <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <!-- center circle hint -->
  <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
    <div class="rounded-full border border-white opacity-[0.06]" style="width:320px;height:320px;"></div>
  </div>

  <div class="relative px-6 py-7 xl:px-12 xl:py-6 text-center xl:text-left flex flex-col xl:flex-row items-center xl:justify-between gap-4 xl:gap-6">

    <!-- left: league identity -->
    <div class="flex flex-col xl:flex-row items-center xl:items-center gap-3 xl:gap-5">
      <img src="{league[0].league_logo}" alt="Liga MX" class="h-12 xl:h-14 w-auto flex-shrink-0" onerror="this.style.display='none'" />
      <div>
        <div class="flex items-center justify-center xl:justify-start gap-2 mb-1">
          <img src="{league[0].league_country_flag}" alt="Mexico" class="h-3.5 rounded opacity-90" onerror="this.style.display='none'" />
          <span class="text-white/50 text-[11px] uppercase" style="letter-spacing: 0.14em;">Mexico</span>
        </div>
        <div class="text-3xl xl:text-4xl font-bold tracking-tight text-white leading-none">Liga MX</div>
        <div class="text-white/60 text-[13px] mt-1.5">
          <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{summary[0].season_is_live ? '#4ade80' : '#cbd5e1'};"></span>{summary[0].season} · {summary[0].season_is_live ? 'Live' : 'Ended'}
        </div>
      </div>
    </div>

    <!-- right: stats + leader -->
    <div class="flex flex-col items-center xl:items-end gap-2">
      <div class="text-white/70 text-sm xl:text-base">
        <span class="font-semibold text-white">{summary[0].total_goals}</span> goals · <span class="font-semibold text-white">{summary[0].total_matches}</span> matches · <span class="font-semibold text-white">{summary[0].total_teams}</span> teams
      </div>

      <!-- Three states, because a Liga MX tournament has three phases. The
           knockout one names the ROUND, not a club: once the table is final
           there is no leader, and the club that topped it is often already
           out. -->
      <div class="inline-flex items-center gap-2 text-[15px]">
        <span class="leading-none">{summary[0].state === 'Champion' ? '👑' : summary[0].state === 'Liguilla' ? '🏆' : '🥇'}</span>
        <span class="text-white/50 text-[11px] font-semibold uppercase" style="letter-spacing: 0.12em;">{summary[0].state}</span>
        <span class="font-semibold text-white">
          {#if summary[0].state === 'Liguilla'}
            {summary[0].liguilla_round}
          {:else}
            <span class="xl:hidden">{summary[0]?.leader_short}</span><span class="hidden xl:inline">{summary[0]?.leader_name}</span>
          {/if}
        </span>
      </div>
    </div>
  </div>
</div>

<div>

<div class="mb-5">
  <div class="mb-2 flex items-center gap-3">
    <span class="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Overview</span>
    <div class="h-px flex-1 bg-gray-200"></div>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
    <a href="/standings" class="group flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm no-underline transition-all duration-200 hover:border-amber-300 hover:shadow-md">
      <span class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-amber-50 text-lg">🏆</span>
      <span class="text-sm font-semibold text-gray-800 transition-colors group-hover:text-amber-600">Standings</span>
      <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-amber-400">→</span>
    </a>
  </div>
</div>

<div class="mb-5">
  <div class="mb-2 flex items-center gap-3">
    <span class="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Matches</span>
    <div class="h-px flex-1 bg-gray-200"></div>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
    <a href="/upcoming-matches" class="group flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm no-underline transition-all duration-200 hover:border-violet-300 hover:shadow-md">
      <span class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-violet-50 text-lg">📅</span>
      <span class="text-sm font-semibold text-gray-800 transition-colors group-hover:text-violet-600">Upcoming Fixtures</span>
      <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-violet-400">→</span>
    </a>
    <a href="/match-results" class="group flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm no-underline transition-all duration-200 hover:border-blue-300 hover:shadow-md">
      <span class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-blue-50 text-lg">⚽</span>
      <span class="text-sm font-semibold text-gray-800 transition-colors group-hover:text-blue-600">Match Results</span>
      <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-blue-400">→</span>
    </a>
    <a href="/predictions" class="group flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm no-underline transition-all duration-200 hover:border-fuchsia-300 hover:shadow-md">
      <span class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-fuchsia-50 text-lg">🔮</span>
      <span class="flex items-center gap-2">
        <span class="text-sm font-semibold text-gray-800 transition-colors group-hover:text-fuchsia-600">Prediction Module</span>
        <span class="rounded-full bg-red-500 px-1.5 py-px text-[9px] font-bold uppercase tracking-wide text-white">New</span>
      </span>
      <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-fuchsia-400">→</span>
    </a>
  </div>
</div>

<div class="mb-5">
  <div class="mb-2 flex items-center gap-3">
    <span class="text-[11px] font-semibold uppercase tracking-widest text-gray-400">More</span>
    <div class="h-px flex-1 bg-gray-200"></div>
  </div>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-2.5">
    <a href="/about" class="group flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm no-underline transition-all duration-200 hover:border-gray-400 hover:shadow-md">
      <span class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg bg-gray-100 text-lg">👤</span>
      <span class="text-sm font-semibold text-gray-800 transition-colors group-hover:text-gray-600">About This Project</span>
      <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-gray-500">→</span>
    </a>
  </div>
</div>

</div>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
