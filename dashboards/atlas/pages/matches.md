---
sidebar: never
hide_toc: true
title: Matches
hide_title: true
---

<script>
  import Panel from '../../components/Panel.svelte';
  import Rank from '../../components/Rank.svelte';
  import Kpi from '../../components/Kpi.svelte';
  import HeatGrid from '../../components/HeatGrid.svelte';
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { leagues as KEY } from '../../components/navItems.js';

  const colourOf = Object.fromEntries(KEY.map((l) => [l.league_name, l.colour]));
  const codeOf   = Object.fromEntries(KEY.map((l) => [l.league_name, l.code]));
  const SERIES   = Object.fromEntries(KEY.map((l) => [l.league_name, l.colour]));
  const f0 = (v) => Math.round(Number(v)).toLocaleString();
  const f1 = (v) => Number(v).toFixed(1);

  function split(rows, key) {
    const total = rows.reduce((s, r) => s + Number(r[key] ?? 0), 0) || 1;
    return rows
      .map((r) => ({ name: r.league_name, colour: colourOf[r.league_name],
                     value: Number(r[key] ?? 0), share: (Number(r[key] ?? 0) / total) * 100 }))
      .sort((a, b) => b.share - a.share);
  }
  const total  = (rows, key) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0);
  const leader = (rows, key) => split(rows, key).find((s) => s.value > 0) ?? null;
  const leads  = (rows, key, verb) => {
    const l = leader(rows, key);
    return l ? `${l.name} ${verb}` : '–';
  };

  // The grids are keyed `row|col`; both queries already emit those labels.
  const toCells = (rows, r, c, v) =>
    Object.fromEntries([...rows].map((x) => [`${x[r]}|${x[c]}`, x[v]]));

  const SCORES = ['0', '1', '2', '3', '4', '5+'];
  const HT_STATES = ['Home ahead', 'Level', 'Away ahead'];
  const FT_STATES = ['Home win', 'Draw', 'Away win'];
</script>

```sql last_updated
select strftime(last_match, '%d %b %Y') as last_updated from atlas.mart_last_updated
```

```sql day_range
select distinct match_date from atlas.mart_matches order by match_date
```

<div class="mb-2 flex flex-wrap items-center gap-x-5 gap-y-1 rounded-[3px] border border-gray-200 bg-white px-2 py-1.5">
  <span class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date defaultValue="Year to Today" />
  <span class="ml-auto text-[10px] text-gray-400">One row per match. Home side is named first throughout.</span>
</div>

```sql league_totals
select
    league_name,
    count(*)                                                    as matches,
    sum(total_goals)                                            as goals,
    count(*) filter (where total_goals = 0)                     as goalless,
    count(*) filter (where home_goals > 0 and away_goals > 0)   as both_scored,
    count(*) filter (where comeback_by is not null)             as comebacks,
    count(*) filter (where home_goals_ht is not null
                       and away_goals_ht is not null)           as half_time_known
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1
```

