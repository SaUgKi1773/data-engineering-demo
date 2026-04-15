---
title: Superligaen Dashboard
---

```sql seasons
select distinct season from superligaen.team_season_stats
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season>
    <DropdownOption value=2025 valueLabel="2025"/>
</Dropdown>

```sql standings
select
    team_name   as team,
    gp, w, d, l, gf, ga, gd, pts,
    round_group
from superligaen.team_season_stats
where season = ${inputs.season.value}
order by round_group, pts desc, gd desc, gf desc
```

```sql championship
select team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Championship Group'
```

```sql relegation
select team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Relegation Group'
```

```sql regular
select team, gp, w, d, l, gf, ga, gd, pts
from ${standings}
where round_group = 'Regular Season'
```

## {inputs.season.value} Season Standings

### Championship Group

<DataTable data={championship} rows=20>
    <Column id=team/>
    <Column id=gp  title="GP"/>
    <Column id=w   title="W"/>
    <Column id=d   title="D"/>
    <Column id=l   title="L"/>
    <Column id=gf  title="GF"/>
    <Column id=ga  title="GA"/>
    <Column id=gd  title="GD"/>
    <Column id=pts title="Pts" contentType=colorscale colorScale=positive/>
</DataTable>

### Relegation Group

<DataTable data={relegation} rows=20>
    <Column id=team/>
    <Column id=gp  title="GP"/>
    <Column id=w   title="W"/>
    <Column id=d   title="D"/>
    <Column id=l   title="L"/>
    <Column id=gf  title="GF"/>
    <Column id=ga  title="GA"/>
    <Column id=gd  title="GD"/>
    <Column id=pts title="Pts" contentType=colorscale colorScale=positive/>
</DataTable>

{#if regular.length > 0}

### Regular Season

<DataTable data={regular} rows=20>
    <Column id=team/>
    <Column id=gp  title="GP"/>
    <Column id=w   title="W"/>
    <Column id=d   title="D"/>
    <Column id=l   title="L"/>
    <Column id=gf  title="GF"/>
    <Column id=ga  title="GA"/>
    <Column id=gd  title="GD"/>
    <Column id=pts title="Pts" contentType=colorscale colorScale=positive/>
</DataTable>

{/if}

<BarChart
    data={standings}
    x=team
    y=pts
    title="Points — {inputs.season.value}"
    yAxisTitle="Points"
    xAxisTitle="Team"
    sort=false
/>
