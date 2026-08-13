---
sidebar: never
hide_toc: true
title: Leagues
hide_title: true
---

<script>
  import Panel from '../../components/Panel.svelte';
  import Matrix from '../../components/Matrix.svelte';
  import MiniBars from '../../components/MiniBars.svelte';
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { leagues as KEY, codeOf, colourOf } from '../../components/navItems.js';

  const CODES = KEY.map((l) => ({ code: l.code, colour: l.colour }));
  const f2 = (v) => Number(v).toFixed(2);
  const f1 = (v) => Number(v).toFixed(1);
  const f0 = (v) => Math.round(Number(v)).toLocaleString();

  // One row of the matrix / one small-multiple tile. `pick` reads the measure
  // off a league's aggregate row; everything else is presentation.
  const M = (group, measure, pick, format = f2) => ({ group, measure, pick, format });

  const MEASURES = [
    M('attack', 'Goals',            (d) => d.goals / d.matches),
    M('attack', 'Shots on target',  (d) => d.shots / d.n_shots),
    M('attack', 'Corners',          (d) => d.corners / d.n_corners),
    M('attack', 'Passes',           (d) => d.passes / d.n_passes, f0),
    M('attack', 'Pass accuracy %',  (d) => 100 * d.passes_accurate / d.passes, f1),
    M('attack', 'Home win %',       (d) => 100 * d.home_wins / d.matches, f1),
    M('control','Home points',      (d) => d.home_points / d.matches),
    M('attack', 'First-half goals', (d) => d.goals_ht / d.matches),
    M('attack', 'Second-half goals',(d) => (d.goals - d.goals_ht) / d.matches),
    M('attack', '5+ goal games %',  (d) => 100 * d.big_games / d.matches, f1),

    M('discipline','Fouls',         (d) => d.fouls / d.n_fouls, f1),
    M('discipline','Yellow cards',  (d) => d.yellow_cards / d.n_cards),
    M('discipline','Red cards',     (d) => d.red_cards / d.n_cards),
    M('discipline','Offsides',      (d) => d.offsides / d.n_offsides),
    M('control','Saves',            (d) => d.saves / d.n_saves),
    M('control','Clean sheet %',    (d) => 100 * d.clean_sheets / (d.matches * 2), f1),
    M('results','Draw %',           (d) => 100 * d.draws / d.matches, f1),
    M('attack', 'Both scored %',    (d) => 100 * d.btts / d.matches, f1),
    M('results','0-0 %',            (d) => 100 * d.nil_nil / d.matches, f1),
    M('results','Comeback %',       (d) => 100 * d.comebacks / d.matches, f1)
  ];

  // Merge the two aggregates (club fact + match fact) into one row per league,
  // then evaluate every measure once. Everything below reads from this.
  function build(clubRows, matchRows) {
    const byLeague = {};
    for (const r of clubRows ?? []) byLeague[r.league_name] = { ...r };
    for (const r of matchRows ?? []) byLeague[r.league_name] = { ...(byLeague[r.league_name] ?? {}), ...r };
    return byLeague;
  }
  const valuesFor = (d, pick) =>
    Object.fromEntries(KEY.map((l) => {
      const row = d[l.league_name];
      if (!row) return [l.code, null];
      const v = pick(row);
      return [l.code, v == null || isNaN(v) || !isFinite(v) ? null : v];
    }));

  const matrixRows = (d, groups) =>
    MEASURES.filter((m) => groups.includes(m.group))
      .map((m) => ({ measure: m.measure, format: m.format, values: valuesFor(d, m.pick) }));

  const tileRows = (d, m) =>
    KEY.map((l) => ({ code: l.code, colour: l.colour, value: valuesFor(d, m.pick)[l.code] }))
      .filter((r) => r.value != null)
      .sort((a, b) => b.value - a.value);
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
    sum(points) filter (where team_side = 'Home')       as home_points,
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

```sql match_totals
select
    league_name,
    count(*)                                                        as m_matches,
    sum(coalesce(home_goals_ht, 0) + coalesce(away_goals_ht, 0))    as goals_ht,
    count(*) filter (where total_goals >= 5)                        as big_games,
    count(*) filter (where home_goals > 0 and away_goals > 0)       as btts,
    count(*) filter (where total_goals = 0)                         as nil_nil,
    count(*) filter (where comeback_by is not null)                 as comebacks
from atlas.mart_matches
where match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1
```

<div class="flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-gray-200 bg-white px-2 py-1.5 mb-2 rounded-[3px]">
  <span class="text-[10px] font-semibold uppercase tracking-wider text-gray-500">Date range</span>
  <DateRange name=period data={day_range} dates=match_date />
  <span class="ml-auto text-[10px] text-gray-400">All five leagues, always. Per match, both teams combined.</span>
</div>

