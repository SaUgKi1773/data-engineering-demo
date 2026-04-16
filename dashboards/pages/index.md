---
title: Superligaen
---

```sql league
select * from superligaen.league_info
```

```sql kpis
select * from superligaen.kpis
```

```sql leader
select * from superligaen.current_leader
```

<div class="flex items-center justify-center gap-6 my-8 flex-wrap">
  <img src="{league[0].league_country_flag}" alt="Denmark" class="h-8 rounded shadow-md" />
  <img src="{league[0].league_logo}" alt="Superligaen" class="h-16" />
  <div class="text-center">
    <div class="text-4xl font-extrabold tracking-tight">Superligaen</div>
    <div class="text-gray-400 text-sm mt-1">Danish Football Premier League &middot; {kpis[0].season} Season</div>
  </div>
  <img src="{league[0].league_country_flag}" alt="Denmark" class="h-8 rounded shadow-md" />
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <BigValue data={kpis}   value=total_goals        title="Goals Scored"      />
  <BigValue data={leader} value=team_name           title="Current Leader"    />
  <BigValue data={kpis}   value=total_red_cards     title="Red Cards"         />
  <BigValue data={kpis}   value=avg_shots_per_match title="Avg Shots / Match" />
</div>

---

<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">

<a href="/standings" class="block no-underline rounded-xl border border-gray-700 bg-gray-900 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-800 transition-all duration-200 group">
  <div class="text-4xl">🏆</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Standings</div>
  <div class="text-gray-400 text-sm">Championship, Relegation &amp; Regular Season tables</div>
</a>

<a href="/match-results" class="block no-underline rounded-xl border border-gray-700 bg-gray-900 p-6 hover:border-blue-500 hover:shadow-lg hover:bg-gray-800 transition-all duration-200 group">
  <div class="text-4xl">⚽</div>
  <div class="text-lg font-bold mt-3 mb-1 group-hover:text-blue-400 transition-colors">Match Results</div>
  <div class="text-gray-400 text-sm">Full match history, results and scorelines by team</div>
</a>

</div>
