---
sidebar: never
hide_toc: true
title: Clubs
hide_title: true
---

<script>
  import Panel from '../../components/Panel.svelte';
  import Rank from '../../components/Rank.svelte';
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { leagues as KEY } from '../../components/navItems.js';

  const colourOf = Object.fromEntries(KEY.map((l) => [l.league_name, l.colour]));
  const codeOf   = Object.fromEntries(KEY.map((l) => [l.league_name, l.code]));
  const f2 = (v) => Number(v).toFixed(2);
  const f0 = (v) => Math.round(Number(v)).toLocaleString();

  // One series per club is the configuration that renders; the league hue is
  // kept by colouring each club's series with its league's colour.
  const clubColours = (rows) =>
    Object.fromEntries([...rows].map((r) => [r.team_name, colourOf[r.league_name]]));

  // Which league's clubs occupy the top of the ranking — the question a flat
  // club list cannot answer on its own.
  function ownership(rows) {
    const tally = {};
    for (const r of rows) tally[r.league_name] = (tally[r.league_name] ?? 0) + 1;
    const total = rows.length || 1;
    return KEY.map((l) => ({ code: l.code, colour: l.colour, name: l.league_name,
                             n: tally[l.league_name] ?? 0,
                             share: ((tally[l.league_name] ?? 0) / total) * 100 }))
      .sort((a, b) => b.n - a.n);
  }
</script>

```sql last_updated
select strftime(last_match, '%d %b %Y') as last_updated from crossleague.mart_last_updated
```

```sql day_range
select distinct match_date from crossleague.mart_club_day order by match_date
```

<div class="mb-5 flex flex-wrap items-center gap-x-5 gap-y-1 rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
  <span class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date defaultValue="Year to Today" />
  <Dropdown name=measure title="Measure" defaultValue="goals_for">
      <DropdownOption value="goals_for" valueLabel="Goals scored" />
      <DropdownOption value="goals_against" valueLabel="Goals conceded" />
      <DropdownOption value="points" valueLabel="Points" />
      <DropdownOption value="clean_sheets" valueLabel="Clean sheets %" />
      <DropdownOption value="shots" valueLabel="Shots on target" />
      <DropdownOption value="passes" valueLabel="Passes" />
      <DropdownOption value="pass_accuracy" valueLabel="Pass accuracy %" />
      <DropdownOption value="possession" valueLabel="Possession %" />
      <DropdownOption value="corners" valueLabel="Corners" />
      <DropdownOption value="fouls" valueLabel="Fouls" />
      <DropdownOption value="yellow_cards" valueLabel="Yellow cards" />
      <DropdownOption value="saves" valueLabel="Saves" />
  </Dropdown>
</div>

```sql clubs
with c as (
    select
        team_name, league_name,
        sum(matches)                                            as matches,
        (1.0 * sum(goals_for)      / nullif(sum(matches), 0))::double     as goals_for,
        (1.0 * sum(goals_against)  / nullif(sum(matches), 0))::double     as goals_against,
        (1.0 * sum(points)         / nullif(sum(matches), 0))::double     as points,
        (100.0 * sum(clean_sheets) / nullif(sum(matches), 0))::double     as clean_sheets,
        (1.0 * sum(shots_on_target)/ nullif(sum(n_shots), 0))::double     as shots,
        (1.0 * sum(passes)         / nullif(sum(n_passes), 0))::double    as passes,
        (100.0 * sum(passes_accurate) / nullif(sum(passes), 0))::double   as pass_accuracy,
        (1.0 * sum(corners)        / nullif(sum(n_corners), 0))::double   as corners,
        (1.0 * sum(possession)     / nullif(sum(n_possession), 0))::double as possession,
        (1.0 * sum(fouls)          / nullif(sum(n_fouls), 0))::double     as fouls,
        (1.0 * sum(yellow_cards)   / nullif(sum(n_cards), 0))::double     as yellow_cards,
        (1.0 * sum(saves)          / nullif(sum(n_saves), 0))::double     as saves,
        (100.0 * sum(wins)         / nullif(sum(matches), 0))::double     as win_pct
    from crossleague.mart_club_day
    where match_date between '${inputs.period.start}' and '${inputs.period.end}'
    group by 1, 2
)
select *,
    case '${inputs.measure.value}'
        when 'goals_for'      then goals_for      when 'goals_against' then goals_against
        when 'points'         then points         when 'clean_sheets'  then clean_sheets
        when 'shots'          then shots          when 'passes'        then passes
        when 'pass_accuracy'  then pass_accuracy  when 'corners'       then corners
        when 'fouls'          then fouls          when 'yellow_cards'  then yellow_cards
        when 'saves'          then saves          when 'possession'    then possession
    end                                                         as value
from c
where value is not null
order by value desc
```

