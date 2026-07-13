---
sidebar: never
hide_toc: true
title: Prediction Module
---

```sql scoreboard
select * from superligaen.mart_prediction_scoreboard
```

```sql timeline
select
    match_date,
    model_hit_pct    as "Model",
    baseline_hit_pct as "Home-win baseline"
from superligaen.mart_prediction_timeline
where cum_matches > 0
order by match_date asc
```

```sql log
select *
from superligaen.mart_prediction_log
where home_team is not null
order by match_date desc
```

## Prediction Module — Model vs Reality

<p style="font-size:0.8125rem;color:#6b7280;margin:0 0 1.5rem 0;">Before every fixture, our data science team's match model publishes win, draw and loss probabilities. This page keeps the receipts: every prediction is frozen before kickoff, never edited afterwards, and scored here against what actually happened — compared to the naive baseline of always picking the home team.</p>

{#if scoreboard[0].matches_scored > 0}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div class="rounded-xl border border-gray-200 bg-white p-4 text-center">
    <div class="text-3xl font-black text-gray-800">{scoreboard[0].matches_scored}</div>
    <div class="text-xs text-gray-400 mt-1 font-semibold uppercase tracking-wide">Matches Scored</div>
  </div>
  <div class="rounded-xl border border-indigo-200 bg-indigo-50 p-4 text-center">
    <div class="text-3xl font-black text-indigo-600">{scoreboard[0].model_hit_pct}%</div>
    <div class="text-xs text-indigo-400 mt-1 font-semibold uppercase tracking-wide">Model Hit Rate</div>
  </div>
  <div class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-center">
    <div class="text-3xl font-black text-amber-600">{scoreboard[0].baseline_hit_pct}%</div>
    <div class="text-xs text-amber-500 mt-1 font-semibold uppercase tracking-wide">Home-Win Baseline</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 text-center">
    <div class="text-3xl font-black text-gray-800">{scoreboard[0].avg_prob_on_result_pct}%</div>
    <div class="text-xs text-gray-400 mt-1 font-semibold uppercase tracking-wide">Avg. Probability on Actual Result</div>
  </div>
</div>

### Hit Rate Over Time

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Cumulative share of matches where the most likely predicted outcome actually happened, next to the always-pick-the-home-team baseline.</p>

<LineChart
    data={timeline}
    x=match_date
    y={['Model', 'Home-win baseline']}
    colorPalette={['#6366f1', '#d97706']}
    yFmt='#,##0.0"%"'
    yMin=0
    yMax=100
    yAxisTitle="Cumulative hit rate"
    chartAreaHeight=280
/>

### Every Prediction, Scored

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The full record — every fixture the model predicted before kickoff and how it turned out. Nothing is removed or restated.</p>

```sql log_display
select
    strftime(match_date, '%Y-%m-%d')   as "Date",
    match_name                          as "Match",
    score                               as "Score",
    home_pct                            as "Home %",
    draw_pct                            as "Draw %",
    away_pct                            as "Away %",
    model_pick                          as "Model Pick",
    actual_result                       as "Result",
    case when hit
         then '<span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-green-500 text-white">✓</span>'
         else '<span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-red-500 text-white">✗</span>'
    end                                 as "Hit"
from ${log}
order by match_date desc
```

<DataTable data={log_display} rows=15 search=true>
    <Column id="Date"       />
    <Column id="Match"      />
    <Column id="Score"      align=center />
    <Column id="Home %"     align=center />
    <Column id="Draw %"     align=center />
    <Column id="Away %"     align=center />
    <Column id="Model Pick" align=center />
    <Column id="Result"     align=center />
    <Column id="Hit"        contentType=html align=center />
</DataTable>

{:else}

<div class="flex flex-col items-center justify-center py-24 text-center">
  <div class="text-5xl mb-4">🔮</div>
  <div class="text-xl font-bold text-gray-700 mb-2">The Track Record Starts Soon</div>
  <div class="text-gray-400 text-sm max-w-md">
    {#if scoreboard[0].pending_predictions > 0}
      {scoreboard[0].pending_predictions} predictions are already on the books, frozen before kickoff. The first verdicts land after the opening fixtures on {scoreboard[0].first_kickoff} — from then on, every prediction is scored here against reality.
    {:else}
      No fixtures are on the prediction books yet. As soon as the schedule is announced, the model publishes its probabilities — and this page starts keeping score.
    {/if}
  </div>
</div>

{/if}

<p style="font-size:0.6875rem;color:#9ca3af;margin:2rem 0 0 0;">How it works: probabilities come from a Poisson goals model fitted on the last two seasons of results. Predictions refresh nightly until three hours before kickoff, then freeze — nothing is ever predicted or revised after a match has started. The model's pick is its highest-probability outcome; a hit means that outcome happened.</p>
