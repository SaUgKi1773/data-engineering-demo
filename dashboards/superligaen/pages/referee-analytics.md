---
sidebar: never
hide_toc: true
title: Referee Intelligence
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';
  const pageInputs = getInputContext();

  $: if (season_stats?.length > 0) {
    pageInputs.update(($i) => {
      const currentIsValid = season_stats.some(r => r.referee_name === $i.referee?.value);
      if (currentIsValid) return $i;
      const first = season_stats[0];
      return { ...$i, referee: { value: first.referee_name, label: first.referee_name, rawValues: [{ value: first.referee_name, label: first.referee_name, selected: true }] } };
    });
  }
</script>

```sql seasons
select distinct season
from superligaen.mart_referee_season
order by season desc
```

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a season to explore referee discipline patterns — league averages, strictness rankings, home/away bias, and individual referee deep dives.</p>

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

```sql season_kpis
select
    count(*)                                                                            as total_referees,
    round(sum(total_yellow_cards)::double / sum(matches_managed), 2)                   as league_avg_yellows,
    round(sum(total_red_cards)::double    / sum(matches_managed), 3)                   as league_avg_reds,
    round(sum(total_fouls)::double        / sum(matches_managed), 1)                   as league_avg_fouls,
    round((sum(total_yellow_cards) + sum(total_red_cards) * 3)::double
          / sum(matches_managed), 2)                                                   as league_severity_index
from superligaen.mart_referee_season
where season = '${inputs.season.value}'
```

```sql season_stats
select
    referee_name,
    matches_managed,
    total_yellow_cards,
    total_red_cards,
    total_fouls,
    avg_yellows_per_match,
    avg_reds_per_match,
    avg_fouls_per_match,
    card_severity_index,
    home_yc_per_match,
    away_yc_per_match,
    home_yc_pct
from superligaen.mart_referee_season
where season = '${inputs.season.value}'
order by matches_managed desc
```

```sql top3_strictest
select * from ${season_stats} order by avg_yellows_per_match desc limit 3
```

```sql top3_lenient
select * from ${season_stats} order by avg_yellows_per_match asc limit 3
```

```sql historical_trends
select
    substr(season, 3, 2) || '/' || right(season, 2)                                        as season,
    round(sum(total_yellow_cards)::double / sum(matches_managed), 2)                        as yc_per_match,
    round(sum(total_red_cards)::double    / sum(matches_managed), 4)                        as rc_per_match,
    round(sum(total_fouls)::double        / sum(matches_managed), 1)                        as fouls_per_match,
    round((sum(total_yellow_cards) + sum(total_red_cards) * 3)::double
          / sum(matches_managed), 2)                                                        as severity_index
from superligaen.mart_referee_season
group by season
order by season asc
```

```sql referee_trends
select
    substr(season, 3, 2) || '/' || right(season, 2)                                        as season,
    avg_yellows_per_match                                                                   as yc_per_match,
    avg_reds_per_match                                                                      as rc_per_match,
    avg_fouls_per_match                                                                     as fouls_per_match,
    card_severity_index                                                                     as severity_index
from superligaen.mart_referee_season
where referee_name = '${inputs.referee.value}'
order by season asc
```

```sql combined_trends
select season, yc_per_match, rc_per_match, fouls_per_match, severity_index, 'League Avg' as source
from ${historical_trends}
union all
select season, yc_per_match, rc_per_match, fouls_per_match, severity_index, '${inputs.referee.value}' as source
from ${referee_trends}
```

---

## Referee Intelligence — {inputs.season.value}

### League Discipline Snapshot

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Season-wide averages across all referees — active officials, yellow and red card rates, and average fouls per match.</p>

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Active Referees</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{season_kpis[0]?.total_referees ?? '—'}</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Avg YC / Match</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{season_kpis[0]?.league_avg_yellows ?? '—'}</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Avg RC / Match</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{season_kpis[0]?.league_avg_reds ?? '—'}</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Avg Fouls / Match</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{season_kpis[0]?.league_avg_fouls ?? '—'}</div>
  </div>
