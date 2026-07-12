---
sidebar: never
hide_toc: true
full_width: true
title: Krogvad Analytics Hub — Football intelligence for the whole world
hide_title: true
description: Free, open football analytics platforms from Farum, Denmark. A dedicated home for every league, one shared data warehouse, refreshed every night.
---

```sql leagues
select
  *,
  case league_id
    when 271 then 'https://superligaanalytics.vercel.app/'
    when 501 then 'https://scottishpremiershipanalytics.vercel.app/'
  end as site_url,
  case league_id
    when 271 then 'Superligaen'
    when 501 then 'Premiership'
  end as banner_title,
  case league_id
    when 271 then 'linear-gradient(135deg, #4a0e18 0%, #a01325 45%, #d42a3d 100%)'
    when 501 then 'linear-gradient(135deg, #0a1f3c 0%, #123c78 45%, #1f6fd4 100%)'
  end as gradient
from hub.league_summary
order by league_id
```

```sql group_stats
select * from hub.group_stats
```

```sql last_updated
select * from hub.last_updated
```

<div class="max-w-5xl mx-auto px-1">

<!-- ══ HERO ══════════════════════════════════════════════════════════════ -->
<div class="relative rounded-3xl overflow-hidden mt-6 mb-14 shadow-xl" style="background: linear-gradient(150deg, #0b1220 0%, #0e1a30 55%, #12233f 100%);">
  <!-- pitch lines: the family watermark -->
  <div class="absolute inset-0 opacity-[0.05]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 90px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 90px);"></div>
  <div class="absolute -right-20 -top-20 w-96 h-96 rounded-full border border-white opacity-[0.05] pointer-events-none"></div>
  <div class="absolute -right-8 -top-8 w-64 h-64 rounded-full border border-white opacity-[0.05] pointer-events-none"></div>

  <div class="relative px-8 py-12 md:px-16 md:py-16">
    <div class="flex flex-wrap items-center gap-3 mb-6">
      <span class="text-white/40 text-[11px] font-bold uppercase" style="letter-spacing: 0.25em;">Krogvad Analytics Hub</span>
      <span class="inline-flex items-center gap-1.5 rounded-full border border-white/20 bg-white/5 px-3 py-1 text-white/60 text-[11px] font-semibold whitespace-nowrap">📍 Farum, Denmark</span>
    </div>
    <h1 class="text-4xl md:text-6xl font-extrabold tracking-tight text-white leading-[1.05] mb-5" style="margin-top:0;">Football intelligence,<br/>for the whole world.</h1>
    <p class="text-white/60 text-base md:text-lg max-w-2xl leading-relaxed mb-8">From beautiful Farum, we build football analytics platforms — a dedicated home for every league, each with its own identity, all powered by a single shared data warehouse. Every match, every goal, every transfer flows through the same modelled, tested pipeline, refreshed end-to-end every night while the town sleeps.</p>
    <div class="flex flex-wrap items-center gap-3">
      <a href="#platforms" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-white text-gray-900 text-sm font-bold no-underline hover:bg-gray-100 transition-colors">Explore our platforms <span class="text-gray-400">↓</span></a>
      <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl border border-white/25 text-white text-sm font-semibold no-underline hover:bg-white/10 transition-colors">Read the diary <span class="text-white/40">↗</span></a>
    </div>
  </div>
</div>

