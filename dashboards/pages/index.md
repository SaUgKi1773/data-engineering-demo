---
title: Superligaen
---

```sql league
select * from superligaen.league_info
```

```sql extended_kpis
select
    count(*)                            as total_matches,
    sum(total_goals)                    as total_goals,
    round(avg(total_goals), 2)          as avg_goals_per_match,
    round(avg(total_xg), 2)             as avg_xg_per_match,
    sum(total_yellow_cards)             as total_yellow_cards,
    sum(total_red_cards)                as total_red_cards,
    round(avg(total_shots_on_goal), 1)  as avg_shots_on_goal,
    max(season)                         as season
from superligaen.match_results_by_match
where season = (select max(season) from superligaen.match_results_by_match)
```

```sql leader
select * from superligaen.current_leader
```

<div class="rounded-2xl border border-gray-300 bg-gray-100 p-8 mb-6">
  <div class="flex items-center justify-center gap-6 flex-wrap">
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-10 rounded shadow-lg" />
    <div class="bg-white rounded-2xl p-3 shadow-lg">
      <img src="{league[0].league_logo}" alt="Superligaen" class="h-16" />
    </div>
    <div class="text-center">
      <div class="text-5xl font-extrabold tracking-tight text-gray-800">Superligaen</div>
      <div class="text-gray-500 text-base mt-2">Danish Football Premier League &middot; {extended_kpis[0].season} Season</div>
    </div>
    <img src="{league[0].league_country_flag}" alt="Denmark" class="h-10 rounded shadow-lg" />
  </div>
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=total_matches       title="Matches Played"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=total_goals         title="Goals Scored"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=avg_goals_per_match title="Avg Goals / Match" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={leader}        value=team_name           title="Current Leader"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=avg_xg_per_match    title="Avg xG / Match"    /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=avg_shots_on_goal   title="Avg Shots on Goal" /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=total_yellow_cards  title="Yellow Cards"      /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4"><BigValue data={extended_kpis} value=total_red_cards     title="Red Cards"         /></div>
</div>

<div class="grid grid-cols-1 md:grid-cols-3 gap-4">

<a href="/standings" class="block no-underline rounded-xl border border-gray-300 bg-gray-100 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-200 transition-all duration-200 group">
  <div class="text-4xl">🏆</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Standings</div>
  <div class="text-gray-400 text-sm">Championship, Relegation &amp; Regular Season tables</div>
</a>

<a href="/match-results" class="block no-underline rounded-xl border border-gray-300 bg-gray-100 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-200 transition-all duration-200 group">
  <div class="text-4xl">⚽</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Match Results</div>
  <div class="text-gray-400 text-sm">Full match history, scorelines and analytics by round</div>
</a>

<a href="/team-analytics" class="block no-underline rounded-xl border border-gray-300 bg-gray-100 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-200 transition-all duration-200 group">
  <div class="text-4xl">📊</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Team Analytics</div>
  <div class="text-gray-400 text-sm">Deep-dive KPIs, form, shooting accuracy &amp; discipline</div>
</a>

<a href="/upcoming-matches" class="block no-underline rounded-xl border border-gray-300 bg-gray-100 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-200 transition-all duration-200 group">
  <div class="text-4xl">📅</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Upcoming Fixtures</div>
  <div class="text-gray-400 text-sm">Head-to-head history &amp; form guide for upcoming matches</div>
</a>

</div>

