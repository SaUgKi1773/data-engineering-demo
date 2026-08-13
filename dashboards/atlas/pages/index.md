---
sidebar: never
hide_toc: true
title: Cross-League Analytics
hide_title: true
description: Five top-flight leagues on three continents, measured the same way.
---

<script>
  import Panel from '../components/Panel.svelte';
  import Matrix from '../components/Matrix.svelte';
  import SiteFooter from '../components/SiteFooter.svelte';
  import { leagues as KEY } from '../components/navItems.js';

  const f2 = (v) => Number(v).toFixed(2);
  const f1 = (v) => Number(v).toFixed(1);
  const f0 = (v) => Math.round(Number(v)).toLocaleString();
  const SERIES = {'La Liga':'#2a78d6','Liga MX':'#eb6834','Premiership':'#1baf7a','Superliga':'#eda100','Süper Lig':'#e87ba4'};

  // Each measure is a numerator and a denominator, never a pre-divided rate.
  // A league's value is num/den for that league; the headline is the POOLED
  // rate, Σnum/Σden across the five — not the mean of five means, which would
  // weight a 468-match league the same as a 2,280-match one and disagree with
  // the totals in the scope bar.
  const M = (label, num, den, scale = 1, format = f2) =>
    ({ label, num, den, scale, format });
  const MEASURES = [
    M('Goals',           (d) => d.goals,           (d) => d.matches),
    M('Shots on target', (d) => d.shots,           (d) => d.n_shots),
    M('Corners',         (d) => d.corners,         (d) => d.n_corners),
    M('Passes',          (d) => d.passes,          (d) => d.n_passes, 1, f0),
    M('Fouls',           (d) => d.fouls,           (d) => d.n_fouls,  1, f1),
    M('Yellow cards',    (d) => d.yellow_cards,    (d) => d.n_cards),
    M('Home win %',      (d) => d.home_wins,       (d) => d.matches, 100, f1),
    M('Draw %',          (d) => d.draws,           (d) => d.matches, 100, f1)
  ];


  const CODES = KEY.map((l) => ({ code: l.code, colour: l.colour }));
  const byLeague = (q) => Object.fromEntries([...q].map((r) => [r.league_name, r]));

  const rate = (m, row) => {
    if (!row) return null;
    const n = Number(m.num(row)), dd = Number(m.den(row));
    return dd ? (m.scale * n) / dd : null;
  };
  function rank(d, m) {
    return KEY.map((l) => ({ code: l.code, colour: l.colour, name: l.league_name, value: rate(m, d[l.league_name]) }))
      .filter((r) => r.value != null && !isNaN(r.value) && isFinite(r.value))
      .sort((a, b) => b.value - a.value);
  }
  // Σnum / Σden across the leagues in view.
  // Segment widths are each league's share of the five rates, so the bar
  // describes the same number the tile reports. `r` arrives sorted highest
  // first, which puts the leader on the left.
  const split = (r) => {
    const sum = r.reduce((a, b) => a + b.value, 0) || 1;
    return r.map((x) => ({ colour: x.colour, share: (x.value / sum) * 100 }));
  };

  function pooled(d, m) {
    let n = 0, dd = 0;
    for (const l of KEY) {
      const row = d[l.league_name];
      if (!row) continue;
      n += Number(m.num(row)) || 0;
      dd += Number(m.den(row)) || 0;
    }
    return dd ? (m.scale * n) / dd : null;
  }
  // Which league tops each measure, counted. No derived statistic: a league
  // either has the highest figure on a measure or it does not.
  const matrixRows = (d) => MEASURES.map((m) => ({
    measure: m.label,
    format: m.format,
    values: Object.fromEntries(KEY.map((l) => [l.code, rate(m, d[l.league_name])]))
  }));

</script>

```sql day_range
select distinct match_date from atlas.mart_club_day order by match_date
```

```sql club_totals
select
    league_name,
    sum(matches) / 2                                    as matches,
    sum(goals_for)                                      as goals,
    sum(wins)   filter (where team_side = 'Home')       as home_wins,
    sum(draws)  / 2                                     as draws,
    sum(clean_sheets)                                   as clean_sheets,
    sum(corners) as corners,           sum(n_corners) / 2 as n_corners,
    sum(yellow_cards) as yellow_cards, sum(red_cards) as red_cards, sum(n_cards) / 2 as n_cards,
    sum(shots_on_target) as shots,     sum(n_shots) / 2 as n_shots,
    sum(passes) as passes,             sum(passes_accurate) as passes_accurate, sum(n_passes) / 2 as n_passes,
    sum(fouls) as fouls,               sum(n_fouls) / 2 as n_fouls,
    sum(offsides) as offsides,         sum(n_offsides) / 2 as n_offsides,
    sum(saves) as saves,               sum(n_saves) / 2 as n_saves
from atlas.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1
```

