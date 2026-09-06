---
sidebar: never
hide_toc: true
title: Cross-League Analytics
hide_title: true
description: Five top-flight leagues on three continents, measured the same way.
---

<script>
  import Panel from '../components/Panel.svelte';
  import Rank from '../components/Rank.svelte';
  import BandLink from '../components/BandLink.svelte';
  import Hero from '../components/Hero.svelte';
  import SiteFooter from '../components/SiteFooter.svelte';

  const f0 = (v) => Math.round(Number(v)).toLocaleString();
  const SERIES = {'La Liga':'#2a78d6','Liga MX':'#eb6834','Premiership':'#1baf7a','Superliga':'#eda100','Süper Lig':'#e87ba4'};
</script>

```sql last_updated
select last_updated from crossleague.last_updated
```

```sql day_range
select distinct match_date from crossleague.mart_club_day order by match_date
```

```sql scope
select
    count(distinct league_name) as leagues,
    sum(matches) / 2            as matches,
    sum(goals_for)              as goals
from crossleague.mart_club_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
```

<Hero leagueCount={scope[0]?.leagues} matches={scope[0]?.matches} goals={scope[0]?.goals} />

<div class="mb-4 flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
  <span class="text-[12px] font-semibold uppercase tracking-widest text-gray-400">Date range</span>
  <DateRange name=period data={day_range} dates=match_date defaultValue="Year to Today" />
</div>

<!-- ══ A · LEAGUES ═════════════════════════════════════════════════════ -->

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

<BandLink href="/leagues" name="Leagues" note="all five side by side, on every measure" />

<div class="mb-5">
  <Panel title="Goals per match" qualifier="by month" scope="all 20 measures on Leagues" href="/leagues">
    <LineChart data={trend} x=ym y=value series=league_name yAxisTitle=""
      seriesColors={SERIES} markers=true sort=false legend=false chartAreaHeight=300
      echartsOptions={{tooltip: {formatter: function(p) {
        const r = p.filter(x => x.value && x.value[1] != null && !isNaN(x.value[1])).sort((a,b) => b.value[1]-a.value[1]);
        if (!r.length) return '';
        let o = '<span style="font-weight:600;">' + p[0].axisValueLabel + '</span>';
        for (const x of r) o += '<br><span style="font-size:11px;">' + x.marker + ' ' + x.seriesName + '</span><span style="float:right;margin-left:14px;font-weight:600;">' + Number(x.value[1]).toFixed(2) + '</span>';
        return o; }}}}
    />
  </Panel>
</div>

<!-- ══ B · CLUBS ═══════════════════════════════════════════════════════ -->

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

```sql home_scatter_bounds
select
    (floor(min(gpm) * 10) / 10)::double  as x_min, (ceil(max(gpm) * 10) / 10)::double  as x_max,
    (floor(min(gapm) * 10) / 10)::double as y_min, (ceil(max(gapm) * 10) / 10)::double as y_max
from ${home_clubs} where gpm is not null and gapm is not null
```

<BandLink href="/clubs" name="Clubs" note="every club on one ranking, whatever the league" />

<div class="mb-5">
  <Panel title="Attack against defence" qualifier="one dot per club" scope="bottom right is where champions sit" href="/clubs">
    <ScatterPlot data={home_clubs} x=gpm y=gapm series=league_name
      xAxisTitle="Goals scored per match" yAxisTitle="Goals conceded per match"
      tooltipColumns={[{id: 'team_name', title: 'Club'}, {id: 'league_name'}, {id: 'gpm', title: 'Scored'}, {id: 'gapm', title: 'Conceded'}]}
      xMin={home_scatter_bounds[0].x_min} xMax={home_scatter_bounds[0].x_max}
      yMin={home_scatter_bounds[0].y_min} yMax={home_scatter_bounds[0].y_max}
      seriesColors={SERIES} tooltipTitle=team_name legend=false chartAreaHeight=300 />
  </Panel>
</div>

<!-- ══ C · PLAYERS ═════════════════════════════════════════════════════ -->

```sql home_scorers
select p.player_name, p.league_name, sum(p.goals) as goals, l.code, l.colour
from crossleague.mart_player_day p join crossleague.mart_leagues l on l.league_name = p.league_name
where p.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 4, 5
having sum(p.goals) > 0
order by goals desc, p.player_name limit 10
```

<BandLink href="/players" name="Players" note="who scores, who gets booked" />

<div class="mb-5">
  <Panel title="Top scorers" qualifier="all five leagues on one ranking" scope="top 20 and bookings on Players" href="/players">
    <Rank measure="Goals"
          rows={[...home_scorers].map((r) => ({ label: r.player_name, sublabel: r.code, value: r.goals, colour: r.colour, hint: r.league_name }))}
          format={f0} />
  </Panel>
</div>

<!-- ══ D · MATCHES ═════════════════════════════════════════════════════ -->

```sql big_wins
select m.league_name, l.colour, l.code, m.home_team, m.away_team, m.home_goals, m.away_goals,
       strftime(m.match_date, '%d %b %Y') as played_on, m.round_name
from crossleague.mart_matches m join crossleague.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by m.winning_margin desc, m.total_goals desc limit 7
```

<BandLink href="/matches" name="Matches" note="the shape of a match, scoreline by scoreline" />

<div class="mb-5">
  <Panel title="Biggest wins" qualifier="by margin" scope="every scoreline on Matches" href="/matches">
    <div class="flex h-full flex-col justify-between">
      {#each [...big_wins] as m}
        <div class="group relative flex items-center gap-2.5 border-b border-gray-100 py-[3px] last:border-0 hover:bg-gray-50">
          <span class="h-5 w-[3px] flex-none rounded-sm" style="background:{m.colour}"></span>
          <span class="w-7 flex-none text-[11px] font-semibold text-gray-400">{m.code}</span>
          <span class="min-w-0 flex-1 truncate text-[13px] text-gray-800">{m.home_team} v {m.away_team}</span>
          <span class="text-[14px] font-semibold tabular-nums text-gray-900">{m.home_goals}–{m.away_goals}</span>
          <span class="pointer-events-none absolute bottom-full left-8 z-30 mb-1 hidden whitespace-nowrap rounded-xl bg-[#1d1d1f] px-2 py-1.5 text-[12px] leading-tight text-white shadow-lg group-hover:block">
            <span class="block font-semibold">{m.home_team} {m.home_goals}–{m.away_goals} {m.away_team}</span>
            <span class="block text-white/60">{m.played_on} · {m.round_name ?? '—'} · {m.league_name}</span>
          </span>
        </div>
      {/each}
    </div>
  </Panel>
</div>

<a href="https://krogvadanalyticshub.vercel.app/" target="_blank" rel="noreferrer" class="group mt-10 mb-5 flex items-center gap-4 rounded-2xl px-5 py-4 no-underline transition-all duration-200 hover:shadow-md" style="background:#f5f5f7;">
  <div>
    <div class="text-[11px] font-semibold uppercase tracking-widest text-gray-400">Part of</div>
    <div class="text-base font-bold tracking-tight text-gray-900">Krogvad Analytics Hub</div>
    <div class="mt-0.5 text-sm text-gray-500">Every platform in the group — all powered by one shared data warehouse, refreshed every night.</div>
  </div>
  <span class="ml-auto text-gray-300 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-gray-500">→</span>
</a>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
