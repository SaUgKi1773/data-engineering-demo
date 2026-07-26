---
sidebar: never
hide_toc: true
title: Standings
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
  import LiguillaBracket from '../../components/LiguillaBracket.svelte';
</script>



```sql seasons
select tournament from (
  select tournament, max(is_current_tournament::int) as is_current
  from ligamx.mart_standings
  group by tournament
) order by is_current desc, tournament desc
```

```sql rounds
select
    min(round) as min_round,
    max(round) as max_round
from ligamx.mart_standings
where tournament = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

<details class="mb-6 rounded-xl border border-blue-100 bg-blue-50">
  <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-blue-700 flex items-center gap-2">
    ℹ️ How does the Liga MX season work?
  </summary>
  <div class="px-4 pb-4 pt-2 text-sm text-gray-700 space-y-3">
    <p><strong>Two championships every year, not one.</strong> A Liga MX season is split into two entirely separate competitions: the <strong>Apertura</strong> (July–December) and the <strong>Clausura</strong> (January–May). Each has its own table, its own knockout and its own champion. A club can win the Apertura and finish bottom of the Clausura five months later — they are not two halves of one season.</p>
    <p><strong>Everyone plays everyone once.</strong> 18 clubs, 17 rounds, a single round-robin. A table is complete at 17 games, roughly half the length of a European league season, so a bad month costs far more here.</p>
    <p><strong>Topping the table does not win you anything.</strong> The regular season only <em>seeds</em> the knockout — the <strong>liguilla</strong> — which is where the title is actually decided:</p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>🟢 <strong>1st–6th</strong> → straight into the liguilla quarter-finals</li>
      <li>🟡 <strong>7th–10th</strong> → the <strong>play-in</strong>, competing for the last two places</li>
      <li>⚪ <strong>11th–18th</strong> → season over</li>
    </ul>
    <p>Every liguilla tie is played over two legs, and the club finishing higher in the table gets the advantage of hosting the second one. Across the twelve completed tournaments held here, the club that topped the table went on to lift the trophy just <strong>six</strong> times. The table is a seeding, not a verdict — the bracket below is where the tournament is settled.</p>
    <p><strong>No relegation.</strong> Unlike the other leagues on this platform, nobody goes down — relegation is currently suspended in Liga MX, so the bottom of the table carries no jeopardy.</p>
  </div>
</details>

{#key seasons[0]?.tournament}
<Dropdown data={seasons} name=season value=tournament label=tournament order="tournament desc" defaultValue={seasons[0]?.tournament} />
{/key}

{#key `${inputs.season.value}:${rounds[0]?.max_round}`}
<div style="padding:0 1.5rem 0 0;">
<Slider name=round data={rounds} minColumn=min_round maxColumn=max_round defaultValue=max_round title="Show standings as of round" size=full showInput=true fmt=num0 />
</div>
{/key}

```sql regular
select
    row_number() over (order by pts desc, gd desc, gf desc) as rank,
    team as team, team_short as team_short,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team || '</span></div>'       as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_short || '</span></div>' as team_col_mobile,
    gp, w, d, l, gf, ga, gd, pts,
    -- where the club would sit if the table finished here: the top six are
    -- seeded straight into the liguilla, 7th-10th enter the play-in
    case
        when row_number() over (order by pts desc, gd desc, gf desc) <= 6  then '🟢 Liguilla'
        when row_number() over (order by pts desc, gd desc, gf desc) <= 10 then '🟡 Play-in'
        else '⚪ Out'
    end as zone
from (
    select
        s.team_sk,
        any_value(s.team_name)                              as team,
        any_value(s.team_short_name)                        as team_short,
        max(s.team_logo)                                    as team_logo,
        count(distinct s.match_id)                          as gp,
        sum(case when s.result = 'Win'  then 1 else 0 end)  as w,
        sum(case when s.result = 'Draw' then 1 else 0 end)  as d,
        sum(case when s.result = 'Loss' then 1 else 0 end)  as l,
        sum(s.goals_scored)                                 as gf,
        sum(s.goals_conceded)                               as ga,
        sum(s.goals_scored) - sum(s.goals_conceded)         as gd,
        sum(s.points_earned)                                as pts
    from ligamx.mart_standings s
    where s.tournament = '${inputs.season.value}'
      and s.result in ('Win', 'Draw', 'Loss')
      and s.round <= ${inputs.round ?? 999}
    group by s.team_sk
)
```

```sql bracket
select *
from ligamx.mart_liguilla_bracket
where tournament = '${inputs.season.value}'
order by round_order, team_a_seed
```

```sql all_teams
select
    team_short_name as team,
    sum(points_earned)                                as pts,
    sum(case when result = 'Win'  then 1 else 0 end)  as w,
    sum(case when result = 'Draw' then 1 else 0 end)  as d,
    sum(case when result = 'Loss' then 1 else 0 end)  as l
from ligamx.mart_standings
where tournament = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and round <= ${inputs.round ?? 999}
group by team_short_name
order by pts desc
```

## {inputs.season.label} Standings

### 🏆 Liguilla

<p style="font-size:0.8rem;color:#6b7280;margin:-0.5rem 0 1rem 0;">Where the title is actually decided. Every tie is played over two legs except the play-in — and if the aggregate finishes level in the quarter- or semi-finals there is no shootout: the better-seeded club goes through.</p>

<LiguillaBracket data={bracket} />

{#if regular.length > 0}

### 📋 Regular Season

<p style="font-size:0.8rem;color:#6b7280;margin:-0.5rem 0 1rem 0;">Showing the table <strong>as of round {inputs.round}</strong> of 17. Drag the slider above to step back through the tournament. The bracket above is unaffected — it is played after the table is final.</p>

<div class="standings-table block md:hidden">
<DataTable data={regular} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team_col_mobile title="Team" contentType=html width="max-content" />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>
</div>
<div class="standings-table hidden md:block">
<DataTable data={regular} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team_col title="Team" contentType=html />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    <!-- explicit width: without it the table hands the slack to the Team
         column and clips the zone labels -->
    <Column id=zone title="Zone" width="110px" />
</DataTable>
</div>

{/if}

---

<BarChart
    data={all_teams}
    x=team
    y=pts
    title="Points by Team — {inputs.season.label}"
    yAxisTitle="Points"
    xAxisTitle="Team"
    sort=false
    swapXY=true
/>

<BarChart
    data={all_teams}
    x=team
    y={['w','d','l']}
    title="Wins, Draws & Losses by Team — {inputs.season.label}"
    yAxisTitle="Matches"
    xAxisTitle="Team"
    sort=false
    swapXY=true
    type=stacked
    colorPalette={['#22c55e','#eab308','#ef4444']}
/>

```sql last_updated
select * from ligamx.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