```sql scope
select
    sum(matches) / 2            as matches,
    sum(goals_for)              as goals,
    count(distinct team_name)   as clubs
from atlas.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
```

<div class="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-[3px] border border-gray-200 bg-white px-2 py-1.5">
  <span class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date />
  <span class="ml-auto text-[10px] tabular-nums text-gray-400">
    <Value data={scope} column=matches fmt='#,##0' /> matches ·
    <Value data={scope} column=goals fmt='#,##0' /> goals ·
    <Value data={scope} column=clubs /> clubs
  </span>
</div>

{#await Promise.resolve() then _}
  {@const D = byLeague(club_totals)}

  <!-- ══ A · HEADLINE ════════════════════════════════════════════════════ -->
  <div class="mb-2 grid grid-cols-2 gap-px overflow-hidden rounded-[3px] border border-gray-200 bg-gray-200 md:grid-cols-4 xl:grid-cols-8">
    {#each MEASURES.slice(0, 8) as m}
      {@const r = rank(D, m)}
      <div class="flex h-[76px] flex-col justify-between bg-white px-2.5 py-1.5">
        <div class="truncate text-[10px] font-semibold uppercase tracking-wider text-gray-500">{m.label}</div>
        <div class="text-[22px] font-semibold leading-none tabular-nums text-gray-900">
          {pooled(D, m) == null ? '–' : m.format(pooled(D, m))}
        </div>
        <div class="flex h-[5px] w-full overflow-hidden rounded-[1px]">
          {#each split(r) as seg}<span style="width:{seg.share}%; background:{seg.colour};"></span>{/each}
        </div>
        <div class="flex items-center gap-1.5 truncate text-[11px] leading-none">
          {#if r.length}
            <span class="flex items-center gap-1">
              <span class="h-1.5 w-1.5 flex-none rounded-full" style="background:{r[0].colour}"></span>
              <span class="font-semibold text-gray-700">{r[0].code}</span>
              <span class="tabular-nums text-gray-900">{m.format(r[0].value)}</span>
            </span>
          {/if}
        </div>
      </div>
    {/each}
  </div>

  <!-- ══ B · LEADERS · TREND · LEAGUES ═══════════════════════════════════ -->
  <div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-3">

    <div>
      <Panel title="The five leagues" qualifier="sorted by goals per match" scope="↗ own site">
        <div class="flex h-full flex-col gap-1">
          {#each rank(D, MEASURES[0]) as r}
            <a href={KEY.find((l) => l.code === r.code).site_url} target="_blank" rel="noopener"
               class="flex items-center gap-2 rounded-[2px] border border-gray-200 px-2 py-[7px] no-underline hover:border-gray-400">
              <span class="h-7 w-[3px] flex-none rounded-[1px]" style="background:{r.colour}"></span>
              <span class="min-w-0 flex-1">
                <span class="block truncate text-[12px] font-medium text-gray-900">{r.name}</span>
                <span class="block text-[10px] tabular-nums text-gray-400">{f0(D[r.name].matches)} matches</span>
              </span>
              <span class="text-[13px] font-semibold tabular-nums text-gray-900">{f2(r.value)}</span>
              <span class="text-[10px] text-gray-300">↗</span>
            </a>
          {/each}
        </div>
      </Panel>
    </div>

    <div>

```sql trend
select
    calendar_year::int::varchar                                     as yr,
    league_name,
    round(1.0 * sum(goals_for) / nullif(sum(matches) / 2, 0), 3)    as value
from atlas.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
having sum(matches) / 2 >= 20
order by yr, league_name
```

      <Panel title="Goals per match" qualifier="by calendar year" href="/leagues">
        <LineChart data={trend} x=yr y=value series=league_name yAxisTitle=""
          seriesColors={SERIES} markers=true sort=false legend=false chartAreaHeight=296
          echartsOptions={{tooltip: {formatter: function(p) {
            const r = p.filter(x => x.value && x.value[1] != null && !isNaN(x.value[1])).sort((a,b) => b.value[1]-a.value[1]);
            if (!r.length) return '';
            let o = '<span style="font-weight:600;">' + p[0].axisValueLabel + '</span>';
            for (const x of r) o += '<br><span style="font-size:11px;">' + x.marker + ' ' + x.seriesName + '</span><span style="float:right;margin-left:14px;font-weight:600;">' + Number(x.value[1]).toFixed(2) + '</span>';
            return o; }}}}
        />
      </Panel>
    </div>

    <div>
      <Panel title="Key measures" href="/leagues" scope="all 20 on Leagues">
        <Matrix codes={CODES} rows={matrixRows(D)} />
      </Panel>
    </div>
  </div>
{/await}

```sql big_wins
select m.league_name, l.colour, l.code, m.home_team, m.away_team, m.home_goals, m.away_goals
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by m.winning_margin desc, m.total_goals desc limit 7
```

```sql high_scoring
select m.league_name, l.colour, l.code, m.home_team, m.away_team, m.home_goals, m.away_goals
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by m.total_goals desc, m.winning_margin desc limit 7
```

```sql comebacks
select m.league_name, l.colour, l.code, m.comeback_by,
       m.home_goals, m.away_goals, m.home_goals_ht, m.away_goals_ht
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
  and m.comeback_by is not null
order by abs(m.home_goals_ht - m.away_goals_ht) desc, m.total_goals desc limit 7
```

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-3">
  <Panel title="Biggest wins" qualifier="by margin" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...big_wins] as m}
        <div class="flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.home_team} v {m.away_team}</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
        </div>
      {/each}
    </div>
  </Panel>

  <Panel title="Most goals in a match" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...high_scoring] as m}
        <div class="flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.home_team} v {m.away_team}</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
        </div>
      {/each}
    </div>
  </Panel>

  <Panel title="Comebacks" qualifier="trailed at the break, won" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...comebacks] as m}
        <div class="flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.comeback_by}</span>
          <span class="text-[10px] tabular-nums text-gray-400">{m.home_goals_ht}–{m.away_goals_ht} HT</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
        </div>
      {/each}
    </div>
  </Panel>
