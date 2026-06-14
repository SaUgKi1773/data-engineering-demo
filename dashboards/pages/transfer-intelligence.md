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

  // Net Spend tooltip: full club name + net / spent / received
  $: clubFin = Object.fromEntries((by_club ?? []).map(r => [r.team_name, r]));
  $: netSpendTip = (params) => {
    const name = (Array.isArray(params) ? params[0] : params).axisValue;
    const r = clubFin[name];
    if (!r) return name;
    return `<strong>${name}</strong>`
      + `<br/>Net spend: €${r.net_spend_m}m`
      + `<br/>Spent: €${r.spend_m}m`
      + `<br/>Received: €${r.income_m}m`;
  };
</script>

```sql team_lookup
select distinct team_code, team_name from superligaen.mart_club_transfers
```

```sql years
select distinct cast(transfer_year as integer) as transfer_year,
  (cast(transfer_year as integer) = year(current_date)) as is_current
from superligaen.mart_club_transfers
order by is_current desc, transfer_year desc
```

```sql months
select distinct cast(transfer_month as integer) as transfer_month, transfer_month_name
from superligaen.mart_club_transfers
order by transfer_month
```

```sql teams
select distinct team_name
from superligaen.mart_club_transfers
order by team_name
```

```sql kpi
select
  sum(signings)        as signings,
  sum(departures)      as departures,
  sum(signings) + sum(departures) as moves,
  sum(permanent_moves) as permanent_moves,
  sum(loan_moves)      as loan_moves,
  sum(free_moves)      as free_moves,
  sum(retirements)     as retirements,
  round(sum(spend_eur) / 1e6, 2)                                          as spend_m,
  round(sum(spend_eur) / nullif(sum(paid_signings), 0) / 1e6, 2)         as avg_fee_m,
  round(max(biggest_fee_eur) / 1e6, 2)                                   as biggest_fee_m
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and team_name in ${inputs.team.value}
```

```sql record_signing
select player_name, player_photo, club, partner,
  cast(transfer_year as integer)::varchar as transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Incoming' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 1
```

```sql record_sale
select player_name, player_photo, club, partner,
  cast(transfer_year as integer)::varchar as transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Outgoing' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 1
```

```sql by_club
select * from (
  select team_name,
    sum(net_spend_eur)                 as net_raw,
    round(sum(net_spend_eur) / 1e6, 2) as net_spend_m,
    round(sum(spend_eur) / 1e6, 2)     as spend_m,
    round(sum(income_eur) / 1e6, 2)    as income_m
  from superligaen.mart_club_transfers
  where transfer_year in ${inputs.year.value}
    and transfer_month in ${inputs.month.value}
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
  and transfer_month in ${inputs.month.value}
  and team_name in ${inputs.team.value}
group by team_name
having sum(signings) + sum(departures) > 0
order by sum(signings) + sum(departures) desc
limit 10
```

```sql trend_year
-- Time series: not affected by the Year filter (it is the time axis); Month/Team filters apply.
select cast(cast(transfer_year as integer) as varchar) as transfer_year,
  sum(signings) + sum(departures) as moves,
  round(sum(spend_eur) / 1e6, 1) as spend_m
from superligaen.mart_club_transfers
where transfer_month in ${inputs.month.value}
  and team_name in ${inputs.team.value}
group by 1
order by 1
```

```sql biggest_signings
select player_name, club, partner, cast(transfer_year as integer)::varchar as transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Incoming' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 10
```

```sql biggest_sales
select player_name, club, partner, cast(transfer_year as integer)::varchar as transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Outgoing' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and club in ${inputs.team.value}
order by fee_eur desc
limit 10
```

```sql ledger
select transfer_date, transfer_month_name, club, direction, transfer_type,
  player_name, position, partner, partner_country,
  case when fee_eur is null then null else round(fee_eur / 1e6, 2) end as fee_m
from superligaen.mart_club_transfer_log
where transfer_year in ${inputs.year.value}
  and transfer_month in ${inputs.month.value}
  and club in ${inputs.team.value}
order by (fee_eur is null), fee_eur desc, transfer_date desc
```

