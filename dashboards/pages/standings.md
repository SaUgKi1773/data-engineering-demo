---
sidebar: never
hide_toc: true
title: Standings
---

<a href="/" class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-800 no-underline mb-6 transition-colors">← Back to Home</a>

```sql seasons
select distinct season, season_name from superligaen.team_season_stats
order by season desc
```

<Dropdown data={seasons} name=season value=season label=season_name>
    <DropdownOption value=2025 valueLabel="2025/26"/>
</Dropdown>

```sql standings
select
    row_number() over (partition by round_group order by pts desc, gd desc, gf desc) as rank,
    team_name   as team,
    gp, w, d, l, gf, ga, gd, pts,
    round_group
from superligaen.team_season_stats
where season = ${inputs.season.value}
order by round_group, pts desc, gd desc, gf desc
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
from superligaen.team_regular_season_stats
where season = ${inputs.season.value}
```

```sql all_teams
select team, pts, gf, ga, round_group from ${standings}
order by round_group, pts desc
```

## {inputs.season.value} Season Standings

{#if championship.length > 0}

### 🏆 Championship Group

<DataTable data={championship} rows=20>
    <Column id=rank title="#"   align=center />
    <Column id=team title="Team"             />
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
    <Column id=team title="Team"             />
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
    <Column id=team title="Team"             />
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
    title="Points by Team — {inputs.season.value}"
    yAxisTitle="Points"
    xAxisTitle="Team"
    sort=false
    swapXY=true
/>

<BarChart
    data={all_teams}
    x=team
    y={['gf','ga']}
    title="Goals For vs Goals Against — {inputs.season.value}"
    yAxisTitle="Goals"
    xAxisTitle="Team"
    sort=false
    swapXY=true
    colorPalette={['#22c55e','#ef4444']}
/>
