---
sidebar: never
hide_toc: true
title: Standings
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

```sql tournaments
select tournament from (
  select tournament, max(is_current_tournament::int) as is_current
  from ligamx.mart_standings
  group by tournament
) order by is_current desc, tournament desc
```

```sql rounds
select max(round) as max_round
from ligamx.mart_standings
where tournament = '${inputs.tournament.value}'
```

<details class="mb-6 rounded-xl border border-emerald-100 bg-emerald-50">
  <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-emerald-800 flex items-center gap-2">
    ℹ️ How does the Liga MX season work?
  </summary>
  <div class="px-4 pb-4 pt-2 text-sm text-gray-700 space-y-3">
    <p><strong>Two championships every year, not one.</strong> A Liga MX season is split into two entirely separate competitions: the <strong>Apertura</strong> (July–December) and the <strong>Clausura</strong> (January–May). Each has its own table, its own knockout, and its own champion. A club can win the Apertura and finish bottom of the Clausura five months later — they are not two halves of one season.</p>
    <p><strong>Everyone plays everyone once.</strong> 18 clubs, 17 rounds, a single round-robin. A table is complete at 17 games, roughly half the length of a European league season, so a bad month costs far more here.</p>
    <p><strong>Topping the table does not win you anything.</strong> This is the part that surprises people. The regular season only <em>seeds</em> the knockout — the <strong>liguilla</strong> — which is where the title is actually decided:</p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>🟢 <strong>1st–6th</strong> → straight into the liguilla quarter-finals</li>
      <li>🟡 <strong>7th–10th</strong> → the <strong>play-in</strong>, competing for the last two places</li>
      <li>⚪ <strong>11th–18th</strong> → season over</li>
    </ul>
    <p>Every liguilla tie is played over two legs, and the club finishing higher in the table gets the advantage of hosting the second one. In Clausura 2025 Toluca topped the table <em>and</em> won the title — but 3rd-placed Cruz Azul reached the semi-finals while 5th-placed Necaxa went out in the quarters. The table is a seeding, not a verdict.</p>
    <p><strong>No relegation.</strong> Unlike the other leagues on this platform, nobody goes down — relegation is currently suspended in Liga MX, so the bottom of the table carries no jeopardy.</p>
  </div>
</details>

<Dropdown data={tournaments} name=tournament value=tournament title="Tournament" defaultValue={tournaments[0].tournament} />

<!-- Keyed on the tournament: each one has its own round count, and without this
     the slider keeps the previous tournament's maximum when you switch. -->
{#key `${inputs.tournament.value}:${rounds[0]?.max_round}`}
<Slider
  title="Table as of round"
  name=upto
  min=1
  max={rounds[0]?.max_round ?? 17}
  defaultValue={rounds[0]?.max_round ?? 17}
/>
{/key}

```sql table
with played as (
    select *
    from ligamx.mart_standings
    where tournament = '${inputs.tournament.value}'
      -- guarded: the slider has no value on first render, and an unguarded
      -- comparison there returns an empty table
      and round <= ${inputs.upto ?? 999}
),
agg as (
    select
        team_sk,
        any_value(team_name)       as team_name,
        any_value(team_short_name) as team_short_name,
        any_value(team_logo)       as team_logo,
        count(*)                                        as played,
        sum(case when result = 'Win'  then 1 else 0 end) as won,
        sum(case when result = 'Draw' then 1 else 0 end) as drawn,
        sum(case when result = 'Loss' then 1 else 0 end) as lost,
        sum(goals_scored)                                as gf,
        sum(goals_conceded)                              as ga,
        sum(goals_scored) - sum(goals_conceded)          as gd,
        sum(points_earned)                               as points
    from played
    group by team_sk
)
select
    row_number() over (order by points desc, gd desc, gf desc) as pos,
    a.*,
    case
        when row_number() over (order by points desc, gd desc, gf desc) <= 6  then 'Liguilla'
        when row_number() over (order by points desc, gd desc, gf desc) <= 10 then 'Play-in'
        else 'Eliminated'
    end as zone,
    l.reached
from agg a
left join ligamx.mart_liguilla l
       on l.team_sk = a.team_sk
      and l.tournament = '${inputs.tournament.value}'
order by pos
```

## {inputs.tournament.value}

<DataTable data={table} rows=18 rowShading=true>
  <Column id=pos title="#" align=center />
  <Column id=team_logo title="" contentType=image height=22 align=center />
  <Column id=team_name title="Club" />
  <Column id=played title="P" align=center />
  <Column id=won title="W" align=center />
  <Column id=drawn title="D" align=center />
  <Column id=lost title="L" align=center />
  <Column id=gf title="GF" align=center />
  <Column id=ga title="GA" align=center />
  <Column id=gd title="GD" align=center fmt='+#,##0;-#,##0;0' />
  <Column id=points title="Pts" align=center contentType=bar barColor=#047857 />
  <Column id=zone title="Qualification" />
  <Column id=reached title="Liguilla run" />
</DataTable>

<div class="mt-2 text-xs text-gray-500">
  <strong>Qualification</strong> is where the club would sit if the table finished here — 🟢 1st–6th reach the liguilla directly, 🟡 7th–10th enter the play-in.
  <strong>Liguilla run</strong> shows how far the club actually went once the knockout began, which is a different question entirely.
  <em>Pts</em> counts the 17 regular rounds only; liguilla matches decide the title but put nothing on the table.
</div>

<SiteFooter />