<div class="flex flex-wrap gap-3 items-end mb-2">
  {#key years[0]?.transfer_year}
  <Dropdown data={years} name=year value=transfer_year multiple=true order="transfer_year desc" defaultValue={[years[0]?.transfer_year]} title="Year" />
  {/key}
  <Dropdown data={months} name=month value=transfer_month label=transfer_month_name multiple=true selectAllByDefault=true order="transfer_month asc" title="Month" />
  <Dropdown data={teams} name=team value=team_name multiple=true selectAllByDefault=true order="team_name asc" title="Club" />
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mt-5 mb-3">
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-3xl font-black text-gray-800 leading-none">{kpi[0]?.moves}</div>
    <div class="text-gray-400 text-xs mt-1.5 uppercase tracking-wide">Transfers</div>
    <div class="text-[11px] text-gray-500 mt-1">{kpi[0]?.permanent_moves} perm · {kpi[0]?.loan_moves} loan · {kpi[0]?.free_moves} free</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-3xl font-black text-emerald-600 leading-none">€{kpi[0]?.spend_m}m</div>
    <div class="text-gray-400 text-xs mt-1.5 uppercase tracking-wide">Total Spend</div>
    <div class="text-[11px] text-gray-500 mt-1">on signings</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-3xl font-black text-gray-800 leading-none">€{kpi[0]?.avg_fee_m ?? '—'}m</div>
    <div class="text-gray-400 text-xs mt-1.5 uppercase tracking-wide">Avg Fee</div>
    <div class="text-[11px] text-gray-500 mt-1">per paid signing</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-3xl font-black text-violet-600 leading-none">€{kpi[0]?.biggest_fee_m}m</div>
    <div class="text-gray-400 text-xs mt-1.5 uppercase tracking-wide">Record Fee</div>
    <div class="text-[11px] text-gray-500 mt-1">biggest deal</div>
  </div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-5 mb-7">
  <div class="rounded-xl border border-emerald-200 bg-emerald-50/40 p-4 shadow-sm flex items-center gap-4">
    <img src="{record_signing[0]?.player_photo}" alt="" class="w-16 h-16 rounded-full object-cover bg-white border border-emerald-100 flex-shrink-0" onerror="this.style.visibility='hidden'" />
    <div class="flex-1 min-w-0">
      <div class="text-[10px] uppercase tracking-widest text-emerald-700 font-bold">🏆 Record Signing</div>
      <div class="text-lg font-bold text-gray-800 truncate">{record_signing[0]?.player_name ?? '—'}</div>
      <div class="text-xs text-gray-500 truncate">{record_signing[0]?.club} ← {record_signing[0]?.partner} · {record_signing[0]?.transfer_year}</div>
    </div>
    <div class="text-2xl font-black text-emerald-600 whitespace-nowrap">€{record_signing[0]?.fee_m ?? '—'}m</div>
  </div>
  <div class="rounded-xl border border-orange-200 bg-orange-50/40 p-4 shadow-sm flex items-center gap-4">
    <img src="{record_sale[0]?.player_photo}" alt="" class="w-16 h-16 rounded-full object-cover bg-white border border-orange-100 flex-shrink-0" onerror="this.style.visibility='hidden'" />
    <div class="flex-1 min-w-0">
      <div class="text-[10px] uppercase tracking-widest text-orange-700 font-bold">💰 Record Sale</div>
      <div class="text-lg font-bold text-gray-800 truncate">{record_sale[0]?.player_name ?? '—'}</div>
      <div class="text-xs text-gray-500 truncate">{record_sale[0]?.club} → {record_sale[0]?.partner} · {record_sale[0]?.transfer_year}</div>
    </div>
    <div class="text-2xl font-black text-orange-600 whitespace-nowrap">€{record_sale[0]?.fee_m ?? '—'}m</div>
  </div>
</div>

## Net Spend by Club

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Fees paid on incoming permanents minus fees received on outgoing permanents. Top 10 clubs by net balance; positive = net investment, negative = net sales.</p>

<BarChart
    data={by_club}
    x=team_name
    y=net_spend_m
    yFmt='#,##0.00'
    title="Net Spend — Top 10 (€m)"
    yAxisTitle="€m"
    sort=false
    colorPalette={['#236aa4']}
    echartsOptions={{xAxis: {axisLabel: {formatter: shortLabel}}, tooltip: {formatter: netSpendTip}}}
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

## Market Over Time <span style="font-size:0.7rem;color:#9ca3af;font-weight:400;">(all years)</span>

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
    <Column id=transfer_month_name title="Month" align=center />
    <Column id=club            title="Club" />
    <Column id=direction       title="Dir" align=center />
    <Column id=transfer_type   title="Type" />
    <Column id=player_name     title="Player" />
    <Column id=partner         title="Counterparty" />
    <Column id=partner_country  title="Country" />
    <Column id=fee_m           title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#236aa4']} />
</DataTable>

<div class="mt-8 text-center text-xs text-gray-400">Fees shown where disclosed.</div>
