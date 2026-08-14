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
  import Rank from '../components/Rank.svelte';
  import BandLink from '../components/BandLink.svelte';
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

```sql last_updated
select strftime(last_match, '%d %b %Y') as last_updated from crossleague.mart_last_updated
```

```sql day_range
select distinct match_date from crossleague.mart_club_day order by match_date
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
from crossleague.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1
```

```sql scope
select
    sum(matches) / 2            as matches,
    sum(goals_for)              as goals,
    count(distinct team_name)   as clubs
from crossleague.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
```

<div class="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1 rounded-[3px] border border-gray-200 bg-white px-2 py-1.5">
  <span class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date defaultValue="Year to Today" />
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

  <!-- ══ B · LEAGUES ═════════════════════════════════════════════════════ -->
<BandLink href="/leagues" name="Leagues" note="all five side by side, on every measure" />

  <div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-3">

    <div>
      <Panel title="The five leagues" qualifier="sorted by goals per match" scope="↗ own site">
        <div class="flex h-full flex-col gap-1">
          {#each rank(D, MEASURES[0]) as r}
            <a href={KEY.find((l) => l.code === r.code).site_url} target="_blank" rel="noopener"
               class="flex flex-1 items-center gap-2 rounded-[2px] border border-gray-200 px-2 no-underline hover:border-gray-400">
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
    strftime(date_trunc('month', match_date), '%b %y')              as ym,
    date_trunc('month', match_date)                                 as month_start,
    league_name,
    round(1.0 * sum(goals_for) / nullif(sum(matches) / 2, 0), 3)    as value
from crossleague.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 3
order by month_start, league_name
```

      <Panel title="Goals per match" qualifier="by month" href="/leagues">
        <LineChart data={trend} x=ym y=value series=league_name yAxisTitle=""
          seriesColors={SERIES} markers=true sort=false legend=false chartAreaHeight=330
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

<!-- ══ C · CLUBS ═══════════════════════════════════════════════════════ -->

```sql home_clubs
select
    team_name, league_name,
    sum(matches)                                                as matches,
    (1.0 * sum(goals_for)     / nullif(sum(matches), 0))::double as gpm,
    (1.0 * sum(goals_against) / nullif(sum(matches), 0))::double as gapm
from crossleague.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
```

```sql home_top_clubs
select c.*, l.code, l.colour
from ${home_clubs} c join crossleague.mart_leagues l on l.league_name = c.league_name
where c.gpm is not null order by c.gpm desc limit 10
```

```sql home_club_owners
with top20 as (select league_name from ${home_clubs} where gpm is not null order by gpm desc limit 20)
select l.code, l.colour, l.league_name, count(*) as n,
       round(100.0 * count(*) / sum(count(*)) over (), 2) as share
from top20 t join crossleague.mart_leagues l on l.league_name = t.league_name
group by 1, 2, 3 order by n desc
```

```sql home_scatter_bounds
select
    (floor(min(gpm) * 10) / 10)::double  as x_min, (ceil(max(gpm) * 10) / 10)::double  as x_max,
    (floor(min(gapm) * 10) / 10)::double as y_min, (ceil(max(gapm) * 10) / 10)::double as y_max
from ${home_clubs} where gpm is not null and gapm is not null
```

<BandLink href="/clubs" name="Clubs" note="every club on one ranking, whatever the league" />

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-4">
    <Panel title="Best attacks" qualifier="goals scored per match" href="/clubs">
      <Rank dense={true} measure="Goals scored per match"
            rows={[...home_top_clubs].map((r) => ({ label: r.team_name, sublabel: r.code, value: r.gpm, colour: r.colour, hint: r.league_name }))}
            format={f2} />
    </Panel>
  </div>

  <div class="xl:col-span-3">
    <Panel title="Who owns the top 20" qualifier="clubs in the leading twenty" href="/clubs">
      <div class="flex flex-col gap-2">
        <div class="flex h-5 w-full overflow-hidden rounded-[2px]">
          {#each [...home_club_owners] as o}
            <span class="flex items-center justify-center text-[10px] font-semibold text-white" style="width:{o.share}%; background:{o.colour};">{o.n}</span>
          {/each}
        </div>
        {#each [...home_club_owners] as o}
          <div class="flex items-center gap-2 border-b border-gray-100 pb-1 last:border-0">
            <span class="h-4 w-[3px] flex-none rounded-[1px]" style="background:{o.colour}"></span>
            <span class="w-8 flex-none text-[10px] font-semibold text-gray-600">{o.code}</span>
            <span class="min-w-0 flex-1 truncate text-[11px] text-gray-500">{o.league_name}</span>
            <span class="text-[13px] font-semibold tabular-nums text-gray-900">{o.n}</span>
          </div>
        {/each}
      </div>
    </Panel>
  </div>

  <div class="xl:col-span-5">
    <Panel title="Attack against defence" qualifier="one dot per club" scope="bottom right is where champions sit" href="/clubs">
      <ScatterPlot data={home_clubs} x=gpm y=gapm series=league_name
        xAxisTitle="Goals scored per match" yAxisTitle="Goals conceded per match"
        tooltipColumns={[{id: 'team_name', title: 'Club'}, {id: 'league_name'}, {id: 'gpm', title: 'Scored'}, {id: 'gapm', title: 'Conceded'}]}
        xMin={home_scatter_bounds[0].x_min} xMax={home_scatter_bounds[0].x_max}
        yMin={home_scatter_bounds[0].y_min} yMax={home_scatter_bounds[0].y_max}
        seriesColors={SERIES} tooltipTitle=team_name legend=false chartAreaHeight=240 />
    </Panel>
  </div>
</div>

<!-- ══ D · PLAYERS ═════════════════════════════════════════════════════ -->

```sql home_scorers
select p.player_name, p.league_name, sum(p.goals) as goals, l.code, l.colour
from crossleague.mart_player_day p join crossleague.mart_leagues l on l.league_name = p.league_name
where p.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 4, 5
having sum(p.goals) > 0
order by goals desc, p.player_name limit 10
```

```sql home_top_per_league
select * from (
    select player_name, league_name, sum(goals) as goals,
           row_number() over (partition by league_name order by sum(goals) desc, player_name) as rn
    from crossleague.mart_player_day
    where match_date between '${inputs.period.start}' and '${inputs.period.end}'
    group by 1, 2
)
where rn <= 3 and goals > 0
order by league_name, rn
```

```sql home_concentration
with p as (
    select league_name, player_name, sum(goals) as goals
    from crossleague.mart_player_day
    where match_date between '${inputs.period.start}' and '${inputs.period.end}'
    group by 1, 2 having sum(goals) > 0
),
r as (
    select *, row_number() over (partition by league_name order by goals desc) as rn,
           sum(goals) over (partition by league_name) as league_goals
    from p
)
select l.code, l.colour, r.league_name,
       round(100.0 * sum(r.goals) filter (where r.rn <= 10) / nullif(max(r.league_goals), 0), 1) as top10_share
from r join crossleague.mart_leagues l on l.league_name = r.league_name
group by 1, 2, 3 order by top10_share desc
```

<BandLink href="/players" name="Players" note="who scores, who gets booked" />

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-4">
    <Panel title="Top scorers" qualifier="all five leagues on one ranking" href="/players">
      <Rank dense={true} measure="Goals"
            rows={[...home_scorers].map((r) => ({ label: r.player_name, sublabel: r.code, value: r.goals, colour: r.colour, hint: r.league_name }))}
            format={f0} />
    </Panel>
  </div>

  <div class="xl:col-span-4">
    <Panel title="Top three per league" qualifier="the same question, league by league" href="/players">
      <div class="flex flex-col gap-2">
        {#each KEY as l}
          <div class="flex gap-2">
            <span class="w-[3px] flex-none rounded-[1px]" style="background:{l.colour}"></span>
            <div class="min-w-0 flex-1">
              <div class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">{l.code}</div>
              {#each [...home_top_per_league].filter((r) => r.league_name === l.league_name) as r, i}
                <div class="flex items-baseline gap-2">
                  <span class="min-w-0 flex-1 truncate text-[12px] {i === 0 ? 'font-medium text-gray-900' : 'text-gray-600'}">{r.player_name}</span>
                  <span class="text-[13px] font-semibold tabular-nums text-gray-900">{r.goals}</span>
                </div>
              {/each}
            </div>
          </div>
        {/each}
      </div>
    </Panel>
  </div>

  <div class="xl:col-span-4">
    <Panel title="How concentrated is scoring" qualifier="share of league goals from its top ten" href="/players">
      <div class="flex flex-col gap-2">
        {#each [...home_concentration] as c}
          <div class="flex items-center gap-2">
            <span class="w-8 flex-none text-[11px] font-semibold text-gray-600">{c.code}</span>
            <span class="flex h-5 min-w-0 flex-1 overflow-hidden rounded-[2px] bg-gray-100">
              <span class="flex items-center justify-center text-[10px] font-semibold text-white"
                    style="width:{c.top10_share}%; background:{c.colour};">{c.top10_share}%</span>
            </span>
          </div>
        {/each}
      </div>
    </Panel>
  </div>
</div>

<!-- ══ E · MATCHES ═════════════════════════════════════════════════════ -->

```sql big_wins
select m.league_name, l.colour, l.code, m.home_team, m.away_team, m.home_goals, m.away_goals,
       strftime(m.match_date, '%d %b %Y') as played_on, m.round_name
from crossleague.mart_matches m join crossleague.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by m.winning_margin desc, m.total_goals desc limit 7
```

```sql high_scoring
select m.league_name, l.colour, l.code, m.home_team, m.away_team, m.home_goals, m.away_goals,
       strftime(m.match_date, '%d %b %Y') as played_on, m.round_name
from crossleague.mart_matches m join crossleague.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by m.total_goals desc, m.winning_margin desc limit 7
```

```sql comebacks
select m.league_name, l.colour, l.code, m.comeback_by, m.home_team, m.away_team,
       m.home_goals, m.away_goals, m.home_goals_ht, m.away_goals_ht,
       strftime(m.match_date, '%d %b %Y') as played_on, m.round_name
from crossleague.mart_matches m join crossleague.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
  and m.comeback_by is not null
order by abs(m.home_goals_ht - m.away_goals_ht) desc, m.total_goals desc limit 7
```

<BandLink href="/matches" name="Matches" note="the shape of a match, scoreline by scoreline" />

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-3">
  <Panel title="Biggest wins" qualifier="by margin" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...big_wins] as m}
        <div class="group relative flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0 hover:bg-gray-50">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.home_team} v {m.away_team}</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
          <span class="pointer-events-none absolute bottom-full left-8 z-30 mb-1 hidden whitespace-nowrap rounded-[3px] bg-[#1d1d1f] px-2 py-1.5 text-[11px] leading-tight text-white shadow-lg group-hover:block">
            <span class="block font-semibold">{m.home_team} {m.home_goals}–{m.away_goals} {m.away_team}</span>
            <span class="block text-white/60">{m.played_on} · {m.round_name ?? '—'} · {m.league_name}</span>
          </span>
        </div>
      {/each}
    </div>
  </Panel>

  <Panel title="Most goals in a match" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...high_scoring] as m}
        <div class="group relative flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0 hover:bg-gray-50">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.home_team} v {m.away_team}</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
          <span class="pointer-events-none absolute bottom-full left-8 z-30 mb-1 hidden whitespace-nowrap rounded-[3px] bg-[#1d1d1f] px-2 py-1.5 text-[11px] leading-tight text-white shadow-lg group-hover:block">
            <span class="block font-semibold">{m.home_team} {m.home_goals}–{m.away_goals} {m.away_team}</span>
            <span class="block text-white/60">{m.played_on} · {m.round_name ?? '—'} · {m.league_name}</span>
          </span>
        </div>
      {/each}
    </div>
  </Panel>

  <Panel title="Comebacks" qualifier="trailed at the break, won" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...comebacks] as m}
        <div class="group relative flex items-center gap-2 border-b border-gray-100 py-[3px] last:border-0 hover:bg-gray-50">
          <span class="h-5 w-[3px] flex-none rounded-[1px]" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[10px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[12px] text-gray-800">{m.comeback_by}</span>
          <span class="text-[10px] tabular-nums text-gray-400">{m.home_goals_ht}–{m.away_goals_ht} HT</span>
          <span class="text-[13px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
          <span class="pointer-events-none absolute bottom-full left-8 z-30 mb-1 hidden whitespace-nowrap rounded-[3px] bg-[#1d1d1f] px-2 py-1.5 text-[11px] leading-tight text-white shadow-lg group-hover:block">
            <span class="block font-semibold">{m.home_team} {m.home_goals}–{m.away_goals} {m.away_team}</span>
            <span class="block text-white/60">{m.home_goals_ht}–{m.away_goals_ht} at the break · {m.played_on} · {m.round_name ?? '—'} · {m.league_name}</span>
          </span>
        </div>
      {/each}
    </div>
  </Panel>
</div>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
