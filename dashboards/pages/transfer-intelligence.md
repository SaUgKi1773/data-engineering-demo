---
sidebar: never
hide_toc: true
title: Transfer Intelligence
---

<script>
  // axis shows the short code; the full club name stays in the data (and tooltip)
  let nameToCode = {};
  $: nameToCode = Object.fromEntries((team_lookup ?? []).map(r => [r.club, r.club_code]));
  $: shortLabel = (name) => nameToCode[name] ?? name;
</script>

```sql team_lookup
select distinct club, club_code from superligaen.mart_club_transfer_log
```

```sql years
select distinct cast(transfer_year as integer) as transfer_year,
  (cast(transfer_year as integer) = year(current_date)) as is_current
from superligaen.mart_club_transfer_log
order by is_current desc, transfer_year desc
```

```sql windows
select transfer_window from (
  select distinct transfer_window,
    case transfer_window
      when 'Summer Window' then 1
      when 'Winter Window' then 2
      else 3
    end as ord
  from superligaen.mart_club_transfer_log
) order by ord
```

```sql teams
select club from (
  select 'All Teams' as club, 0 as ord
  union all
  select distinct club, 1 as ord from superligaen.mart_club_transfer_log
) order by ord, club
```

```sql directions
select distinct direction from superligaen.mart_club_transfer_log order by direction
```

```sql types
select distinct transfer_type from superligaen.mart_club_transfer_log order by transfer_type
```

```sql statuses
select distinct transfer_status from superligaen.mart_club_transfer_log order by transfer_status
```

```sql kpi
-- Market level (each transfer counted once via DISTINCT) with a previous-year
-- benchmark. All filters except year define the set; curr = selected year, prev = year-1.
with base as (
  select distinct transfer_id, transfer_year, fee_eur
  from superligaen.mart_club_transfer_log
  where ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
    and direction in ${inputs.direction.value}
    and transfer_type in ${inputs.type.value}
    and transfer_status in ${inputs.status.value}
    and transfer_window in ${inputs.window.value}
    and transfer_year in (${inputs.year.value}, ${inputs.year.value} - 1)
),
curr as (
  select count(*) as deals, round(sum(fee_eur) / 1e6, 2) as total_m,
    count(*) filter (where fee_eur > 0) as paid,
    round(avg(fee_eur) filter (where fee_eur > 0) / 1e6, 2) as avg_m
  from base where transfer_year = ${inputs.year.value}
),
prev as (
  select count(*) as deals, round(sum(fee_eur) / 1e6, 2) as total_m,
    count(*) filter (where fee_eur > 0) as paid,
    round(avg(fee_eur) filter (where fee_eur > 0) / 1e6, 2) as avg_m
  from base where transfer_year = ${inputs.year.value} - 1
)
select
  curr.deals, curr.total_m, curr.avg_m, curr.paid,
  prev.deals as prev_deals, prev.total_m as prev_total_m, prev.avg_m as prev_avg_m, prev.paid as prev_paid,
  round(curr.deals::double   / nullif(prev.deals, 0), 2) as deals_ratio,
  round(curr.total_m         / nullif(prev.total_m, 0), 2) as total_ratio,
  round(curr.avg_m           / nullif(prev.avg_m, 0), 2) as avg_ratio,
  round(curr.paid::double    / nullif(prev.paid, 0), 2) as paid_ratio
from curr cross join prev
```

```sql by_club
with f as (
  select * from superligaen.mart_club_transfer_log
  where transfer_year = ${inputs.year.value}
    and ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
    and direction in ${inputs.direction.value}
    and transfer_type in ${inputs.type.value}
    and transfer_status in ${inputs.status.value}
    and transfer_window in ${inputs.window.value}
),
agg as (
  select club,
    coalesce(sum(fee_eur) filter (where direction = 'Incoming'), 0)
      - coalesce(sum(fee_eur) filter (where direction = 'Outgoing'), 0) as net_raw,
    round(coalesce(sum(fee_eur) filter (where direction = 'Incoming'), 0) / 1e6, 2) as spend_m,
    round(coalesce(sum(fee_eur) filter (where direction = 'Outgoing'), 0) / 1e6, 2) as income_m
  from f group by club
)
select club,
  round(net_raw / 1e6, 2) as net_spend_m,
  spend_m, income_m
from agg
order by (spend_m + income_m) desc, abs(net_raw) desc
limit 8
```

```sql by_club_busy
select club,
  count(*) filter (where direction = 'Incoming') as incoming,
  count(*) filter (where direction = 'Outgoing') as outgoing
from superligaen.mart_club_transfer_log
where transfer_year = ${inputs.year.value}
  and ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
  and direction in ${inputs.direction.value}
  and transfer_type in ${inputs.type.value}
  and transfer_status in ${inputs.status.value}
  and transfer_window in ${inputs.window.value}
group by club
having count(*) > 0
order by count(*) desc
limit 8
```

