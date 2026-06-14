---
sidebar: never
hide_toc: true
title: Transfer Intelligence
---

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord from superligaen.mart_club_transfers
) order by ord, team_name
```

```sql years
select distinct transfer_year
from superligaen.mart_transfer_kpis
order by transfer_year desc
```

```sql league_kpi
select
  sum(transfers)        as transfers,
  sum(permanent_moves)  as permanent_moves,
  sum(loan_moves)       as loan_moves,
  sum(free_moves)       as free_moves,
  round(sum(total_spend_eur) / 1e6, 1) as total_spend_m,
  round(max(biggest_fee_eur) / 1e6, 1) as biggest_fee_m
from superligaen.mart_transfer_kpis
where transfer_year in ${inputs.year.value}
```

```sql trend
select transfer_year, transfers, permanent_moves, loan_moves, free_moves,
  round(total_spend_eur / 1e6, 1) as total_spend_m
from superligaen.mart_transfer_kpis
where transfer_year in ${inputs.year.value}
order by transfer_year
```

```sql net_spend
select team_name,
  sum(signings) as signings, sum(departures) as departures,
  round(sum(net_spend_eur) / 1e6, 2) as net_spend_m
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
group by team_name
having sum(signings) + sum(departures) > 0
order by sum(net_spend_eur) desc
```

```sql busiest
select team_name, sum(signings) as signings, sum(departures) as departures
from superligaen.mart_club_transfers
where transfer_year in ${inputs.year.value}
group by team_name
order by sum(signings) + sum(departures) desc
limit 12
```

```sql biggest_signings
select player_name, club, partner, transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Incoming' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
order by fee_eur desc
limit 10
```

```sql biggest_sales
select player_name, club, partner, transfer_year,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where direction = 'Outgoing' and fee_eur is not null
  and transfer_year in ${inputs.year.value}
order by fee_eur desc
limit 10
```

```sql team_kpi
select
  sum(signings)   as signings,
  sum(departures) as departures,
  round(sum(spend_eur) / 1e6, 2)      as spend_m,
  round(sum(income_eur) / 1e6, 2)     as income_m,
  round(sum(net_spend_eur) / 1e6, 2)  as net_m,
  sum(net_spend_eur)                  as net_raw
from superligaen.mart_club_transfers
where team_name = '${inputs.team.value}'
  and transfer_year in ${inputs.year.value}
```

```sql team_year
select transfer_year, signings, departures,
  round(spend_eur / 1e6, 2)  as spend_m,
  round(income_eur / 1e6, 2) as income_m
from superligaen.mart_club_transfers
where team_name = '${inputs.team.value}'
  and transfer_year in ${inputs.year.value}
order by transfer_year
```

```sql team_log
select transfer_date, transfer_window, direction, transfer_type, player_name, position,
  partner, partner_country,
  case when fee_eur is null then null else round(fee_eur / 1e6, 2) end as fee_m
from superligaen.mart_club_transfer_log
where club = '${inputs.team.value}'
  and transfer_year in ${inputs.year.value}
