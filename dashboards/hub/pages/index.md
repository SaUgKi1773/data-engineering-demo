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
  end as banner_title
from hub.league_summary
order by league_id
```

```sql group_stats
select * from hub.group_stats
```

```sql last_updated
select * from hub.last_updated
```

<div class="max-w-5xl mx-auto px-1" style="font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

<!-- ══ HERO — centered on white ══════════════════════════════════════════ -->
<div class="text-center pt-16 pb-16 md:pt-24 md:pb-20">
  <div class="text-gray-400 text-xs font-semibold uppercase" style="letter-spacing: 0.14em;">Krogvad Analytics Hub</div>
  <h1 class="text-4xl md:text-6xl font-bold tracking-tight text-gray-900 leading-[1.06] mb-5" style="margin-top:0.9rem;">Football intelligence,<br/>for the whole world.</h1>
  <p class="text-gray-500 text-base md:text-lg max-w-xl mx-auto leading-relaxed mb-8">From beautiful Farum, Denmark, we build a dedicated analytics home for every league — each with its own identity, all powered by one shared data warehouse, refreshed every night. Free for everyone, forever.</p>
  <div class="flex flex-wrap items-center justify-center gap-x-7 gap-y-4">
    <a href="#platforms" class="inline-block rounded-full px-6 py-2.5 text-[15px] font-medium text-white no-underline transition-opacity hover:opacity-90" style="background:#c8102e;">Explore our platforms</a>
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-1.5 text-[15px] font-medium text-gray-900 no-underline hover:underline">Behind the build <span style="color:#c8102e;">›</span></a>
  </div>
</div>

<!-- ══ OUR STORY — gray band ═════════════════════════════════════════════ -->
<div class="rounded-3xl px-6 py-12 md:px-14 md:py-14 mb-14 text-center" style="background:#f5f5f7;">
  <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">Our story</div>
  <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-7" style="margin-top:0.25rem;">A small idea in a new home.</h2>
  <div class="max-w-3xl mx-auto text-left">
    <StoryPager labels={['The idea', 'The rule', 'The aim']}>
      <p class="text-gray-500 text-base md:text-lg leading-relaxed mb-0" style="margin-top:0;">It started as a small idea in a new home. Our founder had just moved to Denmark — a lifelong football fan who suddenly knew nothing about the league playing twenty minutes down the road: the clubs, the players, the rivalries, how the season even worked. Learning it from league tables felt thin. So the idea took shape: <em class="text-gray-900 not-italic font-semibold">what if the Danish Superliga had the same data platform a serious company runs on?</em> Not a spreadsheet, not a toy — real live data, a properly modelled warehouse, a product you'd actually open on a Saturday before kick-off.</p>
      <p class="text-gray-500 text-base md:text-lg leading-relaxed mb-0" style="margin-top:0;">One rule was set on day one: it had to be free — open-source tools only, nothing behind a credit card, so it could stay free for the people using it too. That discipline forced the platform to be built right, and building it right turned out to be the whole point: a warehouse done properly for one league is ready for any league. The small idea became a site, the site earned its first users, and the users pulled it into what it is today — a multi-league football analytics hub.</p>
      <p class="text-gray-500 text-base md:text-lg leading-relaxed mb-0" style="margin-top:0;">Our aim hasn't changed since that day: bring warehouse-grade football analytics to every league in the world — open source, shaped by the people who use it, and free for everyone, forever.</p>
    </StoryPager>
  </div>
</div>

<!-- ══ GROUP IN NUMBERS — centered on white ══════════════════════════════ -->
<div class="mb-14 text-center">
  <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">The group in numbers</div>
  <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-9" style="margin-top:0.25rem;">Numbers that update themselves.</h2>
  <div class="border-t border-b border-gray-200 py-9 md:py-10 grid grid-cols-3 md:grid-cols-6 gap-x-4 gap-y-9 max-w-4xl mx-auto">
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.leagues} duration={900} /></div>
      <div class="text-gray-400 text-xs mt-2">Leagues covered</div>
    </div>
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.seasons} duration={1100} /></div>
      <div class="text-gray-400 text-xs mt-2">Seasons modelled</div>
    </div>
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.matches} duration={1400} /></div>
      <div class="text-gray-400 text-xs mt-2">Matches analysed</div>
    </div>
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.goals} duration={1600} /></div>
      <div class="text-gray-400 text-xs mt-2">Goals recorded</div>
    </div>
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.players} duration={1400} /></div>
      <div class="text-gray-400 text-xs mt-2">Players profiled</div>
    </div>
    <div>
      <div class="text-3xl md:text-4xl font-semibold text-gray-900 leading-none tabular-nums"><CountUp value={group_stats[0]?.transfers} duration={1800} /></div>
      <div class="text-gray-400 text-xs mt-2">Transfers tracked</div>
    </div>
  </div>
</div>

<!-- ══ OUR PLATFORMS — gray product tiles ════════════════════════════════ -->
<div id="platforms" class="mb-14 text-center">
  <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">Our platforms</div>
  <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-6" style="margin-top:0.25rem;">Purpose-built for each league.</h2>

  <div class="flex flex-col gap-4">
{#each leagues as lg}
    <a href="{lg.site_url}" class="block no-underline group">
      <!-- mobile: centered stack · desktop: compact horizontal row -->
      <div class="rounded-2xl px-6 py-8 md:px-10 md:py-8 text-center md:text-left flex flex-col md:flex-row items-center md:justify-between gap-4 md:gap-6 transition-transform duration-200 group-hover:scale-[1.005]" style="background:#f5f5f7;">
        <!-- left: league identity -->
        <div class="flex flex-col md:flex-row items-center md:items-center gap-3 md:gap-5">
          <img src="{lg.league_logo}" alt="{lg.league_name}" class="h-14 md:h-14 w-auto flex-shrink-0" onerror="this.style.display='none'" />
          <div>
            <div class="flex items-center justify-center md:justify-start gap-2 mb-1">
              <img src="{lg.league_country_flag}" alt="{lg.league_country}" class="h-3.5 rounded" onerror="this.style.display='none'" />
              <span class="text-gray-400 text-[11px] uppercase" style="letter-spacing: 0.14em;">{lg.league_country}</span>
            </div>
            <div class="text-3xl md:text-4xl font-bold tracking-tight text-gray-900 leading-none">{lg.banner_title}</div>
            <div class="text-gray-400 text-[13px] mt-1.5">
              <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{new Date() > new Date(lg.season_end) ? '#a1a1a6' : '#30b14e'};"></span>{lg.season} · {new Date() > new Date(lg.season_end) ? 'Ended' : 'Live'}
            </div>
          </div>
        </div>
        <!-- right: stats + explore CTA -->
        <div class="flex flex-col items-center md:items-end gap-2">
          <div class="text-gray-500 text-sm"><span class="font-semibold text-gray-900">{lg.total_goals}</span> goals · <span class="font-semibold text-gray-900">{lg.total_matches}</span> matches · <span class="font-semibold text-gray-900">{lg.total_teams}</span> teams</div>
          <div class="text-[15px] font-medium text-gray-900">Explore {lg.banner_title} <span style="color:#c8102e;">›</span></div>
        </div>
      </div>
    </a>
{/each}

    <div class="rounded-2xl border border-dashed border-gray-300 px-6 py-5 text-center text-gray-400 text-sm">
      Next platform in scouting — wherever in the world the next league plays, the foundation is ready.
    </div>
  </div>
</div>

<!-- ══ WHAT WE STAND FOR — gray band ═════════════════════════════════════ -->
<div class="rounded-3xl px-6 py-12 md:px-14 md:py-14 mb-14" style="background:#f5f5f7;">
  <div class="text-center">
    <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">What we stand for</div>
    <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-9" style="margin-top:0.25rem;">The principles the group is built on.</h2>
  </div>
  <div class="grid md:grid-cols-3 gap-x-8 gap-y-10 max-w-4xl mx-auto text-left">
    <div>
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6l7-3z"/><path d="M9 12l2 2 4-4"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">Trust every number</div>
      <div class="text-gray-500 text-sm leading-relaxed">More than 125 automated quality checks run on every refresh. If one fails, the pipeline stops — a wrong number never reaches a page.</div>
    </div>
    <div>
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12h8M12 8v8"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">Free means free</div>
      <div class="text-gray-500 text-sm leading-relaxed">The platform costs nothing to run and nothing to use. No ads, no accounts, no paywall — that's a founding rule, not a launch offer.</div>
    </div>
    <div>
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 7.5-2"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">Built in the open</div>
      <div class="text-gray-500 text-sm leading-relaxed">Every line of code is public on GitHub, and users shape the roadmap — our Scottish platform exists because one of them asked for it.</div>
    </div>
  </div>
</div>

<!-- ══ FOOTER ════════════════════════════════════════════════════════════ -->
<div class="border-t border-gray-200 pt-8 pb-12 text-center">
  <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 mb-4">
    <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">GitHub</a>
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Data Engineer's Diary</a>
    <a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">LinkedIn</a>
    <a href="https://revolut.me/salihugurkimilli" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Support via Revolut</a>
    <a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new/choose" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Share a Suggestion</a>
  </div>
  <p class="text-gray-500 text-sm mb-2">Built in beautiful Farum, Denmark — free for the whole world, forever.</p>
  <p class="text-gray-400 text-xs mb-0">© 2026 Krogvad Analytics Hub · Data updated {last_updated[0].last_updated?.slice(0, 16).replace('T', ' ')} UTC</p>
</div>

</div>