<!-- ══ OUR STORY ═════════════════════════════════════════════════════════ -->
<div class="mb-14">
  <div class="text-gray-400 text-[11px] font-bold uppercase mb-1" style="letter-spacing: 0.25em;">Our story</div>
  <h2 class="text-2xl md:text-3xl font-extrabold tracking-tight text-gray-900 mb-6" style="margin-top:0.25rem;">A small idea in a new home.</h2>
  <StoryPager labels={['The idea', 'The rule', 'The aim']}>
    <p class="text-gray-600 text-base md:text-lg max-w-3xl leading-relaxed mb-0" style="margin-top:0;">It started as a small idea in a new home. Our founder had just moved to Denmark — a lifelong football fan who suddenly knew nothing about the league playing twenty minutes down the road: the clubs, the players, the rivalries, how the season even worked. Learning it from league tables felt thin. So the idea took shape: <em class="text-gray-900 not-italic font-semibold">what if the Danish Superliga had the same data platform a serious company runs on?</em> Not a spreadsheet, not a toy — real live data, a properly modelled warehouse, a product you'd actually open on a Saturday before kick-off.</p>
    <p class="text-gray-600 text-base md:text-lg max-w-3xl leading-relaxed mb-0" style="margin-top:0;">One rule was set on day one: it had to be free — open-source tools only, nothing behind a credit card, so it could stay free for the people using it too. That discipline forced the platform to be built right, and building it right turned out to be the whole point: a warehouse done properly for one league is ready for any league. The small idea became a site, the site earned its first users, and the users pulled it into what it is today — a multi-league football analytics hub.</p>
    <p class="text-gray-600 text-base md:text-lg max-w-3xl leading-relaxed mb-0" style="margin-top:0;">Our aim hasn't changed since that day: bring warehouse-grade football analytics to every league in the world — open source, shaped by the people who use it, and free for everyone, forever.</p>
  </StoryPager>
</div>

<!-- ══ GROUP IN NUMBERS ══════════════════════════════════════════════════ -->
<div class="mb-14">
  <div class="text-gray-400 text-[11px] font-bold uppercase mb-1" style="letter-spacing: 0.25em;">The group in numbers</div>
  <h2 class="text-2xl md:text-3xl font-extrabold tracking-tight text-gray-900 mb-6" style="margin-top:0.25rem;">Numbers that update themselves.</h2>
  <div class="grid grid-cols-2 md:grid-cols-6 gap-px rounded-2xl overflow-hidden border border-gray-200 bg-gray-200">
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.leagues} duration={900} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Leagues covered</div>
    </div>
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.seasons} duration={1100} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Seasons modelled</div>
    </div>
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.matches} duration={1400} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Matches analysed</div>
    </div>
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.goals} duration={1600} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Goals recorded</div>
    </div>
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.players} duration={1400} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Players profiled</div>
    </div>
    <div class="bg-white px-5 py-6">
      <div class="text-3xl md:text-4xl font-extrabold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.transfers} duration={1800} /></div>
      <div class="text-gray-400 text-[11px] mt-2 uppercase tracking-widest">Transfers tracked</div>
    </div>
  </div>
</div>