</div>

```sql clock
select
    minute_bucket, minute_bucket_sort, league_name,
    round(100.0 * sum(events) / nullif(sum(sum(events)) over (partition by league_name), 0), 2) as share
from atlas.mart_event_clock
where event_group = 'Goal' and match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 3
order by minute_bucket_sort, league_name
```

```sql clock_table
select
    minute_bucket as "Minute", minute_bucket_sort,
    max(case when league_name = 'La Liga'     then share end) as "ESP",
    max(case when league_name = 'Liga MX'     then share end) as "MEX",
    max(case when league_name = 'Premiership' then share end) as "SCO",
    max(case when league_name = 'Superliga'   then share end) as "DEN",
    max(case when league_name = 'Süper Lig'   then share end) as "TUR"
from ${clock} group by 1, 2 order by minute_bucket_sort
```

<div class="grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-8">
    <Panel title="When goals are scored" qualifier="share of each league's goals, by quarter-hour" href="/matches">
      <LineChart data={clock} x=minute_bucket y=share series=league_name yAxisTitle=""
        seriesColors={SERIES} markers=true sort=false legend=false chartAreaHeight=210
        echartsOptions={{tooltip: {formatter: function(p) {
          const r = p.filter(x => x.value && x.value[1] != null && !isNaN(x.value[1])).sort((a,b) => b.value[1]-a.value[1]);
          if (!r.length) return '';
          let o = '<span style="font-weight:600;">' + p[0].axisValueLabel + '</span>';
          for (const x of r) o += '<br><span style="font-size:11px;">' + x.marker + ' ' + x.seriesName + '</span><span style="float:right;margin-left:14px;font-weight:600;">' + Number(x.value[1]).toFixed(1) + '%</span>';
          return o; }}}}
      />
    </Panel>
  </div>
  <div class="xl:col-span-4">
    <Panel title="Share of goals" qualifier="%, shaded down each column" pad={false}>
      <DataTable data={clock_table} rows=8 rowShading=false>
        <Column id="Minute" />
        <Column id="ESP" fmt='0.0' contentType=colorscale colorScale=#1f3f6b />
        <Column id="MEX" fmt='0.0' contentType=colorscale colorScale=#1f3f6b />
        <Column id="SCO" fmt='0.0' contentType=colorscale colorScale=#1f3f6b />
        <Column id="DEN" fmt='0.0' contentType=colorscale colorScale=#1f3f6b />
        <Column id="TUR" fmt='0.0' contentType=colorscale colorScale=#1f3f6b />
      </DataTable>
    </Panel>
  </div>
</div>

<SiteFooter />
