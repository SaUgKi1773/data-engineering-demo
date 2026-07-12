---
sidebar: never
hide_toc: true
title: Prediction Tracker
---

```sql scored
select
    match_id,
    strftime(match_date, '%Y-%m-%d')  as match_date,
    strftime(match_date, '%d %b %Y')  as match_day,
    season,
    round,
    match_round_number,
    home_team_short,
    away_team_short,
    home_team_logo,
    away_team_logo,
    home_goals,
    away_goals,
    home_team_short || ' ' || home_goals || ' - ' || away_goals || ' ' || away_team_short as score_line,
    actual_outcome,
    predicted_outcome,
    is_correct,
    home_win_prob,
    draw_prob,
    away_win_prob,
    case predicted_outcome
        when 'Home' then home_win_prob
        when 'Away' then away_win_prob
        else draw_prob
    end                               as confidence,
    brier_score,
    baseline_is_correct,
    baseline_brier_score,
    prediction_model_version
from superligaen.mart_prediction_accuracy
where match_id > 0
order by match_date desc
```

```sql summary
select
    count(*)                                   as matches_scored,
    avg(is_correct::int)                       as model_hit_rate,
    avg(baseline_is_correct::int)              as baseline_hit_rate,
    avg(brier_score)                           as model_brier,
    avg(baseline_brier_score)                  as baseline_brier
from superligaen.mart_prediction_accuracy
where match_id > 0
```

```sql calibration
select
    floor(confidence * 10) / 10                as bucket_floor,
    format('{:.0f}–{:.0f}%', floor(confidence * 10) * 10, floor(confidence * 10) * 10 + 10) as confidence_band,
    count(*)                                   as n_matches,
    avg(confidence)                            as avg_confidence,
    avg(is_correct::int)                       as actual_rate
from ${scored}
group by 1, 2
order by 1
```

# Prediction Tracker

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Before each round, our data science team's model publishes win/draw/loss probabilities for every fixture — you can see them on the <a href="/upcoming-matches" style="color:#6b7280;">Upcoming Fixtures</a> page. This page keeps the model honest: every prediction made before kickoff is scored against the real result, and nothing is ever re-predicted after the fact.</p>

{#if scored.length > 0}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Matches Scored</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{summary[0].matches_scored}</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Model Hit Rate</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{Math.round(summary[0].model_hit_rate*100)}%</div>
    <div class="text-xs text-gray-400 text-center mt-2">picked the right outcome</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Naive Baseline</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{Math.round(summary[0].baseline_hit_rate*100)}%</div>
    <div class="text-xs text-gray-400 text-center mt-2">always picks the league's most common outcome</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Brier Score</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{summary[0].model_brier.toFixed(3)}</div>
    <div class="text-xs text-gray-400 text-center mt-2">baseline {summary[0].baseline_brier.toFixed(3)} &middot; lower is better</div>
  </div>
</div>

## Scored Matches

{#each scored as m}
<div class="rounded-xl border border-gray-200 bg-white px-4 py-3 mb-2">
  <div class="flex items-center gap-3">
    <div class="text-[11px] text-gray-400 w-20 shrink-0">{m.match_day}</div>
    <div class="flex-1 flex items-center gap-2 min-w-0">
      <img src={m.home_team_logo} alt="" class="h-5 w-5 object-contain shrink-0" onerror="this.style.display='none'" />
      <span class="font-semibold text-gray-800 text-sm">{m.home_team_short} {m.home_goals} - {m.away_goals} {m.away_team_short}</span>
      <img src={m.away_team_logo} alt="" class="h-5 w-5 object-contain shrink-0" onerror="this.style.display='none'" />
    </div>
    <div class="shrink-0 text-xs text-gray-500">called <span class="font-semibold">{m.predicted_outcome}</span> at {Math.round(m.confidence*100)}%</div>
    <div class="shrink-0 text-sm font-bold {m.is_correct ? 'text-green-600' : 'text-red-500'}">{m.is_correct ? '✓' : '✗'}</div>
  </div>
  <div class="mt-2 max-w-md">
    <div class="flex h-1.5 rounded-full overflow-hidden gap-[2px]">
      <div class="bg-[#3b82f6] rounded-l-full" style="width:{(m.home_win_prob*100).toFixed(1)}%"></div>
      <div class="bg-[#94a3b8]" style="width:{(m.draw_prob*100).toFixed(1)}%"></div>
      <div class="bg-[#f97316] rounded-r-full" style="width:{(m.away_win_prob*100).toFixed(1)}%"></div>
    </div>
    <div class="flex justify-between text-[10px] text-gray-500 mt-1">
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#3b82f6] mr-1"></span>{m.home_team_short} {Math.round(m.home_win_prob*100)}%</span>
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#94a3b8] mr-1"></span>Draw {Math.round(m.draw_prob*100)}%</span>
      <span><span class="inline-block w-2 h-2 rounded-full bg-[#f97316] mr-1"></span>{m.away_team_short} {Math.round(m.away_win_prob*100)}%</span>
    </div>
  </div>
</div>
{/each}

## Calibration

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 0.5rem 0;font-style:italic;">A well-calibrated model is right about as often as it claims: when it says 60%, the pick should land about 60% of the time.</p>

<DataTable data={calibration} rows=10>
  <Column id=confidence_band title="Model Confidence" align=center />
  <Column id=n_matches       title="Matches"          align=center />
  <Column id=avg_confidence  title="Avg Claimed"      fmt='0.0%' align=center />
  <Column id=actual_rate     title="Actually Right"   fmt='0.0%' align=center />
</DataTable>

{:else}

<div class="flex flex-col items-center justify-center py-24 text-center">
  <div class="text-5xl mb-4">🎯</div>
  <div class="text-xl font-bold text-gray-700 mb-2">No Scored Predictions Yet</div>
  <div class="text-gray-400 text-sm max-w-md">The tracker earns its history in public: predictions are published before each round and scored here once the matches finish. Check back after the next round.</div>
</div>

{/if}
