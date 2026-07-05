---
sidebar: never
hide_toc: true
full_width: true
title: " "
---

```sql leagues
select
  *,
  case league_id
    when 271 then 'https://superligaanalytics.vercel.app/'
    when 501 then 'https://scottishpremiershipanalytics.vercel.app/'
  end as site_url,
  case league_id
    when 271 then 'Superliga Analytics'
    when 501 then 'Scottish Premiership Analytics'
  end as site_name,
  case league_id
    when 271 then 'linear-gradient(135deg, #4a0e18 0%, #a01325 45%, #d42a3d 100%)'
    when 501 then 'linear-gradient(135deg, #0a1f3c 0%, #123c78 45%, #1f6fd4 100%)'
  end as gradient
from hub.league_summary
order by league_id
```

```sql last_updated
select * from hub.last_updated
```

<div class="max-w-3xl mx-auto">

<!-- ── Hub hero ─────────────────────────────────────────────────────────── -->
<div class="text-center pt-10 pb-8">
  <img src="/icon.svg" alt="Krogvad Analytics" class="inline-block w-16 h-16 rounded-2xl mb-4 shadow-lg" />
  <h1 class="text-4xl md:text-5xl font-extrabold tracking-tight mb-2" style="margin:0;">Krogvad Analytics</h1>
  <p class="text-gray-500 text-sm md:text-base mt-2 mb-0">Football intelligence, league by league — free, open, rebuilt nightly.</p>
</div>

<!-- ── League cards ─────────────────────────────────────────────────────── -->
<div class="flex flex-col gap-5 mb-10">
{#each leagues as lg}
  <a href="{lg.site_url}" class="block no-underline group">
    <div class="relative rounded-2xl overflow-hidden shadow-lg transition-transform duration-200 group-hover:scale-[1.01] group-hover:shadow-xl" style="background: {lg.gradient};">
      <!-- pitch lines overlay -->
      <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>

      <div class="relative px-6 py-6 md:px-9 md:py-7 flex flex-col md:flex-row items-center md:items-center justify-between gap-5">
        <!-- left: league identity -->
        <div class="flex items-center gap-4 min-w-0">
          <div class="bg-white/10 backdrop-blur rounded-2xl p-2.5 shadow-inner flex-shrink-0">
            <img src="{lg.league_logo}" alt="{lg.league_name}" class="h-12 md:h-14 w-auto" onerror="this.style.display='none'" />
          </div>
          <div class="min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <img src="{lg.league_country_flag}" alt="{lg.league_country}" class="h-3.5 rounded opacity-90" onerror="this.style.display='none'" />
              <span class="text-white/50 text-[11px] uppercase tracking-widest">{lg.league_country}</span>
              <!-- season status chip -->
              <span class="rounded-full px-2.5 py-0.5 backdrop-blur inline-flex items-center gap-1.5 text-[10px] font-semibold whitespace-nowrap"
                    style="{new Date() > new Date(lg.season_end) ? 'background:rgba(100,116,139,0.25);border:1px solid rgba(148,163,184,0.3);color:rgb(203,213,225)' : 'background:rgba(74,222,128,0.2);border:1px solid rgba(74,222,128,0.3);color:rgb(134,239,172)'}">
                <span class="inline-block w-1 h-1 rounded-full" style="{new Date() > new Date(lg.season_end) ? 'background:rgb(148,163,184)' : 'background:rgb(74,222,128)'}"></span>
                {lg.season} · {new Date() > new Date(lg.season_end) ? 'Ended' : 'Live'}
              </span>
            </div>
            <div class="text-2xl md:text-3xl font-extrabold tracking-tight text-white leading-tight">{lg.site_name}</div>
            <div class="text-white/60 text-xs mt-1.5 flex items-center gap-1.5">
              <span class="text-sm leading-none">{new Date() > new Date(lg.season_end) ? '👑' : '🥇'}</span>
              <span class="text-[10px] font-bold uppercase tracking-widest text-white/40">{new Date() > new Date(lg.season_end) ? 'Champion' : 'Leader'}</span>
              <span class="text-xs font-black text-white">{lg.leader_name}</span>
              <span class="text-white/40 text-[11px]">· {lg.leader_pts} pts</span>
            </div>
          </div>
        </div>

        <!-- right: KPI tiles + enter affordance -->
        <div class="flex items-center gap-3 flex-shrink-0">
          <div class="flex gap-2.5">
            <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-3.5 py-2.5 text-center min-w-[72px]">
              <div class="text-white text-lg font-black leading-none">{lg.total_goals}</div>
              <div class="text-white/50 text-[10px] mt-1 uppercase tracking-wide">Goals</div>
            </div>
            <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-3.5 py-2.5 text-center min-w-[72px]">
              <div class="text-white text-lg font-black leading-none">{lg.total_matches}</div>
              <div class="text-white/50 text-[10px] mt-1 uppercase tracking-wide">Matches</div>
            </div>
            <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-3.5 py-2.5 text-center min-w-[72px]">
              <div class="text-white text-lg font-black leading-none">{lg.total_teams}</div>
              <div class="text-white/50 text-[10px] mt-1 uppercase tracking-wide">Teams</div>
            </div>
          </div>
          <div class="text-white/40 text-2xl font-light group-hover:text-white/80 group-hover:translate-x-0.5 transition-all duration-200">→</div>
        </div>
      </div>
    </div>
  </a>
{/each}

  <!-- more leagues coming -->
  <div class="rounded-2xl border-2 border-dashed border-gray-200 px-6 py-5 flex items-center justify-center gap-3">
    <span class="text-xl opacity-40">⚽</span>
    <span class="text-gray-400 text-sm">More leagues on the way — built on the same pipeline, one league at a time.</span>
  </div>
</div>

<!-- ── Footer ───────────────────────────────────────────────────────────── -->
<div class="text-center pb-10">
  <div class="flex items-center justify-center gap-4 mb-3">
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-1.5 text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">📖 Data Engineer's Diary</a>
    <span class="text-gray-300">·</span>
    <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="inline-flex items-center gap-1.5 text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">GitHub</a>
  </div>
  <p class="text-gray-400 text-xs mb-0">Data updated {last_updated[0].last_updated?.slice(0, 16).replace('T', ' ')} UTC</p>
</div>

</div>
