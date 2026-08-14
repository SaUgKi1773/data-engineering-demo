---
sidebar: never
hide_toc: true
title: Players
hide_title: true
---

<script>
  import Panel from '../../components/Panel.svelte';
  import Rank from '../../components/Rank.svelte';
  import Kpi from '../../components/Kpi.svelte';
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { leagues as KEY } from '../../components/navItems.js';

  const colourOf = Object.fromEntries(KEY.map((l) => [l.league_name, l.colour]));
  const codeOf   = Object.fromEntries(KEY.map((l) => [l.league_name, l.code]));
  const SERIES   = Object.fromEntries(KEY.map((l) => [l.league_name, l.colour]));
  const f0 = (v) => Math.round(Number(v)).toLocaleString();
  const f1 = (v) => Number(v).toFixed(1);

  // The split bar always divides on the measure the tile is showing, so its
  // segment lengths and the headline answer the same question.
  function split(rows, key) {
    const total = rows.reduce((s, r) => s + Number(r[key] ?? 0), 0) || 1;
    return rows
      .map((r) => ({ name: r.league_name, colour: colourOf[r.league_name],
                     value: Number(r[key] ?? 0), share: (Number(r[key] ?? 0) / total) * 100 }))
      .sort((a, b) => b.share - a.share);
  }
  const total = (rows, key) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0);
  const leader = (rows, key) => split(rows, key).find((s) => s.value > 0) ?? null;
  // Never let an empty range print "undefined leads".
  const leads = (rows, key, verb) => {
    const l = leader(rows, key);
    return l ? `${l.name} ${verb}` : '–';
  };

  const asRank = (rows, key) =>
    [...rows].map((r) => ({ label: r.player_name, sublabel: codeOf[r.league_name],
                            value: r[key], colour: colourOf[r.league_name],
                            hint: r.team_name + ' · ' + r.league_name }));
</script>

```sql last_updated
select strftime(last_match, '%d %b %Y') as last_updated from cross_league.mart_last_updated
```

```sql day_range
select distinct match_date from cross_league.mart_player_day order by match_date
```

<div class="mb-2 flex flex-wrap items-center gap-x-5 gap-y-1 rounded-[3px] border border-gray-200 bg-white px-2 py-1.5">
  <span class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date defaultValue="Year to Today" />
  <Dropdown name=rank_by title="Rank scorers by" defaultValue="goals">
      <DropdownOption value="goals" valueLabel="Goals" />
      <DropdownOption value="share" valueLabel="Share of league goals" />
  </Dropdown>
  <span class="ml-auto text-[10px] text-gray-400">Goals are those credited to a player; a player's totals span every club he turned out for.</span>
</div>

```sql players
select
    player_name,
    league_name,
    arg_max(team_name, match_date)          as team_name,
    count(distinct team_name)               as clubs,
    sum(goals)                              as goals,
    sum(penalty_goals)                      as penalty_goals,
    sum(goals) - sum(penalty_goals)         as open_play_goals,
    sum(yellow_cards)                       as yellow_cards,
    sum(sent_off)                           as sent_off
from cross_league.mart_player_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
```

```sql league_events
select
    league_name,
    sum(goals)                                          as goals,
    sum(penalty_goals)                                  as penalty_goals,
    sum(yellow_cards)                                   as yellow_cards,
    sum(sent_off)                                       as sent_off,
    count(distinct player_name) filter (where goals > 0) as scorers
from cross_league.mart_player_day
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1
```


```sql overall
-- Counted across leagues, not summed from them: a player who moved between
-- leagues in the window is one scorer, not two.
select count(distinct player_name) as scorers
from cross_league.mart_player_day
where goals > 0 and match_date between '${inputs.period.start}' and '${inputs.period.end}'
```