```sql scope
select
    count(*)                as clubs,
    sum(matches) / 2        as matches,
    count(distinct league_name) as leagues,
    max(value)              as best,
    min(value)              as worst,
    round(avg(value), 2)    as average
from ${clubs}
```

<div class="mb-5 grid grid-cols-2 gap-2.5 md:grid-cols-4">
  <div class="flex h-[86px] flex-col justify-between rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
    <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">Clubs in view</div>
    <div class="text-[26px] font-semibold leading-none tabular-nums text-gray-900"><Value data={scope} column=clubs /></div>
    <div class="text-[12px] text-gray-500"><Value data={scope} column=leagues /> leagues</div>
  </div>
  <div class="flex h-[86px] flex-col justify-between rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
    <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">Highest</div>
    <div class="text-[26px] font-semibold leading-none tabular-nums text-gray-900"><Value data={scope} column=best fmt='#,##0.00' /></div>
    <div class="truncate text-[12px] text-gray-500">{clubs[0]?.team_name ?? '–'}</div>
  </div>
  <div class="flex h-[86px] flex-col justify-between rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
    <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">Average club</div>
    <div class="text-[26px] font-semibold leading-none tabular-nums text-gray-900"><Value data={scope} column=average fmt='#,##0.00' /></div>
    <div class="text-[12px] text-gray-500">across all clubs</div>
  </div>
  <div class="flex h-[86px] flex-col justify-between rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
    <div class="text-[11px] font-semibold uppercase tracking-wider text-gray-500">Lowest</div>
    <div class="text-[26px] font-semibold leading-none tabular-nums text-gray-900"><Value data={scope} column=worst fmt='#,##0.00' /></div>
    <div class="truncate text-[12px] text-gray-500">{[...clubs].at(-1)?.team_name ?? '–'}</div>
  </div>
</div>

