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
    when 271    then 'https://superligaanalytics.vercel.app/'
    when 501    then 'https://scottishpremiershipanalytics.vercel.app/'
    when 223746 then 'https://mexicanligamxanalytics.vercel.app/'
    when 173537 then 'https://turkishsuperliganalytics.vercel.app/'
    when 119924 then 'https://spanishlaligaanalytics.vercel.app/'
  end as site_url,
  case league_id
    when 271    then 'Superligaen'
    when 501    then 'Premiership'
    when 223746 then 'Liga MX'
    when 173537 then 'Süper Lig'
    when 119924 then 'La Liga'
  end as banner_title,
  -- The order the platforms launched in. league_id is the provider's id, and
  -- sorting on it would slot each new league wherever its id happens to fall
  -- rather than at the end of the shelf.
  case league_id
    when 271    then 1
    when 501    then 2
    when 223746 then 3
    when 173537 then 4
    when 119924 then 5
  end as launch_order
from hub.league_summary
order by launch_order
```

```sql group_stats
select * from hub.group_stats
```

```sql crossleague
select * from hub.crossleague_summary
```


```sql last_updated
select * from hub.last_updated
```

<div class="max-w-5xl mx-auto px-1" style="font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">

<!-- ══ HERO — copy stacked over the spinning globe ═══════════════════════ -->
<div class="pt-12 pb-14 md:pt-20 md:pb-20">
  <!-- Centred at every width, like the Our Story and Group in Numbers bands
       below and like the hero already was on mobile. -->
  <div class="text-center">
    <div class="text-gray-400 text-xs font-semibold uppercase" style="letter-spacing: 0.14em;">Krogvad Analytics Hub</div>
    <h1 class="text-4xl lg:text-5xl font-bold tracking-tight text-gray-900 leading-[1.08] mb-0" style="margin-top:0.9rem;">Football intelligence, for the whole world.</h1>
    <!-- Capped: the copy no longer shares a row with the globe, and a paragraph
         running the full width of the page would read as a wall. -->
    <p class="text-gray-500 text-base md:text-lg max-w-xl mx-auto leading-relaxed mb-8" style="margin-top:1.75rem;">From beautiful Farum, Denmark, we build a dedicated analytics home for every league — each with its own identity, all powered by one shared data warehouse, refreshed every night. Free for everyone, forever.</p>
    <div class="flex flex-wrap items-center justify-center gap-x-7 gap-y-4">
      <a href="#platforms" class="inline-block rounded-full px-6 py-2.5 text-[15px] font-medium text-white no-underline transition-opacity hover:opacity-90" style="background:#c8102e;">Explore our platforms</a>
      <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-1.5 text-[15px] font-medium text-gray-900 no-underline hover:underline">Behind the build <span style="color:#c8102e;">›</span></a>
    </div>
  </div>
  <!-- Below the copy on every width now, which is the order mobile already
       had. Centred, since nothing sits beside it to anchor it left. -->
  <div class="mx-auto w-full mt-12 md:mt-14" style="max-width: 22rem;">
    <Globe />
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
<!-- scroll-margin clears the fixed 3rem header so the heading isn't hidden on #platforms -->
<div id="platforms" class="mb-14 text-center" style="scroll-margin-top: 4.5rem;">
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
              <span class="inline-block w-1.5 h-1.5 rounded-full align-middle mr-1.5" style="background:{lg.season_is_live ? '#30b14e' : '#a1a1a6'};"></span>{lg.season} · {lg.season_is_live ? 'Live' : 'Ended'}
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

    <!-- Not a league card: no flag, no season, no club count. The five hues
         along the top are the ones the site itself uses for the five leagues. -->
    <a href="https://crossleagueanalytics.vercel.app/" class="block no-underline group">
      <div class="overflow-hidden rounded-2xl" style="background:#f5f5f7;">
        <div class="flex h-1.5 w-full">
          <span class="flex-1" style="background:#eda100;"></span>
          <span class="flex-1" style="background:#1baf7a;"></span>
          <span class="flex-1" style="background:#eb6834;"></span>
          <span class="flex-1" style="background:#e87ba4;"></span>
          <span class="flex-1" style="background:#2a78d6;"></span>
        </div>
        <div class="px-6 py-8 md:px-10 md:py-8 text-center md:text-left flex flex-col md:flex-row items-center md:justify-between gap-4 md:gap-6 transition-transform duration-200 group-hover:scale-[1.005]">
          <div class="flex flex-col md:flex-row items-center gap-3 md:gap-5">
            <img src="/logos/crossleague.svg" alt="Cross-League Analytics" class="h-14 w-auto flex-shrink-0" />
            <div>
              <div class="text-3xl md:text-4xl font-bold tracking-tight text-gray-900 leading-none">Cross-League Analytics</div>
            </div>
          </div>
          <div class="flex flex-col items-center md:items-end gap-2">
            <div class="text-gray-500 text-sm"><span class="font-semibold text-gray-900">{crossleague[0]?.leagues}</span> leagues · <span class="font-semibold text-gray-900">{crossleague[0]?.matches}</span> matches · <span class="font-semibold text-gray-900">{crossleague[0]?.goals}</span> goals</div>
            <div class="text-[15px] font-medium text-gray-900">Explore Cross-League <span style="color:#c8102e;">›</span></div>
          </div>
        </div>
      </div>
    </a>

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

<!-- ══ BUILD WITH US — bordered cards, so it does not read as a second gray band ══ -->
<div class="mb-14 text-center">
  <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">Build with us</div>
  <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-4" style="margin-top:0.25rem;">There is room for you here.</h2>
  <p class="text-gray-500 text-base max-w-2xl mx-auto leading-relaxed mb-9">Every platform in the group is free to use and built in the open, and we are looking for people who want to build the next one with us. This is volunteer work — there is no salary. What there is: real production data, a live product with real users, and public work you can put your name on.</p>

  <div class="grid md:grid-cols-2 gap-4 max-w-4xl mx-auto text-left mb-9">
    <div class="rounded-2xl border border-gray-200 px-6 py-5">
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 19V11M10 19V5M15 19v-6M20 19v-9"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">BI Developer</div>
      <div class="text-gray-500 text-sm leading-relaxed">New analytics pages — SQL against the gold layer, charts and components in Evidence.</div>
    </div>
    <div class="rounded-2xl border border-gray-200 px-6 py-5">
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20l4-1 9.5-9.5a2.1 2.1 0 0 0-3-3L5 16l-1 4z"/><path d="M13.5 6.5l4 4"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">UI / UX Designer</div>
      <div class="text-gray-500 text-sm leading-relaxed">How the platforms look, read and feel — on a phone every bit as much as on a laptop.</div>
    </div>
    <div class="rounded-2xl border border-gray-200 px-6 py-5">
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 6h16M4 12h10M4 18h13"/><circle cx="18" cy="12" r="2"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">Product Manager</div>
      <div class="text-gray-500 text-sm leading-relaxed">What gets built next, and why — turning what users ask for into a roadmap.</div>
    </div>
    <div class="rounded-2xl border border-gray-200 px-6 py-5">
      <svg viewBox="0 0 24 24" class="w-7 h-7" fill="none" stroke="#1d1d1f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6"/><path d="M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/></svg>
      <div class="font-semibold text-gray-900 mt-4 mb-1.5">Data Engineer</div>
      <div class="text-gray-500 text-sm leading-relaxed">New leagues and new sources, from ingestion all the way through bronze, silver and gold.</div>
    </div>
  </div>

  <a href="https://forms.gle/vPCoCNZvehu5yyze8" target="_blank" rel="noreferrer" class="inline-flex items-center gap-2 rounded-full bg-gray-900 px-6 py-3 text-sm font-semibold text-white no-underline transition-colors hover:bg-gray-700">Tell us what you'd want to build</a>
  <p class="text-gray-400 text-xs mt-3 mb-0">Not on the list? Say so on the form — if you can move the platform forward, we want to hear it.</p>
</div>

<!-- ══ GALLERY — photos from the group ═══════════════════════════════════ -->
<!-- The component owns the whole section, heading included, so it can render
     nothing at all until there are photos. An empty gallery on a marketing
     page reads as broken, which is the opposite of the point. -->
<Gallery />

<!-- ══ FOOTER ════════════════════════════════════════════════════════════ -->
<div class="border-t border-gray-200 pt-8 pb-12 text-center">
  <!-- Two tiers: the three things we want clicked, then the about-and-support
       set in a lighter weight. Seven links at one size read as a wall. -->
  <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 mb-2.5">
    <a href="https://forms.gle/vPCoCNZvehu5yyze8" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Build with us</a>
    <a href="https://forms.gle/2wDZcfwm8jk6aWGS9" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Request Data Access</a>
    <a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new?template=suggestion.md" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Share a Suggestion</a>
  </div>
  <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5 mb-4">
    <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">GitHub</a>
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">Blog</a>
    <a href="https://revolut.me/salihugurkimilli" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">Revolut</a>
    <a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">LinkedIn</a>
  </div>
  <p class="text-gray-500 text-sm mb-2">Built in beautiful Farum, Denmark — free for the whole world, forever.</p>
  <p class="text-gray-400 text-xs mb-0">© 2026 Krogvad Analytics Hub · Data updated {last_updated[0]?.last_updated?.slice(0, 16).replace('T', ' ') ?? '–'} UTC</p>
</div>

</div>