{#await Promise.resolve() then _}
  {@const T = [...league_totals]}

  <!-- ══ A · KPI STRIP ═══════════════════════════════════════════════════ -->
  <div class="mb-2 grid grid-cols-2 gap-px overflow-hidden rounded-[3px] border border-gray-200 bg-gray-200 md:grid-cols-5">
    <Kpi label="Matches" value={f0(total(T, 'matches'))}
         split={split(T, 'matches')} foot={leads(T, 'matches', 'played most')}
         footColour={leader(T, 'matches')?.colour} />
    <Kpi label="Goals" value={f0(total(T, 'goals'))}
         split={split(T, 'goals')} foot={leads(T, 'goals', 'scored most')}
         footColour={leader(T, 'goals')?.colour} />
    <Kpi label="Goalless" value={f0(total(T, 'goalless'))}
         split={split(T, 'goalless')}
         foot="{f1(100 * total(T, 'goalless') / (total(T, 'matches') || 1))}% of every match"
         footColour={leader(T, 'goalless')?.colour} />
    <Kpi label="Both teams scored" value={f0(total(T, 'both_scored'))}
         split={split(T, 'both_scored')}
         foot="{f1(100 * total(T, 'both_scored') / (total(T, 'matches') || 1))}% of every match"
         footColour={leader(T, 'both_scored')?.colour} />
    <Kpi label="Comebacks" value={f0(total(T, 'comebacks'))}
         split={split(T, 'comebacks')} foot="behind at the break, won"
         footColour={leader(T, 'comebacks')?.colour} />
  </div>
{/await}

```sql scoreline
select
    least(home_goals, 5)::int::varchar || case when home_goals >= 5 then '+' else '' end as home_score,
    least(away_goals, 5)::int::varchar || case when away_goals >= 5 then '+' else '' end as away_score,
    round(100.0 * count(*) / sum(count(*)) over (), 2)                                   as share
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
```

```sql margin
select
    l.code,
    case when m.winning_margin >= 4 then '4+' else m.winning_margin::int::varchar end   as margin,
    round(100.0 * count(*) / sum(count(*)) over (partition by l.code), 2)               as share
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
order by margin, l.code
```

```sql goals_in_match
select
    l.code,
    case when m.total_goals >= 6 then '6+' else m.total_goals::int::varchar end          as goals,
    round(100.0 * count(*) / sum(count(*)) over (partition by l.code), 2)                as share
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
order by goals, l.code
```

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-5">
    <Panel title="Every scoreline" qualifier="% of all matches" scope="home down, away across">
      <HeatGrid rows={SCORES} cols={SCORES} cells={toCells(scoreline, 'home_score', 'away_score', 'share')}
                rowTitle="Home" colTitle="Away" format={(v) => Number(v).toFixed(1)} />
    </Panel>
  </div>

  <div class="xl:col-span-3">
    <Panel title="Winning margin" qualifier="% of each league's matches">
      <BarChart data={margin} x=margin y=share series=code type=grouped
        yAxisTitle="" xAxisTitle="" seriesColors={ {'ESP':'#2a78d6','MEX':'#eb6834','SCO':'#1baf7a','DEN':'#eda100','TUR':'#e87ba4'} }
        sort=false legend=false chartAreaHeight=200 />
    </Panel>
  </div>

  <div class="xl:col-span-4">
    <Panel title="Goals in a match" qualifier="% of each league's matches">
      <BarChart data={goals_in_match} x=goals y=share series=code type=grouped
        yAxisTitle="" xAxisTitle="" seriesColors={ {'ESP':'#2a78d6','MEX':'#eb6834','SCO':'#1baf7a','DEN':'#eda100','TUR':'#e87ba4'} }
        sort=false legend=false chartAreaHeight=200 />
    </Panel>
  </div>
</div>

```sql ht_ft
select
    case when home_goals_ht > away_goals_ht then 'Home ahead'
         when home_goals_ht < away_goals_ht then 'Away ahead' else 'Level' end   as ht,
    case when home_goals > away_goals then 'Home win'
         when home_goals < away_goals then 'Away win'  else 'Draw' end           as ft,
    round(100.0 * count(*) / sum(count(*)) over (), 2)                           as share
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
  and home_goals_ht is not null and away_goals_ht is not null
group by 1, 2
```

```sql comeback_rate
select
    l.code, l.colour, m.league_name,
    round(100.0 * count(*) filter (where m.comeback_by is not null)
        / nullif(count(*) filter (where m.home_goals_ht is not null and m.away_goals_ht is not null), 0), 2) as rate
from atlas.mart_matches m join atlas.mart_leagues l on l.league_name = m.league_name
where m.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 3
order by rate desc
```

```sql turnarounds
select
    comeback_by                                                     as winner,
    league_name,
    home_team || ' ' || home_goals::int || '–' || away_goals::int || ' ' || away_team as fixture,
    strftime(match_date, '%d %b %Y')                                as played,
    abs(home_goals_ht - away_goals_ht)::int                         as deficit,
    home_goals_ht::int || '–' || away_goals_ht::int                 as at_the_break
from atlas.mart_matches
where comeback_by is not null
  and match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by deficit desc, abs(home_goals - away_goals) desc
limit 10
```

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-4">
    <Panel title="Half-time to full-time" qualifier="% of all matches" scope="break down, final across">
      <HeatGrid rows={HT_STATES} cols={FT_STATES} cells={toCells(ht_ft, 'ht', 'ft', 'share')}
                rowTitle="At the break" colTitle="Final" format={(v) => Number(v).toFixed(1)} />
    </Panel>
  </div>

  <div class="xl:col-span-3">
    <Panel title="Comeback rate" qualifier="% of matches won from behind at the break">
      <Rank measure="Comeback rate" showRank={false} compact={true}
            rows={[...comeback_rate].map((r) => ({ label: r.league_name, sublabel: r.code, value: r.rate, colour: r.colour }))}
            format={(v) => Number(v).toFixed(2) + '%'} />
    </Panel>
  </div>

  <div class="xl:col-span-5">
    <Panel title="Biggest turnarounds" qualifier="deepest half-time deficit overturned" pad={false}>
      <div class="flex flex-col">
        {#each [...turnarounds] as t, i}
          <div class="flex items-center gap-2 border-b border-gray-100 px-2 py-1 last:border-0">
            <span class="w-4 flex-none text-right text-[10px] tabular-nums text-gray-400">{i + 1}</span>
            <span class="h-4 w-[3px] flex-none rounded-[1px]" style="background:{colourOf[t.league_name]}"></span>
            <div class="min-w-0 flex-1">
              <div class="truncate text-[12px] font-medium text-gray-900">{t.fixture}</div>
              <div class="text-[10px] text-gray-400">{codeOf[t.league_name]} · {t.played} · {t.at_the_break} at the break</div>
            </div>
            <span class="flex-none text-right">
              <span class="text-[13px] font-semibold tabular-nums text-gray-900">{t.deficit}</span>
              <span class="text-[10px] text-gray-400"> down</span>
            </span>
          </div>
        {/each}
      </div>
    </Panel>
  </div>
</div>

```sql match_table
select
    strftime(match_date, '%Y-%m-%d')                                as "Date",
    league_name                                                     as "League",
    round_name                                                      as "Round",
    home_team                                                       as "Home",
    home_goals::int || '–' || away_goals::int                       as "Score",
    away_team                                                       as "Away",
    coalesce(home_goals_ht::int || '–' || away_goals_ht::int, '–')  as "Half-time",
    total_goals::int                                                as "Goals",
    winning_margin::int                                             as "Margin"
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by match_date desc, "Home"
```

<Panel title="Every match" qualifier="sortable and searchable; newest first" pad={false}>
  <DataTable data={match_table} rows=15 rowShading=false sortable=true search=true>
    <Column id="Date" />
    <Column id="League" />
    <Column id="Round" />
    <Column id="Home" />
    <Column id="Score" align=center />
    <Column id="Away" />
    <Column id="Half-time" align=center />
    <Column id="Goals" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Margin" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
  </DataTable>
</Panel>

```sql biggest_wins
select
    home_team || ' ' || home_goals::int || '–' || away_goals::int || ' ' || away_team as fixture,
    league_name, strftime(match_date, '%d %b %Y') as played, winning_margin::int as margin
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by winning_margin desc, total_goals desc limit 10
```

```sql highest_scoring
select
    home_team || ' ' || home_goals::int || '–' || away_goals::int || ' ' || away_team as fixture,
    league_name, strftime(match_date, '%d %b %Y') as played, total_goals::int as goals
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
order by total_goals desc, winning_margin desc limit 10
```

<div class="mt-2 grid grid-cols-1 gap-2 xl:grid-cols-2">
  <Panel title="Biggest wins" qualifier="widest winning margin">
    <Rank dense={true} measure="Winning margin" showRank={true}
          rows={[...biggest_wins].map((r) => ({ label: r.fixture, sublabel: codeOf[r.league_name], value: r.margin, colour: colourOf[r.league_name], hint: r.played }))}
          format={f0} />
  </Panel>

  <Panel title="Highest scoring" qualifier="most goals in one match">
    <Rank dense={true} measure="Goals in the match" showRank={true}
          rows={[...highest_scoring].map((r) => ({ label: r.fixture, sublabel: codeOf[r.league_name], value: r.goals, colour: colourOf[r.league_name], hint: r.played }))}
          format={f0} />
  </Panel>
</div>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
