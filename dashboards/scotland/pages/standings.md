---
sidebar: never
hide_toc: true
title: Standings
---



```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from scotland.mart_standings
  group by season
) order by is_current desc, season desc
```

```sql rounds
select
    min(match_round_number) as min_round,
    max(match_round_number) as max_round
from scotland.mart_standings
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
```

<details class="mb-6 rounded-xl border border-blue-100 bg-blue-50">
  <summary class="cursor-pointer px-4 py-3 text-sm font-semibold text-blue-700 flex items-center gap-2">
    ℹ️ How does the Scottish Premiership season work?
  </summary>
  <div class="px-4 pb-4 pt-2 text-sm text-gray-700 space-y-3">
    <p><strong>Two phases, one season.</strong> All 12 teams play each other three times in the regular season (33 games each). After round 33 comes <strong>"the split"</strong> — the league divides based on the table:</p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li><strong>Top 6</strong> → <strong>Championship Group</strong> — compete for the title and European spots</li>
      <li><strong>Bottom 6</strong> → <strong>Relegation Group</strong> — fight to stay in the division</li>
    </ul>
    <p><strong>Points carry over in full.</strong> There is no reset — every point earned before the split follows you into the final phase. Each team then plays 5 more games, once against each of the other five teams in its half (38 games total). One famous quirk: after the split, teams cannot cross halves in the final table — the 7th-placed team finishes below 6th even if they end the season on more points.</p>
    <p><strong>What's at stake in the Championship Group:</strong></p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>🏆 <strong>1st (Champion)</strong> — Champions League qualifying</li>
      <li>🔵 <strong>2nd</strong> — European qualifying (Champions League or Europa League route, depending on Scotland's UEFA coefficient)</li>
      <li>🟠 <strong>3rd–4th</strong> — Europa League / Conference League qualifying; exact spots shift with the Scottish Cup winner's league position</li>
    </ul>
    <p><strong>What's at stake in the Relegation Group:</strong></p>
    <ul class="list-disc list-inside space-y-1 pl-2">
      <li>⬆️ <strong>7th–10th</strong> — Safe, remain in the Premiership</li>
      <li>⚠️ <strong>11th</strong> — Relegation play-off (two-legged final against the Championship play-off winner)</li>
      <li>⬇️ <strong>12th</strong> — Directly relegated to the Scottish Championship</li>
    </ul>
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

```sql standings
select
    row_number() over (
        partition by round_group
        order by pts desc, gd desc, gf desc
    )                as rank,
    team_name        as team,
    team_short_name  as team_short,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_name || '</span></div>'       as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_short_name || '</span></div>' as team_col_mobile,
    gp, w, d, l, gf, ga, gd, pts,
    round_group
from (
    select
        team_name,
        team_short_name,
        max(team_logo)                                    as team_logo,
        -- group is derived from the latest round type each team has played within the selected round window,
        -- so before the split (rounds 1-22) every team is still 'Regular Season' and no group tables show
        case arg_max(match_round_type, match_round_number)
            when 'Championship Round' then 'Championship Group'
            when 'Relegation Round'   then 'Relegation Group'
            else                           'Regular Season'
        end                                               as round_group,
        count(distinct match_id)                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from scotland.mart_standings
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
      and match_round_number <= ${inputs.round ?? 999}
    group by team_name, team_short_name
)
where round_group != 'Regular Season'
order by round_group, pts desc, gd desc, gf desc
```

```sql championship
select rank, team, team_short, team_col, team_col_mobile, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Championship Group'
```

```sql relegation
select rank, team, team_short, team_col, team_col_mobile, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Relegation Group'
```

```sql regular
select
    row_number() over (order by pts desc, gd desc, gf desc) as rank,
    team_name as team, team_short_name as team_short,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_name || '</span></div>'       as team_col,
    '<div style="display:flex;align-items:center;gap:6px;"><img src="' || team_logo || '" style="height:20px;width:20px;object-fit:contain;" onerror="this.style.display=''none''"><span>' || team_short_name || '</span></div>' as team_col_mobile,
    gp, w, d, l, gf, ga, gd, pts
from (
    select
        team_name,
        team_short_name,
        max(team_logo)                                    as team_logo,
        count(distinct match_id)                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from scotland.mart_standings
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
      and match_round_type = 'Regular Season'
      and match_round_number <= ${inputs.round ?? 999}
    group by team_name, team_short_name
)
```

```sql all_teams
select
    team_short_name as team,
    sum(points_earned)                                as pts,
    sum(case when result = 'Win'  then 1 else 0 end)  as w,
    sum(case when result = 'Draw' then 1 else 0 end)  as d,
    sum(case when result = 'Loss' then 1 else 0 end)  as l,
    case arg_max(match_round_type, match_round_number)
        when 'Championship Round' then 'Championship Group'
        when 'Relegation Round'   then 'Relegation Group'
        else                           'Regular Season'
    end                                               as round_group
from scotland.mart_standings
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
  and match_round_number <= ${inputs.round ?? 999}
group by team_short_name
order by
    case round_group
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        else                           3
    end,
    pts desc
```

## {inputs.season.label} Season Standings

<p style="font-size:0.8rem;color:#6b7280;margin:-0.5rem 0 1rem 0;">Showing the table <strong>as of round {inputs.round}</strong>. Drag the slider above to step back through the season.</p>

{#if championship.length > 0}

### 🏆 Championship Group

<div class="standings-table block md:hidden">
<DataTable data={championship} rows=20>
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
<DataTable data={championship} rows=20>
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

{/if}

{#if relegation.length > 0}

### ⬇️ Relegation Group

<div class="standings-table block md:hidden">
<DataTable data={relegation} rows=20>
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
<DataTable data={relegation} rows=20>
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

{/if}

{#if regular.length > 0}

### 📋 Regular Season

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
</DataTable>
</div>

{/if}

---

<BarChart
    data={all_teams}
    x=team
    y=pts
    series=round_group
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