```sql trend_year
-- Time series: not affected by the Year filter (it is the time axis); other filters apply.
with base as (
  select distinct transfer_id, transfer_year, fee_eur
  from superligaen.mart_club_transfer_log
  where ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
    and direction in ${inputs.direction.value}
    and transfer_type in ${inputs.type.value}
    and transfer_status in ${inputs.status.value}
    and transfer_window in ${inputs.window.value}
)
select cast(transfer_year as integer)::varchar as transfer_year,
  count(*)                     as transfers,
  round(sum(fee_eur) / 1e6, 2) as total_value_m
from base group by 1 order by 1
```

```sql record_signing
select player_name, player_photo, club, partner,
  strftime(transfer_date, '%-d %B %Y') as transfer_date_fmt,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Incoming' and fee_eur > 0
  and transfer_year = ${inputs.year.value}
  and ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
  and direction in ${inputs.direction.value}
  and transfer_type in ${inputs.type.value}
  and transfer_status in ${inputs.status.value}
  and transfer_window in ${inputs.window.value}
order by fee_eur desc
limit 1
```

```sql record_sale
select player_name, player_photo, club, partner,
  strftime(transfer_date, '%-d %B %Y') as transfer_date_fmt,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Outgoing' and fee_eur > 0
  and transfer_year = ${inputs.year.value}
  and ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
  and direction in ${inputs.direction.value}
  and transfer_type in ${inputs.type.value}
  and transfer_status in ${inputs.status.value}
  and transfer_window in ${inputs.window.value}
order by fee_eur desc
limit 1
```

```sql ledger
select transfer_date, club, direction, transfer_type, transfer_status,
  player_name, player_age, position, partner, partner_country,
  case when fee_eur is null then null else round(fee_eur / 1e6, 2) end as fee_m
from superligaen.mart_club_transfer_log
where transfer_year = ${inputs.year.value}
  and ('All Teams' in ${inputs.team.value} or club in ${inputs.team.value})
  and direction in ${inputs.direction.value}
  and transfer_type in ${inputs.type.value}
  and transfer_status in ${inputs.status.value}
  and transfer_window in ${inputs.window.value}
order by (fee_eur is null), fee_eur desc, transfer_date desc
```

