---
sidebar: never
hide_toc: true
title: Liga MX Analytics — Mexican football intelligence
hide_title: true
description: Free, open analytics for Liga MX, the Mexican top flight — Apertura and Clausura tables, liguilla results, expected goals and match intelligence, refreshed every night. A Krogvad Analytics Hub platform.
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
select * from ligamx.mart_home_summary where is_current order by tournament desc limit 1
```

```sql leader
select l.* from ligamx.mart_home_leader l
join ligamx.mart_home_summary s on s.tournament = l.tournament
where s.is_current order by l.tournament desc limit 1
```

<!-- ══ HERO — Mexican flag colours over pitch lines ══ -->
<div class="relative rounded-3xl overflow-hidden shadow-lg mb-8" style="background: linear-gradient(135deg, #04412c 0%, #006847 45%, #0d7a4f 100%); font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
    <div class="rounded-full border border-white opacity-[0.06]" style="width:320px;height:320px;"></div>
  </div>
  <!-- red flag band, right edge -->
  <div class="absolute top-0 right-0 h-full opacity-90" style="width:10px;background:#ce1126;"></div>

  <div class="relative px-6 py-7 xl:px-12 xl:py-6 text-center xl:text-left flex flex-col xl:flex-row items-center xl:justify-between gap-4 xl:gap-6">

    <div class="flex flex-col xl:flex-row items-center gap-3 xl:gap-5">
      <img src="{league[0].league_logo}" alt="Liga MX" class="h-12 xl:h-14 w-auto flex-shrink-0" onerror="this.style.display='none'" />
      <div>
        <div class="flex items-center justify-center xl:justify-start gap-2 mb-1">
          <img src="{league[0].league_country_flag}" alt="Mexico" class="h-3.5 rounded opacity-90" onerror="this.style.display='none'" />
          <span class="text-white/50 text-[11px] uppercase" style="letter-spacing: 0.14em;">Mexico</span>
        </div>
        <div class="text-3xl xl:text-4xl font-bold tracking-tight text-white leading-none">Liga MX</div>
        <div class="text-white/60 text-[13px] mt-1.5">
          <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{summary[0].is_current ? '#4ade80' : '#cbd5e1'};"></span>{summary[0].tournament} · round {summary[0].latest_round} of 17
        </div>
      </div>
    </div>

    <div class="flex flex-col items-center xl:items-end gap-2">
      <div class="text-white/70 text-sm xl:text-base">
        <span class="font-semibold text-white">{summary[0].goals}</span> goals · <span class="font-semibold text-white">{summary[0].matches_played}</span> matches · <span class="font-semibold text-white">{summary[0].teams}</span> clubs
      </div>
      <!-- Top of the table is a SEEDING in Liga MX, never a title. Labelled
           accordingly: the champion is decided in the liguilla. -->
      <div class="inline-flex items-center gap-2 text-[15px]">
        <span class="leading-none">🥇</span>
        <span class="text-white/50 text-[11px] font-semibold uppercase" style="letter-spacing: 0.12em;">Top seed</span>
        <img src="{leader[0].top_seed_logo}" alt="" class="h-5 w-auto" onerror="this.style.display='none'" />
        <span class="text-white font-semibold">{leader[0].top_seed}</span>
      </div>
      <div class="text-white/40 text-[11px]">seeds the liguilla — the title is decided there</div>
    </div>
  </div>
</div>

## The season, in short

<div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-8">
  <div class="rounded-2xl border border-gray-200 p-4">
    <div class="text-[11px] uppercase text-gray-500" style="letter-spacing:0.1em;">Two titles a year</div>
    <div class="mt-1 text-sm text-gray-700">The <strong>Apertura</strong> (Jul–Dec) and <strong>Clausura</strong> (Jan–May) are separate competitions, each with its own table and champion.</div>
  </div>
  <div class="rounded-2xl border border-gray-200 p-4">
    <div class="text-[11px] uppercase text-gray-500" style="letter-spacing:0.1em;">17 rounds, everyone once</div>
    <div class="mt-1 text-sm text-gray-700">18 clubs, a single round-robin. Half the length of a European season, so form swings count double.</div>
  </div>
  <div class="rounded-2xl border border-gray-200 p-4">
    <div class="text-[11px] uppercase text-gray-500" style="letter-spacing:0.1em;">The liguilla decides it</div>
    <div class="mt-1 text-sm text-gray-700">Top six go through, 7th–10th play in. The table only seeds it — the top seed has won just <strong>6 of the last 12</strong> titles.</div>
  </div>
</div>

## Explore

<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
  <a href="/standings" class="block rounded-2xl border border-gray-200 p-5 hover:shadow-md transition" style="background:#fffbeb;">
    <div class="text-2xl">🏆</div>
    <div class="mt-2 font-semibold text-gray-900">Standings</div>
    <div class="text-sm text-gray-600">Apertura and Clausura tables, with liguilla and play-in places — and how far each club actually went.</div>
  </a>
</div>

<div class="mt-8 text-xs text-gray-500">Data refreshed {last_updated[0].last_updated}. More pages are on the way.</div>

<SiteFooter />
