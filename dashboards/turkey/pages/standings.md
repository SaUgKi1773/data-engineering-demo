---
sidebar: never
hide_toc: true
title: Standings
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>



```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from turkey.mart_standings
  group by season
) order by is_current desc, season desc
```

```sql rounds
select
    min(round) as min_round,
    max(round) as max_round
from turkey.mart_standings
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

<details class="mb-6 rounded-xl border border-blue-100 bg-blue-50">
  <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-blue-700 flex items-center gap-2">
    ℹ️ How does the Süper Lig season work?
  </summary>
  <div class="px-4 pb-4 pt-2 text-sm text-gray-700 space-y-3">
    <p><strong>One table, start to finish.</strong> Every club plays every other club twice, home and away, and the club top of the table at the end is champion. There is no split, no play-off and no second phase — the season is decided by the table you see below.</p>
    <p><strong>The league does not always run the same length.</strong> The number of clubs has changed several times, and the number of rounds moves with it, so the round slider adapts to whichever season you pick.</p>
    <p><strong>Level on points is settled between the clubs, not by goal difference.</strong> Where two or more clubs finish on the same points, the Süper Lig ranks them on their record against each other — a mini-table of just those clubs, points first and then goal difference within it — and only falls back to overall goal difference if that is level too.</p>
    <p><strong>At stake:</strong> the champion enters the Champions League qualifying rounds, the clubs below take the Europa and Conference League places, and the bottom of the table is relegated to the 1. Lig.</p>
  </div>
</details>

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key `${inputs.season.value}:${rounds[0]?.max_round}`}
<div style="padding:0 1.5rem 0 0;">
<Slider name=round data={rounds} minColumn=min_round maxColumn=max_round defaultValue=max_round title="Show standings as of round" size=full showInput=true fmt=num0 />
</div>
{/key}

```sql regular
with played as (
    select *
    from turkey.mart_standings
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
      and round <= ${inputs.round ?? 999}
),
totals as (
    select
        team_sk,
        any_value(team_name)                             as team,
        any_value(team_short_name)                       as team_short,
        max(team_logo)                                   as team_logo,
        count(distinct match_id)                         as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                as gf,
        sum(goals_conceded)                              as ga,
        sum(goals_scored) - sum(goals_conceded)          as gd,
        sum(points_earned)                               as pts
    from played
    group by team_sk
),
-- The Süper Lig separates clubs level on points by the mini-table between
-- just those clubs, so each club is re-aggregated over its matches against
-- opponents on its own points total. A club nobody is level with matches no
-- opponent here and falls through as NULL, which costs it nothing: there is
-- no tie for these columns to break.
head_to_head as (
    select
        p.team_sk,
        sum(p.points_earned)                        as h2h_pts,
        sum(p.goals_scored) - sum(p.goals_conceded) as h2h_gd
    from played p
    join totals mine on mine.team_sk = p.team_sk
    join totals tied on tied.team_sk = p.opponent_team_sk
                    and tied.pts     = mine.pts
    group by p.team_sk
)
select
    row_number() over (
        order by t.pts desc,
                 coalesce(h.h2h_pts, 0) desc,
                 coalesce(h.h2h_gd, 0) desc,
                 t.gd desc,
                 t.gf desc
    ) as rank,
    t.team, t.team_short,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || t.team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || t.team || '</span></div>'       as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || t.team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || t.team_short || '</span></div>' as team_col_mobile,
    t.gp, t.w, t.d, t.l, t.gf, t.ga, t.gd, t.pts
from totals t
left join head_to_head h on h.team_sk = t.team_sk
```

```sql all_teams
select
    team_short_name as team,
    sum(points_earned)                                as pts,
    sum(case when result = 'Win'  then 1 else 0 end)  as w,
    sum(case when result = 'Draw' then 1 else 0 end)  as d,
    sum(case when result = 'Loss' then 1 else 0 end)  as l
from turkey.mart_standings
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and round <= ${inputs.round ?? 999}
group by team_short_name
order by pts desc
```

## {inputs.season.label} Season Standings

<p style="font-size:0.8rem;color:#6b7280;margin:-0.5rem 0 1rem 0;">Showing the table <strong>as of round {inputs.round}</strong> of {rounds[0]?.max_round}. Drag the slider above to step back through the season.</p>

<div class="standings-table block md:hidden">
<DataTable data={regular} rows=25>
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
<DataTable data={regular} rows=25>
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
</DataTable>
</div>

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
select * from turkey.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