<div class="mb-5 grid grid-cols-1 gap-2.5 xl:grid-cols-3">

  <div class="xl:col-span-2">
    <Panel title="Top 20 clubs" qualifier="on the selected measure">
      <Rank dense={true}
            measure={inputs.measure.label}
            rows={[...clubs].slice(0, 20).map((r) => ({ label: r.team_name, sublabel: codeOf[r.league_name], value: r.value, colour: colourOf[r.league_name], hint: r.league_name }))}
            format={f2} />
    </Panel>
  </div>

  <div>
    <Panel title="Who owns the top 20" qualifier="clubs in the leading twenty">
      <div class="flex flex-col gap-2.5">
        <div class="flex h-5 w-full overflow-hidden rounded-md">
          {#each ownership([...clubs].slice(0, 20)) as o}
            {#if o.n}
              <span class="flex items-center justify-center text-[11px] font-semibold text-white" style="width:{o.share}%; background:{o.colour};">{o.n}</span>
            {/if}
          {/each}
        </div>
        {#each ownership([...clubs].slice(0, 20)) as o}
          <div class="flex items-center gap-2.5 border-b border-gray-100 pb-1 last:border-0">
            <span class="h-4 w-[3px] flex-none rounded-sm" style="background:{o.colour}"></span>
            <span class="w-8 flex-none text-[11px] font-semibold text-gray-600">{o.code}</span>
            <span class="min-w-0 flex-1 truncate text-[12px] text-gray-500">{o.name}</span>
            <span class="text-[14px] font-semibold tabular-nums text-gray-900">{o.n}</span>
          </div>
        {/each}
      </div>
    </Panel>
  </div>
</div>

```sql club_table
select
    team_name                       as "Club",
    league_name                     as "League",
    matches                         as "Matches",
    round(goals_for, 2)             as "Goals for",
    round(goals_against, 2)         as "Goals against",
    round(points, 2)                as "Points",
    round(win_pct, 1)               as "Win %",
    round(clean_sheets, 1)          as "Clean sheet %",
    round(shots, 2)                 as "Shots on target",
    round(corners, 2)               as "Corners",
    round(passes, 0)                as "Passes",
    round(pass_accuracy, 1)         as "Pass accuracy %",
    round(possession, 1)            as "Possession %",
    round(fouls, 1)                 as "Fouls",
    round(yellow_cards, 2)          as "Yellow cards",
    round(saves, 2)                 as "Saves"
from ${clubs}
order by "Goals for" desc
```

<Panel title="Every club" qualifier="sortable; shading runs down each column" scope="per match, the club's own figures" pad={false}>
  <DataTable data={club_table} rows=20 rowShading=false sortable=true search=true>
    <Column id="Club" />
    <Column id="League" />
    <Column id="Matches" fmt='#,##0' />
    <Column id="Goals for" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Goals against" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Points" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Win %" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Clean sheet %" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Shots on target" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Corners" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Passes" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Pass accuracy %" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Possession %" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Fouls" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Yellow cards" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Saves" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
  </DataTable>
</Panel>

```sql best_attack
select team_name, league_name, round(goals_for, 2) as value
from ${clubs} where goals_for is not null order by goals_for desc limit 10
```

```sql best_defence
select team_name, league_name, round(goals_against, 2) as value
from ${clubs} where goals_against is not null order by goals_against asc limit 10
```

<div class="mt-5 mb-5 grid grid-cols-1 gap-2.5 xl:grid-cols-2">
  <Panel title="Best attacks" qualifier="goals scored per match">
    <Rank dense={true} measure="Goals scored per match"
          rows={[...best_attack].map((r) => ({ label: r.team_name, sublabel: codeOf[r.league_name], value: r.value, colour: colourOf[r.league_name], hint: r.league_name }))}
          format={f2} />
  </Panel>
  <Panel title="Best defences" qualifier="goals conceded per match, fewest first" scope="bar length is goals conceded">
    <Rank dense={true} measure="Goals conceded per match"
          rows={[...best_defence].map((r) => ({ label: r.team_name, sublabel: codeOf[r.league_name], value: r.value, colour: colourOf[r.league_name], hint: r.league_name }))}
          format={f2} />
  </Panel>
</div>

```sql scatter
select team_name, league_name,
       round(goals_for, 3)::double     as goals_for,
       round(goals_against, 3)::double as goals_against,
       matches
from ${clubs}
where goals_for is not null and goals_against is not null
```

```sql scatter_bounds
select
    (floor(min(goals_for) * 10) / 10)::double      as x_min,
    (ceil(max(goals_for) * 10) / 10)::double       as x_max,
    (floor(min(goals_against) * 10) / 10)::double  as y_min,
    (ceil(max(goals_against) * 10) / 10)::double   as y_max
from ${scatter}
```

<Panel title="Attack against defence" qualifier="one dot per club" scope="bottom right is where champions sit">
  <ScatterPlot data={scatter} x=goals_for y=goals_against series=league_name
    xAxisTitle="Goals scored per match" yAxisTitle="Goals conceded per match"
    tooltipColumns={[{id: 'team_name', title: 'Club'}, {id: 'league_name', title: 'League'}, {id: 'goals_for', title: 'Scored'}, {id: 'goals_against', title: 'Conceded'}, {id: 'matches', title: 'Matches'}]}
    xMin={scatter_bounds[0].x_min} xMax={scatter_bounds[0].x_max}
    yMin={scatter_bounds[0].y_min} yMax={scatter_bounds[0].y_max}
    seriesColors={ {'La Liga':'#2a78d6','Liga MX':'#eb6834','Premiership':'#1baf7a','Superliga':'#eda100','Süper Lig':'#e87ba4'} }
    tooltipTitle=team_name
    legend=false chartAreaHeight=300 />
</Panel>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