<!-- ══ OUR PLATFORMS ═════════════════════════════════════════════════════ -->
<div id="platforms" class="mb-14">
  <div class="text-gray-400 text-[11px] font-bold uppercase mb-1" style="letter-spacing: 0.25em;">Our platforms</div>
  <h2 class="text-2xl md:text-3xl font-extrabold tracking-tight text-gray-900 mb-6" style="margin-top:0.25rem;">Purpose-built for each league.</h2>

  <div class="flex flex-col gap-5">
{#each leagues as lg}
    <a href="{lg.site_url}" class="block no-underline group">
      <div class="relative rounded-2xl overflow-hidden shadow-lg transition-transform duration-200 group-hover:scale-[1.01] group-hover:shadow-xl" style="background: {lg.gradient};">
        <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>

        <div class="relative px-6 py-6 md:px-9 md:py-7 flex flex-col md:flex-row items-center md:items-center justify-between gap-5">
          <div class="flex items-center gap-4 min-w-0">
            <div class="bg-white/10 backdrop-blur rounded-2xl p-2.5 shadow-inner flex-shrink-0">
              <img src="{lg.league_logo}" alt="{lg.league_name}" class="h-12 md:h-14 w-auto" onerror="this.style.display='none'" />
            </div>
            <div class="min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <img src="{lg.league_country_flag}" alt="{lg.league_country}" class="h-3.5 rounded opacity-90" onerror="this.style.display='none'" />
                <span class="text-white/50 text-[11px] uppercase tracking-widest">{lg.league_country}</span>
              </div>
              <div class="text-2xl md:text-3xl font-extrabold tracking-tight text-white leading-tight">{lg.banner_title}</div>
            </div>
          </div>

          <div class="flex items-center gap-3 flex-shrink-0">
            <div class="flex flex-col items-center md:items-end gap-2.5">
            <span class="rounded-full px-2.5 py-0.5 backdrop-blur inline-flex items-center gap-1.5 text-[10px] font-semibold whitespace-nowrap"
                  style="{new Date() > new Date(lg.season_end) ? 'background:rgba(100,116,139,0.25);border:1px solid rgba(148,163,184,0.3);color:rgb(203,213,225)' : 'background:rgba(74,222,128,0.2);border:1px solid rgba(74,222,128,0.3);color:rgb(134,239,172)'}">
              <span class="inline-block w-1 h-1 rounded-full" style="{new Date() > new Date(lg.season_end) ? 'background:rgb(148,163,184)' : 'background:rgb(74,222,128)'}"></span>
              {lg.season} · {new Date() > new Date(lg.season_end) ? 'Ended' : 'Live'}
            </span>
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
            </div>
            <div class="text-white/40 text-2xl font-light group-hover:text-white/80 group-hover:translate-x-0.5 transition-all duration-200">→</div>
          </div>
        </div>
      </div>
    </a>
{/each}

    <div class="rounded-2xl border-2 border-dashed border-gray-200 px-6 py-5 flex items-center gap-3">
      <span class="text-gray-300 text-[10px] font-bold uppercase flex-shrink-0" style="letter-spacing: 0.2em;">Next platform</span>
      <span class="text-gray-400 text-sm">In scouting — wherever in the world the next league plays, the foundation is ready.</span>
    </div>
  </div>
</div>

<!-- ══ WHAT WE STAND FOR ═════════════════════════════════════════════════ -->
<div class="mb-14">
  <div class="text-gray-400 text-[11px] font-bold uppercase mb-1" style="letter-spacing: 0.25em;">What we stand for</div>
  <h2 class="text-2xl md:text-3xl font-extrabold tracking-tight text-gray-900 mb-6" style="margin-top:0.25rem;">The principles the group is built on.</h2>
  <div class="grid md:grid-cols-3 gap-4">
    <div class="rounded-2xl border border-gray-200 px-6 py-6">
      <div class="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center text-xl mb-3">🛡️</div>
      <div class="font-bold text-gray-900 mb-1.5">Trust every number</div>
      <div class="text-gray-500 text-sm leading-relaxed">More than 125 automated quality checks run on every refresh. If one fails, the pipeline stops — a wrong number never reaches a page.</div>
    </div>
    <div class="rounded-2xl border border-gray-200 px-6 py-6">
      <div class="w-10 h-10 rounded-xl bg-green-50 flex items-center justify-center text-xl mb-3">🤝</div>
      <div class="font-bold text-gray-900 mb-1.5">Free means free</div>
      <div class="text-gray-500 text-sm leading-relaxed">The platform costs nothing to run and nothing to use. No ads, no accounts, no paywall — that's a founding rule, not a launch offer.</div>
    </div>
    <div class="rounded-2xl border border-gray-200 px-6 py-6">
      <div class="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center text-xl mb-3">🔓</div>
      <div class="font-bold text-gray-900 mb-1.5">Built in the open</div>
      <div class="text-gray-500 text-sm leading-relaxed">Every line of code is public on GitHub, and users shape the roadmap — our Scottish platform exists because one of them asked for it.</div>
    </div>
  </div>
</div>

<!-- ══ FOOTER ════════════════════════════════════════════════════════════ -->
<div class="border-t border-gray-100 pt-8 pb-12 text-center">
  <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 mb-4">
    <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">GitHub</a>
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">Data Engineer's Diary</a>
    <a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">LinkedIn</a>
    <a href="https://revolut.me/salihugurkimilli" target="_blank" class="text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">Support via Revolut</a>
    <a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new/choose" target="_blank" class="text-sm font-semibold text-gray-600 hover:text-gray-900 no-underline">Share a Suggestion</a>
  </div>
  <p class="text-gray-500 text-sm font-medium mb-2">Built in beautiful Farum, Denmark — free for the whole world, forever.</p>
  <p class="text-gray-400 text-xs mb-0">© 2026 Krogvad Analytics Hub · Data updated {last_updated[0].last_updated?.slice(0, 16).replace('T', ' ')} UTC</p>
</div>

</div>
