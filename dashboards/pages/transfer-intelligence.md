---
sidebar: never
hide_toc: true
title: Transfer Intelligence
---

<script>
  // axis shows the short code; the full club name stays in the data (and tooltip)
  let nameToCode = {};
  $: nameToCode = Object.fromEntries((team_lookup ?? []).map(r => [r.team_name, r.team_code]));
  $: shortLabel = (name) => nameToCode[name] ?? name;
</script>

```sql team_lookup
select distinct team_code, team_name from superligaen.mart_club_transfers
```

```sql years
select distinct transfer_year,
  (transfer_year = year(current_date)) as is_current
from superligaen.mart_club_transfers
order by is_current desc, transfer_year desc
```

```sql teams
select distinct team_name
from superligaen.mart_club_transfers
order by team_name
```

```sql kpi
select
  sum(signings)          as signings,
  sum(departures)        as departures,
  sum(permanent_moves)   as permanent_moves,
  sum(loan_moves)        as loan_moves,
  sum(free_moves)        as free_moves,
  round(sum(spend_eur) / 1e6, 2)      as spend_m,
  round(sum(income_eur) / 1e6, 2)     as income_m,
  round(sum(net_spend_eur) / 1e6, 2)  as net_m,
  sum(net_spend_eur)                  as net_raw,
  round(max(biggest_fee_eur) / 1e6, 2) as biggest_fee_m
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
  and team_name in ${inputs.team.value}
```

```sql by_club
select * from (
  select team_name,
    sum(net_spend_eur)                 as net_raw,
    round(sum(net_spend_eur) / 1e6, 2) as net_spend_m
  from superligaen.mart_club_transfers
  where transfer_year in ${inputs.year.value}
    and team_name in ${inputs.team.value}
  group by team_name
  having sum(signings) + sum(departures) > 0
  order by abs(sum(net_spend_eur)) desc
  limit 10
)
order by net_raw desc
```

```sql by_club_busy
select team_name,
  sum(signings) as signings,
  sum(departures) as departures
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
  and team_name in ${inputs.team.value}
group by team_name
having sum(signings) + sum(departures) > 0
order by sum(signings) + sum(departures) desc
limit 10
```

```sql trend_year
select transfer_year,
  sum(signings) + sum(departures) as moves,
  sum(permanent_moves) as permanent_moves,
  sum(loan_moves)      as loan_moves,
  sum(free_moves)      as free_moves,
  round(sum(spend_eur) / 1e6, 1) as spend_m
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
  and team_name in ${inputs.team.value}
group by transfer_year
order by transfer_year
```

```sql biggest_signings
select player_name, club, partner, transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Incoming' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 10
```

```sql biggest_sales
select player_name, club, partner, transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Outgoing' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 10
```

```sql ledger
select transfer_date, transfer_window, club, direction, transfer_type,
  player_name, position, partner, partner_country,
  case when fee_eur is null then null else round(fee_eur / 1e6, 2) end as fee_m
from superligaen.mart_club_transfer_log
where transfer_year in ${inputs.year.value}
  and club in ${inputs.team.value}
order by (fee_eur is null), fee_eur desc, transfer_date desc
```

<div class="flex flex-wrap gap-3 items-end mb-2">
  {#key years[0]?.transfer_year}
  <Dropdown data={years} name=year value=transfer_year multiple=true order="transfer_year desc" defaultValue={[years[0]?.transfer_year]} title="Year" />
  {/key}
  <Dropdown data={teams} name=team value=team_name multiple=true selectAllByDefault=true order="team_name asc" title="Club" />
</div>

<div class="grid grid-cols-2 md:grid-cols-6 gap-3 my-5">
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{kpi[0]?.signings}</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Signings</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{kpi[0]?.departures}</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Departures</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-emerald-600 leading-none">€{kpi[0]?.spend_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Spent</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-orange-600 leading-none">€{kpi[0]?.income_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Received</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black leading-none" style="color:{kpi[0]?.net_raw >= 0 ? '#236aa4' : '#16a34a'}">€{kpi[0]?.net_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Net Spend</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-violet-600 leading-none">€{kpi[0]?.biggest_fee_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Record Fee</div>
  </div>
</div>

## Net Spend by Club

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Fees paid on incoming permanents minus fees received on outgoing permanents. Top 10 clubs by net balance; positive = net investment, negative = net sales.</p>

<BarChart
    data={by_club}
    x=team_name
    y=net_spend_m
    title="Net Spend — Top 10 (€m)"
    yAxisTitle="€m"
    sort=false
    colorPalette={['#236aa4']}
    echartsOptions={{xAxis: {axisLabel: {formatter: shortLabel}}}}
/>

## Market Activity

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Incoming vs outgoing moves per club — top 10 busiest.</p>

<BarChart
    data={by_club_busy}
    x=team_name
    y={['signings','departures']}
    title="Ins vs Outs — Top 10 Busiest"
    type=grouped
    colorPalette={['#16a34a','#f97316']}
    seriesOptions={{"barGap": "0%"}}
    sort=false
    echartsOptions={{xAxis: {axisLabel: {formatter: shortLabel}}}}
/>

## Market Over Time

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={trend_year}
    x=transfer_year
    y=spend_m
    title="Spend by Year (€m)"
    colorPalette={['#16a34a']}
    sort=false
/>

<LineChart
    data={trend_year}
    x=transfer_year
    y=moves
    title="Moves by Year"
    markers=true
    sort=false
/>

</div>

## Record Moves

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>
<p style="font-size:0.8rem;font-weight:600;color:#16a34a;margin:0 0 0.5rem 0;">▼ Biggest Signings (in)</p>
<DataTable data={biggest_signings} rows=10>
    <Column id=player_name   title="Player" />
    <Column id=club          title="Club" />
    <Column id=partner       title="From" />
    <Column id=transfer_year title="Yr" align=center />
    <Column id=fee_m         title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#16a34a']} />
</DataTable>
</div>

<div>
<p style="font-size:0.8rem;font-weight:600;color:#f97316;margin:0 0 0.5rem 0;">▲ Biggest Sales (out)</p>
<DataTable data={biggest_sales} rows=10>
    <Column id=player_name   title="Player" />
    <Column id=club          title="Club" />
    <Column id=partner       title="To" />
    <Column id=transfer_year title="Yr" align=center />
    <Column id=fee_m         title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#f97316']} />
</DataTable>
</div>

</div>

## Transfer Ledger

<DataTable data={ledger} rows=15 search=true>
    <Column id=transfer_date   title="Date" />
    <Column id=transfer_window title="Window" align=center />
    <Column id=club            title="Club" />
    <Column id=direction       title="Dir" align=center />
    <Column id=transfer_type   title="Type" />
    <Column id=player_name     title="Player" />
    <Column id=partner         title="Counterparty" />
    <Column id=partner_country  title="Country" />
    <Column id=fee_m           title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#236aa4']} />
</DataTable>

<div class="mt-8 text-center text-xs text-gray-400">Transfer windows: Summer (Jun–Sep), Winter (Jan–Feb). Fees shown where disclosed.</div>
