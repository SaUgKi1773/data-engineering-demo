---
sidebar: never
hide_toc: true
title: Standings
---

```sql seasons
select distinct season from superligaen.mart_match_facts
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season order="season desc">
    <DropdownOption value="2025/26" valueLabel="2025/26"/>
</Dropdown>

```sql standings
select
    row_number() over (
        partition by standings_type
        order by pts desc, gd desc, gf desc
    )              as rank,
    team_name      as team,
    gp, w, d, l, gf, ga, gd, pts,
    standings_type as round_group
from (
    select
        team_name,
        standings_type,
        count(*)                                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by team_name, standings_type
)
where standings_type != 'Regular Season'
order by standings_type, pts desc, gd desc, gf desc
```

```sql championship
select rank, team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Championship Group'
```

```sql relegation
select rank, team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Relegation Group'
```

```sql regular
select
    row_number() over (order by pts desc, gd desc, gf desc) as rank,
    team_name as team, gp, w, d, l, gf, ga, gd, pts
from (
    select
        team_name,
        count(*)                                          as gp,
        sum(case when result = 'Win'  then 1 else 0 end) as w,
        sum(case when result = 'Draw' then 1 else 0 end) as d,
        sum(case when result = 'Loss' then 1 else 0 end) as l,
        sum(goals_scored)                                 as gf,
        sum(goals_conceded)                               as ga,
        sum(goals_scored) - sum(goals_conceded)           as gd,
        sum(points_earned)                                as pts
    from superligaen.mart_match_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
      and match_round_type = 'Regular Season'
    group by team_name
)
```

```sql all_teams
select
    team_name      as team,
    sum(points_earned)                      as pts,
    sum(goals_scored)                       as gf,
    sum(goals_conceded)                     as ga,
    standings_type                          as round_group
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
group by team_name, standings_type
order by
    case standings_type
        when 'Championship Group' then 1
        when 'Relegation Group'   then 2
        else                           3
    end,
    pts desc
```

## {inputs.season.label} Season Standings

{#if championship.length > 0}

### 🏆 Championship Group

<DataTable data={championship} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

{/if}

{#if relegation.length > 0}

### ⬇️ Relegation Group

<DataTable data={relegation} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

{/if}

{#if regular.length > 0}

### 📋 Regular Season

<DataTable data={regular} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team" wrap=true   />
    <Column id=gp   title="GP"  align=center />
    <Column id=w    title="W"   align=center />
    <Column id=d    title="D"   align=center />
    <Column id=l    title="L"   align=center />
    <Column id=gf   title="GF"  align=center />
    <Column id=ga   title="GA"  align=center />
    <Column id=gd   title="GD"  align=center />
    <Column id=pts  title="Pts" align=center contentType=colorscale colorPalette={['white','#6366f1']} />
</DataTable>

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
    y={['gf','ga']}
    title="Goals For vs Goals Against — {inputs.season.label}"
    yAxisTitle="Goals"
    xAxisTitle="Team"
    sort=false
    swapXY=true
    colorPalette={['#22c55e','#ef4444']}
/>
