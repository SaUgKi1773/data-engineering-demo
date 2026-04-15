---
title: Match Results
---

```sql seasons
select distinct season from superligaen.match_results
order by season desc
```

```sql teams
select distinct team_name as team from superligaen.match_results
order by team_name
```

<Dropdown data={seasons} name=season value=season label=season>
    <DropdownOption value=2025 valueLabel="2025"/>
</Dropdown>

<Dropdown data={teams} name=team value=team label=team>
    <DropdownOption value="All Teams" valueLabel="All Teams"/>
</Dropdown>

```sql results
select
    match_date, round, team_name as team, opponent,
    side, gf, ga, result, pts, stadium
from superligaen.match_results
where season = ${inputs.season.value}
  and (team_name = '${inputs.team.value}' or '${inputs.team.value}' = 'All Teams')
order by match_date desc
```

## Results — {inputs.season.value}

<DataTable data={results} rows=20 search=true>
    <Column id=match_date title="Date"/>
    <Column id=round      title="Round"/>
    <Column id=team       title="Team"/>
    <Column id=opponent   title="Opponent"/>
    <Column id=side       title="Side"/>
    <Column id=gf         title="GF"/>
    <Column id=ga         title="GA"/>
    <Column id=result     title="Result"/>
    <Column id=pts        title="Pts"/>
    <Column id=stadium    title="Stadium"/>
</DataTable>