<div class="flex flex-wrap gap-3 items-end mb-2">
  {#key years[0]?.transfer_year}
  <Dropdown data={years} name=year value=transfer_year order="transfer_year desc" defaultValue={years[0]?.transfer_year} title="Year" />
  {/key}
  <Dropdown data={windows} name=window value=transfer_window multiple=true selectAllByDefault=true title="Transfer Window" />
  <Dropdown data={teams} name=team value=club multiple=true defaultValue={['All Teams']} title="Team" />
  <Dropdown data={directions} name=direction value=direction multiple=true selectAllByDefault=true title="Direction" />
  <Dropdown data={types} name=type value=transfer_type multiple=true selectAllByDefault=true title="Type" />
  <Dropdown data={statuses} name=status value=transfer_status multiple=true selectAllByDefault=true title="Status" />
</div>

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 my-5">
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-gray-400 text-xs uppercase tracking-wide text-center">Deals</div>
    <div class="text-3xl font-black text-gray-900 leading-none mt-2 text-center">{kpi[0]?.deals}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-[11px] text-gray-400">Prev: {kpi[0]?.prev_deals ?? '—'}</span>
      {#if kpi[0]?.deals_ratio != null}<span class="text-sm font-bold {kpi[0].deals_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{kpi[0].deals_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-gray-400 text-xs uppercase tracking-wide text-center">Total Deal Amount</div>
    <div class="text-3xl font-black text-gray-900 leading-none mt-2 text-center">€{kpi[0]?.total_m}m</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-[11px] text-gray-400">Prev: €{kpi[0]?.prev_total_m ?? '—'}m</span>
      {#if kpi[0]?.total_ratio != null}<span class="text-sm font-bold {kpi[0].total_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{kpi[0].total_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-gray-400 text-xs uppercase tracking-wide text-center">Avg Deal Amount</div>
    <div class="text-3xl font-black text-gray-900 leading-none mt-2 text-center">€{kpi[0]?.avg_m ?? '—'}m</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-[11px] text-gray-400">Prev: €{kpi[0]?.prev_avg_m ?? '—'}m</span>
      {#if kpi[0]?.avg_ratio != null}<span class="text-sm font-bold {kpi[0].avg_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{kpi[0].avg_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-gray-400 text-xs uppercase tracking-wide text-center">Fee Disclosed Deals</div>
    <div class="text-3xl font-black text-gray-900 leading-none mt-2 text-center">{kpi[0]?.paid}</div>
    <div class="flex justify-between items-center mt-3">
      <span class="text-[11px] text-gray-400">Prev: {kpi[0]?.prev_paid ?? '—'}</span>
      {#if kpi[0]?.paid_ratio != null}<span class="text-sm font-bold {kpi[0].paid_ratio >= 1 ? 'text-green-600' : 'text-red-500'}">{kpi[0].paid_ratio >= 1 ? '▲' : '▼'}</span>{/if}
    </div>
  </div>
</div>

<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-7">
  <div class="rounded-xl border border-emerald-200 bg-emerald-50/40 p-4 shadow-sm flex items-center gap-4">
    <img src="{record_signing[0]?.player_photo}" alt="" class="w-16 h-16 rounded-full object-cover bg-white border border-emerald-100 flex-shrink-0" onerror="this.style.visibility='hidden'" />
    <div class="flex-1 min-w-0">
      <div class="text-[10px] uppercase tracking-widest text-emerald-700 font-bold">🏆 Record Signing</div>
      <div class="text-lg font-bold text-gray-800 truncate">{record_signing[0]?.player_name ?? '—'}</div>
      <div class="text-xs text-gray-500 truncate">{record_signing[0]?.club} ← {record_signing[0]?.partner}</div>
      <div class="text-[11px] text-gray-400 mt-0.5">{record_signing[0]?.transfer_date_fmt}</div>
    </div>
    <div class="text-2xl font-black text-emerald-600 whitespace-nowrap">€{record_signing[0]?.fee_m ?? '—'}m</div>
  </div>
  <div class="rounded-xl border border-orange-200 bg-orange-50/40 p-4 shadow-sm flex items-center gap-4">
    <img src="{record_sale[0]?.player_photo}" alt="" class="w-16 h-16 rounded-full object-cover bg-white border border-orange-100 flex-shrink-0" onerror="this.style.visibility='hidden'" />
    <div class="flex-1 min-w-0">
      <div class="text-[10px] uppercase tracking-widest text-orange-700 font-bold">💰 Record Sale</div>
      <div class="text-lg font-bold text-gray-800 truncate">{record_sale[0]?.player_name ?? '—'}</div>
      <div class="text-xs text-gray-500 truncate">{record_sale[0]?.club} → {record_sale[0]?.partner}</div>
      <div class="text-[11px] text-gray-400 mt-0.5">{record_sale[0]?.transfer_date_fmt}</div>
    </div>
    <div class="text-2xl font-black text-orange-600 whitespace-nowrap">€{record_sale[0]?.fee_m ?? '—'}m</div>
  </div>
</div>

## Net Spend by Team

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Fees <span style="color:#16a34a;font-weight:600;">spent</span> on incoming moves vs <span style="color:#f97316;font-weight:600;">received</span> on outgoing moves, with the resulting <span style="color:#236aa4;font-weight:600;">net spend</span> — the 8 clubs with the highest transfer volume (total fees in + out).</p>

<Chart
    data={by_club}
    x=club
    yFmt='"€"#,##0.00"m"'
    title="Spent vs Received vs Net (€m)"
    yAxisTitle="€m"
    sort=false
    echartsOptions={{xAxis: {axisLabel: {formatter: shortLabel}}}}
>
    <Bar y=spend_m name="Spent" fillColor="#16a34a" />
    <Bar y=income_m name="Received" fillColor="#f97316" />
    <Scatter y=net_spend_m name="Net Spend" fillColor="#236aa4" pointSize={11} />
</Chart>

## Transfers by Team

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;"><span style="color:#16a34a;font-weight:600;">Incoming</span> vs <span style="color:#f97316;font-weight:600;">outgoing</span> moves per club, busiest first.</p>

<BarChart
    data={by_club_busy}
    x=club
    y={['incoming','outgoing']}
    title="Incoming vs Outgoing"
    type=stacked
    colorPalette={['#16a34a','#f97316']}
    sort=false
    echartsOptions={{xAxis: {axisLabel: {formatter: shortLabel}}}}
/>

## Market Over Time <span style="font-size:0.7rem;color:#9ca3af;font-weight:400;">(all years)</span>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={trend_year}
    x=transfer_year
    y=total_value_m
    yFmt='#,##0.00'
    title="Total Value by Year (€m)"
    colorPalette={['#236aa4']}
    sort=false
/>

<LineChart
    data={trend_year}
    x=transfer_year
    y=transfers
    title="Transfers by Year"
    markers=true
    sort=false
    colorPalette={['#236aa4']}
/>

</div>

## Transfer Ledger

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every move matching the filters, biggest fees first. Search and sort to drill in.</p>

<DataTable data={ledger} rows=15 search=true>
    <Column id=transfer_date   title="Date" />
    <Column id=club            title="Club" />
    <Column id=direction       title="Direction" align=center />
    <Column id=transfer_type   title="Type" />
    <Column id=transfer_status title="Status" align=center />
    <Column id=player_name     title="Player" />
    <Column id=player_age      title="Age" align=center />
    <Column id=position        title="Pos" align=center />
    <Column id=partner         title="Counterparty" />
    <Column id=fee_m           title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#236aa4']} />
</DataTable>

<div class="mt-8 text-center text-xs text-gray-400">Fees shown where disclosed.</div>