{#await Promise.resolve() then _}
  {@const T = [...league_events]}

  <!-- ══ A · KPI STRIP ═══════════════════════════════════════════════════ -->
  <div class="mb-2 grid grid-cols-2 gap-px overflow-hidden rounded-[3px] border border-gray-200 bg-gray-200 md:grid-cols-5">
    <Kpi label="Goals" value={f0(total(T, 'goals'))}
         split={split(T, 'goals')} foot={leads(T, 'goals', 'scored most')}
         footColour={leader(T, 'goals')?.colour} />
    <Kpi label="Scorers" value={f0(overall[0]?.scorers ?? 0)}
         split={split(T, 'scorers')} foot="players who found the net"
         footColour={leader(T, 'scorers')?.colour} />
    <Kpi label="Penalty goals" value={f0(total(T, 'penalty_goals'))}
         split={split(T, 'penalty_goals')}
         foot="{f1(100 * total(T, 'penalty_goals') / (total(T, 'goals') || 1))}% of every goal"
         footColour={leader(T, 'penalty_goals')?.colour} />
    <Kpi label="Yellow cards" value={f0(total(T, 'yellow_cards'))}
         split={split(T, 'yellow_cards')} foot={leads(T, 'yellow_cards', 'booked most')}
         footColour={leader(T, 'yellow_cards')?.colour} />
    <Kpi label="Sent off" value={f0(total(T, 'sent_off'))}
         split={split(T, 'sent_off')} foot="reds and second yellows"
         footColour={leader(T, 'sent_off')?.colour} />
  </div>
{/await}

```sql players_ranked
-- Share of their own league's goals is the only fair cross-league player rate
-- available: goals per match would need appearances, and those exist for two
-- leagues of the five. Numerator and denominator come from the same window, so
-- a player is measured against exactly the football he played in.
select
    p.*,
    (100.0 * p.goals / nullif(e.goals, 0))::double as league_goal_share
from ${players} p
join ${league_events} e on e.league_name = p.league_name
```

```sql top_scorers
select player_name, league_name, team_name, goals, penalty_goals, league_goal_share
from ${players_ranked}
where goals > 0
order by case '${inputs.rank_by.value}' when 'share' then league_goal_share else goals end desc,
         player_name
limit 20
```

```sql top_per_league
select * from (
    select player_name, league_name, team_name, goals,
           row_number() over (partition by league_name order by goals desc, player_name) as rn
    from ${players} where goals > 0
) where rn <= 3 order by league_name, rn
```

<div class="mb-2 grid grid-cols-1 gap-2 xl:grid-cols-12">
  <div class="xl:col-span-8">
    <Panel title="Top 20 scorers" qualifier="all five leagues on one ranking" scope={inputs.rank_by.label}>
      {#if inputs.rank_by.value === 'share'}
        <Rank dense={true} measure="Share of league goals"
              rows={asRank([...top_scorers], 'league_goal_share')}
              format={(v) => Number(v).toFixed(2) + '%'} />
      {:else}
        <Rank dense={true} measure="Goals" rows={asRank([...top_scorers], 'goals')} format={f0} />
      {/if}
    </Panel>
  </div>

  <div class="xl:col-span-4">
    <Panel title="Top three per league" qualifier="the same question, league by league">
      <div class="flex flex-col gap-2">
        {#each KEY as l}
          {@const three = [...top_per_league].filter((r) => r.league_name === l.league_name)}
          <div class="flex gap-2">
            <span class="w-[3px] flex-none rounded-[1px]" style="background:{l.colour}"></span>
            <div class="min-w-0 flex-1">
              <div class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">{l.code} · {l.league_name}</div>
              {#each three as r, i}
                <div class="flex items-baseline gap-2">
                  <span class="w-3 flex-none text-[10px] tabular-nums text-gray-400">{i + 1}</span>
                  <span class="min-w-0 flex-1 truncate text-[12px] {i === 0 ? 'font-medium text-gray-900' : 'text-gray-600'}" title={r.team_name}>{r.player_name}</span>
                  <span class="text-[13px] font-semibold tabular-nums text-gray-900">{r.goals}</span>
                </div>
              {/each}
              {#if !three.length}
                <div class="text-[12px] text-gray-400">–</div>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    </Panel>
  </div>
</div>

```sql player_table
select
    player_name                                                     as "Player",
    team_name                                                       as "Club",
    league_name                                                     as "League",
    goals                                                           as "Goals",
    round(league_goal_share, 2)                                     as "Share of league goals %",
    open_play_goals                                                 as "Open play",
    penalty_goals                                                   as "Penalties",
    round(100.0 * penalty_goals / nullif(goals, 0), 1)              as "Penalty %",
    yellow_cards                                                    as "Yellow cards",
    sent_off                                                        as "Sent off"
from ${players_ranked}
where goals > 0 or yellow_cards > 0 or sent_off > 0
order by "Goals" desc, "Player"
```

<Panel title="Every player" qualifier="sortable; shading runs down each column" scope="club shown is the most recent" pad={false}>
  <DataTable data={player_table} rows=20 rowShading=false sortable=true search=true>
    <Column id="Player" />
    <Column id="Club" />
    <Column id="League" />
    <Column id="Goals" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Share of league goals %" fmt='0.00' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Open play" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Penalties" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Penalty %" fmt='0.0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Yellow cards" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
    <Column id="Sent off" fmt='#,##0' contentType=colorscale colorScale={['#eef2f7', '#1f3f6b']} />
  </DataTable>
</Panel>

```sql most_yellows
select player_name, league_name, team_name, yellow_cards
from ${players} where yellow_cards > 0 order by yellow_cards desc, player_name limit 10
```

```sql most_sent_off
select player_name, league_name, team_name, sent_off
from ${players} where sent_off > 0 order by sent_off desc, player_name limit 10
```

```sql concentration
with ranked as (
    select league_name, goals,
           row_number() over (partition by league_name order by goals desc) as rn,
           sum(goals) over (partition by league_name)                       as league_goals
    from ${players} where goals > 0
)
select
    league_name,
    max(league_goals)                                                       as league_goals,
    sum(goals) filter (where rn <= 10)                                      as top10_goals,
    round(100.0 * sum(goals) filter (where rn <= 10) / nullif(max(league_goals), 0), 1) as top10_share
from ranked group by 1 order by top10_share desc
```

<div class="mt-2 mb-2 grid grid-cols-1 gap-2 xl:grid-cols-3">
  <Panel title="Most booked" qualifier="yellow cards">
    <Rank dense={true} measure="Yellow cards" rows={asRank([...most_yellows], 'yellow_cards')} format={f0} />
  </Panel>

  <Panel title="Most sent off" qualifier="reds and second yellows">
    <Rank dense={true} measure="Sent off" rows={asRank([...most_sent_off], 'sent_off')} format={f0} />
  </Panel>

  <Panel title="How concentrated is scoring" qualifier="share of league goals from its top ten scorers">
    <div class="flex flex-col gap-2">
      {#each [...concentration] as c}
        <div class="flex items-center gap-2">
          <span class="w-8 flex-none text-[11px] font-semibold text-gray-600">{codeOf[c.league_name]}</span>
          <span class="flex h-5 min-w-0 flex-1 overflow-hidden rounded-[2px] bg-gray-100">
            <span class="flex items-center justify-center text-[10px] font-semibold text-white"
                  style="width:{c.top10_share}%; background:{colourOf[c.league_name]};">{c.top10_share}%</span>
          </span>
          <span class="w-16 flex-none text-right text-[11px] tabular-nums text-gray-400">{f0(c.top10_goals)} / {f0(c.league_goals)}</span>
        </div>
      {/each}
      <div class="mt-0.5 text-[10px] text-gray-400">Bar is the top ten's share; the figures are their goals against the league's total.</div>
    </div>
  </Panel>
</div>

```sql booking_clock
select
    minute_bucket, minute_bucket_sort, league_name,
    round(100.0 * sum(events) / nullif(sum(sum(events)) over (partition by league_name), 0), 2) as share
from cross_league.mart_event_clock
where event_group = 'Card' and match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 3
order by minute_bucket_sort, league_name
```

```sql sub_clock
select
    minute_bucket, minute_bucket_sort, league_name,
    round(100.0 * sum(events) / nullif(sum(sum(events)) over (partition by league_name), 0), 2) as share
from cross_league.mart_event_clock
where event_group = 'Substitution' and match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2, 3
order by minute_bucket_sort, league_name
```

<div class="grid grid-cols-1 gap-2 xl:grid-cols-2">
  <Panel title="When players are booked" qualifier="share of each league's cards, by quarter-hour">
    <BarChart data={booking_clock} x=minute_bucket y=share series=league_name type=stacked
      yAxisTitle="" seriesColors={SERIES} sort=false legend=false chartAreaHeight=210
      echartsOptions={{tooltip: {formatter: function(p) {
        const r = p.filter(x => x.value && x.value[1] != null && !isNaN(x.value[1])).sort((a,b) => b.value[1]-a.value[1]);
        if (!r.length) return '';
        let o = '<span style="font-weight:600;">' + p[0].axisValueLabel + '</span>';
        for (const x of r) o += '<br><span style="font-size:11px;">' + x.marker + ' ' + x.seriesName + '</span><span style="float:right;margin-left:14px;font-weight:600;">' + Number(x.value[1]).toFixed(1) + '%</span>';
        return o; }}}}
    />
  </Panel>

  <Panel title="When substitutions happen" qualifier="share of each league's substitutions, by quarter-hour">
    <BarChart data={sub_clock} x=minute_bucket y=share series=league_name type=stacked
      yAxisTitle="" seriesColors={SERIES} sort=false legend=false chartAreaHeight=210
      echartsOptions={{tooltip: {formatter: function(p) {
        const r = p.filter(x => x.value && x.value[1] != null && !isNaN(x.value[1])).sort((a,b) => b.value[1]-a.value[1]);
        if (!r.length) return '';
        let o = '<span style="font-weight:600;">' + p[0].axisValueLabel + '</span>';
        for (const x of r) o += '<br><span style="font-size:11px;">' + x.marker + ' ' + x.seriesName + '</span><span style="float:right;margin-left:14px;font-weight:600;">' + Number(x.value[1]).toFixed(1) + '%</span>';
        return o; }}}}
    />
  </Panel>
</div>

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