order by (fee_eur is null), fee_eur desc, transfer_date desc
```

<div class="relative rounded-2xl overflow-hidden mb-6 shadow-lg" style="background: linear-gradient(135deg, #1e3a5f 0%, #1a5276 40%, #6b21a8 100%);">
  <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <div class="relative px-6 py-8 md:px-10 md:py-9 flex flex-col md:flex-row items-center justify-between gap-6">
    <div class="flex items-center gap-5">
      <div class="bg-white/10 backdrop-blur rounded-2xl p-3 shadow-inner flex-shrink-0 text-4xl">🔁</div>
      <div>
        <div class="text-white/50 text-xs uppercase tracking-widest mb-1">Superligaen · since 2020</div>
        <div class="text-3xl md:text-4xl font-extrabold tracking-tight text-white leading-tight">Transfer Intelligence</div>
        <div class="text-white/50 text-xs mt-1 tracking-wide italic">Ins, outs, fees &amp; net spend across the market</div>
      </div>
    </div>
    <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-5 py-3 text-center">
      <div class="text-white/50 text-xs uppercase tracking-wide mb-1">Viewing</div>
      <div class="text-white text-2xl font-black leading-none">{inputs.team.value}</div>
    </div>
  </div>
</div>

<div class="flex flex-wrap gap-3 items-end">
  <Dropdown data={years} name=year value=transfer_year multiple=true selectAllByDefault=true order="transfer_year desc" title="Year" />
  <Dropdown data={teams} name=team value=team_name label=team_name defaultValue="All Teams" title="Club" />
</div>

{#if inputs.team.value === 'All Teams'}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 my-5">
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{league_kpi[0]?.transfers}</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Transfers</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-emerald-600 leading-none">€{league_kpi[0]?.total_spend_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Disclosed Fees</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-violet-600 leading-none">€{league_kpi[0]?.biggest_fee_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Record Fee</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{league_kpi[0]?.permanent_moves} <span class="text-sm text-gray-400 font-semibold">/ {league_kpi[0]?.loan_moves} / {league_kpi[0]?.free_moves}</span></div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Perm / Loan / Free</div>
  </div>
</div>

## Net Spend by Club

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Fees paid on incoming permanents minus fees received on outgoing permanents, 2020 onward. Positive = net investment, negative = net sales.</p>

<BarChart
    data={net_spend}
    x=team_name
    y=net_spend_m
    swapXY=true
    title="Net Spend (€m)"
    yAxisTitle="€m"
    chartAreaHeight=400
    sort=false
    colorPalette={['#236aa4']}
/>

## Market Activity

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={busiest}
    x=team_name
    y={['signings','departures']}
    title="Busiest Clubs — Ins vs Outs"
    type=grouped
    swapXY=true
    colorPalette={['#16a34a','#f97316']}
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={trend}
    x=transfer_year
    y={['permanent_moves','loan_moves','free_moves']}
    title="Move Types by Year"
    type=stacked
    colorPalette={['#236aa4','#f4b548','#85c7c6']}
    sort=false
/>

</div>

## Market Over Time

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={trend}
    x=transfer_year
    y=total_spend_m
    title="Disclosed Fees by Year (€m)"
    colorPalette={['#16a34a']}
    sort=false
/>

<LineChart
    data={trend}
    x=transfer_year
    y=transfers
    title="Transfers by Year"
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

{:else}

<div class="grid grid-cols-2 md:grid-cols-5 gap-3 my-5">
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-gray-800 leading-none">{team_kpi[0]?.signings}</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Signings</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-gray-800 leading-none">{team_kpi[0]?.departures}</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Departures</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-emerald-600 leading-none">€{team_kpi[0]?.spend_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Spent</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-orange-600 leading-none">€{team_kpi[0]?.income_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Received</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black leading-none" style="color:{team_kpi[0]?.net_raw >= 0 ? '#236aa4' : '#16a34a'}">€{team_kpi[0]?.net_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Net Spend</div>
  </div>
</div>

## {inputs.team.value} — Activity by Year

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={team_year}
    x=transfer_year
    y={['signings','departures']}
    title="Ins vs Outs"
    type=grouped
    colorPalette={['#16a34a','#f97316']}
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

<BarChart
    data={team_year}
    x=transfer_year
    y={['spend_m','income_m']}
    title="Spend vs Income (€m)"
    type=grouped
    colorPalette={['#236aa4','#f4b548']}
    seriesOptions={{"barGap": "0%"}}
    sort=false
/>

</div>

## {inputs.team.value} — Transfer Ledger

<DataTable data={team_log} rows=15 search=true>
    <Column id=transfer_date   title="Date" />
    <Column id=transfer_window title="Window" align=center />
    <Column id=direction       title="Dir" align=center />
    <Column id=transfer_type   title="Type" />
    <Column id=player_name     title="Player" />
    <Column id=position        title="Pos" align=center />
    <Column id=partner         title="Counterparty" />
    <Column id=partner_country  title="Country" />
    <Column id=fee_m           title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#236aa4']} />
</DataTable>

{/if}

<div class="mt-8 text-center text-xs text-gray-400">Transfer windows: Summer (Jun–Sep), Winter (Jan–Feb). Fees shown where disclosed.</div>