{#await Promise.resolve() then _}
  {@const D = build([...club_totals], [...match_totals])}

  <!-- ══ A · LEAGUE HEADERS ══════════════════════════════════════════════ -->
  <div class="grid grid-cols-2 gap-2 md:grid-cols-5 mb-2">
    {#each KEY as l}
      {@const d = D[l.league_name]}
      {@const gpm = d ? d.goals / d.matches : null}
      {@const rank = KEY.map((x) => D[x.league_name]).filter(Boolean)
                        .map((x) => x.goals / x.matches).sort((a, b) => b - a)
                        .indexOf(gpm) + 1}
      <div class="overflow-hidden rounded-[3px] border border-gray-200 bg-white">
        <div class="h-[3px] w-full" style="background:{l.colour}"></div>
        <div class="px-2 py-1.5">
          <div class="flex items-baseline gap-1.5">
            <span class="text-[11px] font-semibold text-gray-500">{l.code}</span>
            <span class="truncate text-[12px] font-medium text-gray-900">{l.league_name}</span>
          </div>
          <div class="mt-0.5 flex items-baseline gap-2">
            <span class="text-[15px] font-semibold tabular-nums text-gray-900">{d ? f2(gpm) : '–'}</span>
            <span class="text-[10px] text-gray-400">goals/match</span>
            {#if d}<span class="ml-auto text-[10px] font-semibold text-gray-500">#{rank}</span>{/if}
          </div>
          <div class="text-[10px] tabular-nums text-gray-400">{d ? f0(d.matches) : '–'} matches</div>
        </div>
      </div>
    {/each}
  </div>

  <!-- ══ B · THE MATRIX ══════════════════════════════════════════════════ -->
  <div class="grid grid-cols-1 gap-2 xl:grid-cols-2 mb-2">
    <Panel title="Attack & volume">
      <Matrix codes={CODES} rows={matrixRows(D, ['attack'])} />
    </Panel>
    <Panel title="Discipline, control & results">
      <Matrix codes={CODES} rows={matrixRows(D, ['discipline', 'control', 'results'])} />
    </Panel>
  </div>

  <!-- ══ C · SMALL MULTIPLES ═════════════════════════════════════════════ -->
  <Panel title="Every measure" qualifier="five leagues, sorted highest first" scope="{MEASURES.length} measures">
    <div class="grid grid-cols-2 gap-1.5 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
      {#each MEASURES as m}
        <MiniBars title={m.measure} rows={tileRows(D, m)} format={m.format} />
      {/each}
    </div>
  </Panel>
{/await}

<div class="mt-2 grid grid-cols-1 gap-2 xl:grid-cols-3">
  <div class="xl:col-span-2">

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

    <Panel title="Goals per match by calendar year" qualifier="a league appears from its first covered year">
      <LineChart data={trend} x=yr y=value series=league_name yAxisTitle=""
        seriesColors={ {'La Liga':'#2a78d6','Liga MX':'#eb6834','Premiership':'#1baf7a','Superliga':'#eda100','Süper Lig':'#e87ba4'} }
        markers=true sort=false legend=false chartAreaHeight=200
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

```sql venue
select
    l.code,
    l.colour,
    round(100.0 * sum(c.wins) filter (where c.team_side = 'Home') / nullif(sum(c.matches) / 2, 0), 1) as home_share,
    round(100.0 * sum(c.draws) / 2 / nullif(sum(c.matches) / 2, 0), 1)                                as draw_share,
    round(100.0 * sum(c.wins) filter (where c.team_side = 'Away') / nullif(sum(c.matches) / 2, 0), 1) as away_share
from atlas.mart_club_day c join atlas.mart_leagues l on l.league_name = c.league_name
where c.match_date between '${inputs.period.start}' and '${inputs.period.end}'
group by 1, 2
order by home_share desc
```

    <Panel title="Result mix" qualifier="share of matches" scope="sorted by home wins">
      <div class="flex flex-col gap-1.5">
        {#each [...venue] as v}
          <div class="flex items-center gap-2">
            <span class="w-8 flex-none text-[11px] font-semibold text-gray-600">{v.code}</span>
            <span class="flex h-4 min-w-0 flex-1 overflow-hidden rounded-[2px]">
              <span class="flex items-center justify-center text-[9px] font-semibold text-white" style="width:{v.home_share}%; background:{v.colour};">{v.home_share}</span>
              <span class="flex items-center justify-center bg-gray-300 text-[9px] font-semibold text-gray-700" style="width:{v.draw_share}%;">{v.draw_share}</span>
              <span class="flex items-center justify-center bg-gray-100 text-[9px] font-semibold text-gray-500" style="width:{v.away_share}%;">{v.away_share}</span>
            </span>
          </div>
        {/each}
        <div class="mt-0.5 flex gap-3 text-[9px] text-gray-400">
          <span>■ home win</span><span>■ draw</span><span>■ away win</span>
        </div>
      </div>
    </Panel>
  </div>
</div>

<SiteFooter />