</div>

---

## Strictest vs Most Lenient Referees

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Top 3 referees by yellow cards per match at each extreme — who runs the tightest game and who lets the most go.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">

<div>
  <div class="text-sm font-bold text-red-500 uppercase tracking-widest mb-3">🟨 Most Strict</div>
  <div class="flex flex-col gap-3">
    {#each top3_strictest as r, i}
      <div class="rounded-xl border border-red-100 bg-gradient-to-r from-red-50 to-orange-50 p-4 flex items-center gap-4">
        <div class="text-2xl font-black text-red-400 w-8 text-center">{i+1}</div>
        <div class="flex-1">
          <div class="font-bold text-gray-800">{r.referee_name}</div>
          <div class="text-xs text-gray-400 mt-0.5">{r.matches_managed} games · {r.total_yellow_cards} yellows · {r.total_red_cards} reds</div>
        </div>
        <div class="text-right">
          <div class="text-xl font-black text-red-500">{r.avg_yellows_per_match}</div>
          <div class="text-xs text-gray-400">YC/match</div>
        </div>
      </div>
    {/each}
  </div>
</div>

<div>
  <div class="text-sm font-bold text-green-500 uppercase tracking-widest mb-3">🟩 Least Strict</div>
  <div class="flex flex-col gap-3">
    {#each top3_lenient as r, i}
      <div class="rounded-xl border border-green-100 bg-gradient-to-r from-green-50 to-teal-50 p-4 flex items-center gap-4">
        <div class="text-2xl font-black text-green-400 w-8 text-center">{i+1}</div>
        <div class="flex-1">
          <div class="font-bold text-gray-800">{r.referee_name}</div>
          <div class="text-xs text-gray-400 mt-0.5">{r.matches_managed} games · {r.total_yellow_cards} yellows · {r.total_red_cards} reds</div>
        </div>
        <div class="text-right">
          <div class="text-xl font-black text-green-600">{r.avg_yellows_per_match}</div>
          <div class="text-xs text-gray-400">YC/match</div>
        </div>
      </div>
    {/each}
  </div>
</div>

</div>

---

## Season Leaderboard

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">All referees ranked by matches managed. Includes cards, fouls, severity index, and home/away yellow card split.</p>

<DataTable data={season_stats} rows=20>
    <Column id=referee_name          title="Referee"              wrap=true />
    <Column id=matches_managed       title="Games"                contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=total_yellow_cards    title="Yellow Cards"         contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards       title="Red Cards"            contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=avg_yellows_per_match title="Avg YC / Match"       contentType=colorscale colorPalette={['white','#eab308']} />
    <Column id=avg_reds_per_match    title="Avg RC / Match"       contentType=colorscale colorPalette={['white','#ef4444']} />
    <Column id=avg_fouls_per_match   title="Avg Fouls / Match"    contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=card_severity_index   title="Severity Index"       contentType=colorscale colorPalette={['white','#dc2626']} />
    <Column id=home_yc_pct           title="Home YC %"            fmt='0.0"%"' contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

---

## Home / Away Bias

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">A neutral referee should book home and away teams equally. Values near 50% = balanced. Above 50% = more cards to home team.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={season_stats}
    x=referee_name
    y={['home_yc_per_match','away_yc_per_match']}
    title="YC per Match — Home vs Away Teams"
    yAxisTitle="YC / Match"
    colorPalette={['#3b82f6','#f97316']}
    swapXY=true
    type=stacked
/>

<BarChart
    data={season_stats}
    x=referee_name
    y=home_yc_pct
    title="% of Yellow Cards Given to Home Team"
    yAxisTitle="Home YC %"
    yFmt='0.0'
    colorPalette={['#6366f1']}
    swapXY=true
    sort=true
/>

</div>

---

## Cards & Fouls per Match

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Per-match averages for every referee. Sorted highest to lowest so outliers are immediately visible.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={season_stats}
    x=referee_name
    y={['avg_yellows_per_match','avg_reds_per_match']}
    title="Cards per Match — {inputs.season.value}"
    colorPalette={['#eab308','#ef4444']}
    swapXY=true
    sort=true
/>

<BarChart
    data={season_stats}
    x=referee_name
    y=avg_fouls_per_match
    title="Fouls per Match — {inputs.season.value}"
    colorPalette={['#f97316']}
    swapXY=true
    sort=true
/>

</div>

---

## Referee Deep Dive

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Select a referee to see their personal profile, team exposure, match log, and how their card rates compare to the league average across all seasons.</p>

{#key season_stats[0]?.referee_name}
<Dropdown data={season_stats} name=referee value=referee_name label=referee_name defaultValue={season_stats[0]?.referee_name} />
{/key}

```sql referee_team_exposure
select team_name, count(*)::int as matches
from (
    select referee_name, season, home_team as team_name from superligaen.mart_match_card
    union all
    select referee_name, season, away_team as team_name from superligaen.mart_match_card
) t
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
group by team_name
order by matches desc
```

```sql referee_match_log
select
    match_date,
    match_round_name                            as round,
    match_name,
    score,
    (home_yc + away_yc)::int                   as yellow_cards,
    (home_rc + away_rc)::int                   as red_cards,
    (home_fouls + away_fouls)::int             as fouls
from superligaen.mart_match_card
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
order by match_date desc
```

```sql referee_kpis
select * from ${season_stats}
where referee_name = '${inputs.referee.value}'
```

{#each referee_kpis as r}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="text-center md:text-left">
    <div class="text-3xl font-extrabold text-white mb-1">{r.referee_name}</div>
    <div class="text-gray-400 text-sm mb-5">{inputs.season.value} · {r.matches_managed} matches officiated</div>
    <div class="flex flex-wrap justify-center md:justify-start gap-6">
      <div class="text-center">
        <div class="text-3xl font-black text-yellow-400">{r.total_yellow_cards}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Yellow Cards</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-red-400">{r.total_red_cards}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Red Cards</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-orange-400">{r.avg_yellows_per_match}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">YC / Match</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-white">{r.avg_fouls_per_match}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Fouls / Match</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black text-purple-400">{r.card_severity_index}</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Severity Index</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-black {r.home_yc_pct > 55 ? 'text-red-400' : r.home_yc_pct < 45 ? 'text-blue-400' : 'text-green-400'}">{r.home_yc_pct}%</div>
        <div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Home YC %</div>
      </div>
    </div>
  </div>
</div>
{/each}

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>

### Team Exposure

<BarChart
    data={referee_team_exposure}
    x=team_name
    y=matches
    title="Matches per Team — {inputs.referee.value}"
    colorPalette={['#6366f1']}
    swapXY=true
/>

</div>

<div>

### Match Log

<DataTable data={referee_match_log} rows=5>
    <Column id=match_date    title="Date"   />
    <Column id=round         title="Round"  />
    <Column id=match_name    title="Match"  wrap=true />
    <Column id=score         title="Score"  align=center />
    <Column id=yellow_cards  title="YC"     contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards     title="RC"     contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=fouls         title="Fouls"  contentType=colorscale colorPalette={['white','#f97316']} align=center />
</DataTable>

</div>

</div>

---

## Historical Discipline Trends

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Season-by-season league averages (grey) overlaid with the selected referee's own trend line — spot referees who have become stricter or more lenient over time.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<LineChart
    data={combined_trends}
    x=season
    y=yc_per_match
    series=source
    title="Yellow Cards per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="YC / Match"
    colorPalette={['#d1d5db','#eab308']}
    sort=false
/>

<LineChart
    data={combined_trends}
    x=season
    y=fouls_per_match
    series=source
    title="Fouls per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="Fouls / Match"
    colorPalette={['#d1d5db','#f97316']}
    sort=false
/>

<LineChart
    data={combined_trends}
    x=season
    y=severity_index
    series=source
    title="Card Severity Index — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="Severity Index"
    colorPalette={['#d1d5db','#dc2626']}
    sort=false
/>

<LineChart
    data={combined_trends}
    x=season
    y=rc_per_match
    series=source
    title="Red Cards per Match — All Seasons"
    xAxisTitle="Season"
    yAxisTitle="RC / Match"
    colorPalette={['#d1d5db','#ef4444']}
    sort=false
/>

</div>

---

## Card Timing — {inputs.referee.value}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">When this referee reaches for the cards, by 15-minute interval, against the league baseline for the selected season. Stoppage time (45+, 90+) counted separately.</p>

```sql ref_card_timing
select minute_bucket, minute_bucket_sort, cards_per_match, league_cards_per_match, yellow_cards, second_yellow_cards, red_cards
from superligaen.mart_referee_card_timing
where season = '${inputs.season.value}'
  and referee_name = '${inputs.referee.value}'
order by minute_bucket_sort
```

```sql ref_card_timing_compare
select minute_bucket, minute_bucket_sort, league_cards_per_match as cards_per_match, 'League Avg' as source
from ${ref_card_timing}
union all
select minute_bucket, minute_bucket_sort, cards_per_match, '${inputs.referee.value}' as source
from ${ref_card_timing}
order by minute_bucket_sort
```

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={ref_card_timing_compare}
    x=minute_bucket
    y=cards_per_match
    series=source
    title="Cards per Match by Minute — vs League"
    xAxisTitle="Match Minute"
    yAxisTitle="Cards / Match"
    colorPalette={['#d1d5db','#eab308']}
    type=grouped
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={ref_card_timing}
    x=minute_bucket
    y={['yellow_cards','second_yellow_cards','red_cards']}
    title="Card Types by Minute"
    xAxisTitle="Match Minute"
    yAxisTitle="Cards"
    colorPalette={['#eab308','#f97316','#ef4444']}
    type=stacked
    sort=false
/>

</div>

---

## VAR Decisions

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Video-assistant involvement for the selected referee and season — reviews, overturned goals, and penalty calls. Reviews without a categorized outcome count toward the total only.</p>

```sql ref_var
select *
from superligaen.mart_referee_var
where season = '${inputs.season.value}'
  and referee_name = '${inputs.referee.value}'
```

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">VAR Reviews</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{ref_var[0]?.var_reviews ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Reviews / Match</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{ref_var[0]?.var_per_match ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Goals Disallowed</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{ref_var[0]?.goals_disallowed ?? '—'}</div>
  </div>
  <div>
    <div class="text-xs text-gray-500 uppercase tracking-wide mb-1 text-center">Goals Awarded</div>
    <div class="text-3xl font-black text-gray-900 leading-none text-center">{ref_var[0]?.goals_awarded ?? '—'}</div>
  </div>
</div>

```sql var_table
select referee_name, matches, var_reviews, var_per_match, goals_disallowed, goals_awarded, penalties_confirmed, penalties_cancelled, card_reviews
from superligaen.mart_referee_var
where season = '${inputs.season.value}'
order by var_per_match desc
```

<DataTable data={var_table} rows=20>
    <Column id=referee_name title="Referee" />
    <Column id=matches title="Matches" />
    <Column id=var_reviews title="Reviews" />
    <Column id=var_per_match title="Reviews / Match" />
    <Column id=goals_disallowed title="Goals Disallowed" />
    <Column id=goals_awarded title="Goals Awarded" />
    <Column id=penalties_confirmed title="Pens Confirmed" />
    <Column id=penalties_cancelled title="Pens Cancelled" />
    <Column id=card_reviews title="Card Reviews" />
</DataTable>


```sql last_updated
select * from superligaen.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
