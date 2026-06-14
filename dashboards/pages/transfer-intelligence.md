---
sidebar: never
hide_toc: true
title: Transfer Intelligence
---

```sql seasons
select season, season_start_year, is_current
from superligaen.mart_transfer_kpis
order by is_current desc, season_start_year desc
```

```sql kpi
select *,
  round(total_spend_eur / 1e6, 1) as total_spend_m,
  round(biggest_fee_eur / 1e6, 1) as biggest_fee_m
from superligaen.mart_transfer_kpis
where season = '${inputs.season.value}'
```

```sql net_spend
select team_name, team_logo, signings, departures,
  spend_eur, income_eur, net_spend_eur,
  round(net_spend_eur / 1e6, 2) as net_spend_m
from superligaen.mart_club_transfers
where season = '${inputs.season.value}'
  and (signings + departures) > 0
order by net_spend_eur desc
```

```sql busiest
select team_name, signings, departures, (signings + departures) as total_moves
from superligaen.mart_club_transfers
where season = '${inputs.season.value}'
order by total_moves desc
limit 12
```

```sql type_trend
select season, season_start_year, permanent_moves, free_moves, loan_moves
from superligaen.mart_transfer_kpis
order by season_start_year
```

```sql spend_trend
select season, season_start_year, transfers,
  round(total_spend_eur / 1e6, 1) as total_spend_m
from superligaen.mart_transfer_kpis
order by season_start_year
```

```sql biggest_signings
select player_name, position, club, partner, partner_country, transfer_type,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where season = '${inputs.season.value}'
  and direction = 'Incoming'
  and fee_eur is not null
order by fee_eur desc
limit 8
```

```sql biggest_sales
select player_name, position, club, partner, partner_country, transfer_type,
  round(fee_eur / 1e6, 2) as fee_m
from superligaen.mart_club_transfer_log
where season = '${inputs.season.value}'
  and direction = 'Outgoing'
  and fee_eur is not null
order by fee_eur desc
limit 8
```

```sql clubs_in_season
select distinct team_name
from superligaen.mart_club_transfers
where season = '${inputs.season.value}'
  and (signings + departures) > 0
order by team_name
```

```sql club_summary
select *,
  round(spend_eur / 1e6, 2) as spend_m,
  round(income_eur / 1e6, 2) as income_m,
  round(net_spend_eur / 1e6, 2) as net_m
from superligaen.mart_club_transfers
where season = '${inputs.season.value}'
  and team_name = '${inputs.club.value}'
```

```sql club_log
select transfer_date, direction, transfer_type, player_name, position,
  partner, partner_country,
  case when fee_eur is null then null else round(fee_eur / 1e6, 2) end as fee_m
from superligaen.mart_club_transfer_log
where season = '${inputs.season.value}'
  and club = '${inputs.club.value}'
order by (fee_eur is null), fee_eur desc, transfer_date desc
```

<div class="relative rounded-2xl overflow-hidden mb-6 shadow-lg" style="background: linear-gradient(135deg, #1e3a5f 0%, #1a5276 40%, #6b21a8 100%);">
  <div class="absolute inset-0 opacity-[0.08]" style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <div class="relative px-6 py-8 md:px-10 md:py-9 flex flex-col md:flex-row items-center justify-between gap-6">
    <div class="flex items-center gap-5">
      <div class="bg-white/10 backdrop-blur rounded-2xl p-3 shadow-inner flex-shrink-0 text-4xl">🔁</div>
      <div>
        <div class="text-white/50 text-xs uppercase tracking-widest mb-1">Superligaen</div>
        <div class="text-3xl md:text-4xl font-extrabold tracking-tight text-white leading-tight">Transfer Intelligence</div>
        <div class="text-white/50 text-xs mt-1 tracking-wide italic">Ins, outs, fees &amp; net spend across the market</div>
      </div>
    </div>
    <div class="rounded-xl bg-white/10 backdrop-blur border border-white/20 px-5 py-3 text-center">
      <div class="text-white/50 text-xs uppercase tracking-wide mb-1">Season</div>
      <div class="text-white text-2xl font-black leading-none">{inputs.season.value}</div>
    </div>
  </div>
</div>

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} title="Transfer Season" />
{/key}

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 my-5">
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{kpi[0]?.transfers}</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Transfers</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-emerald-600 leading-none">€{kpi[0]?.total_spend_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Disclosed Fees</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-violet-600 leading-none">€{kpi[0]?.biggest_fee_m}m</div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Record Fee</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
    <div class="text-2xl font-black text-gray-800 leading-none">{kpi[0]?.permanent_moves} <span class="text-sm text-gray-400 font-semibold">/ {kpi[0]?.loan_moves} / {kpi[0]?.free_moves}</span></div>
    <div class="text-gray-400 text-xs mt-1 uppercase tracking-wide">Perm / Loan / Free</div>
  </div>
</div>

## Net Spend by Club

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Fees paid on incoming permanents minus fees received on outgoing permanents, {inputs.season.value}. Positive = net investment, negative = net sales.</p>

<BarChart
    data={net_spend}
    x=team_name
    y=net_spend_m
    swapXY=true
    title="Net Spend (€m)"
    yAxisTitle="€m"
    chartAreaHeight=380
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
    data={type_trend}
    x=season
    y={['permanent_moves','loan_moves','free_moves']}
    title="Move Types by Season"
    type=stacked
    colorPalette={['#236aa4','#f4b548','#85c7c6']}
    sort=false
/>

</div>

## Market Over Time

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={spend_trend}
    x=season
    y=total_spend_m
    title="Disclosed Fees by Season (€m)"
    colorPalette={['#16a34a']}
    sort=false
/>

<LineChart
    data={spend_trend}
    x=season
    y=transfers
    title="Transfers by Season"
    markers=true
    sort=false
/>

</div>

## Record Moves — {inputs.season.value}

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<div>
<p style="font-size:0.8rem;font-weight:600;color:#16a34a;margin:0 0 0.5rem 0;">▼ Biggest Signings (in)</p>
<DataTable data={biggest_signings} rows=8>
    <Column id=player_name title="Player" />
    <Column id=club        title="Club" />
    <Column id=partner     title="From" />
    <Column id=fee_m       title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#16a34a']} />
</DataTable>
</div>

<div>
<p style="font-size:0.8rem;font-weight:600;color:#f97316;margin:0 0 0.5rem 0;">▲ Biggest Sales (out)</p>
<DataTable data={biggest_sales} rows=8>
    <Column id=player_name title="Player" />
    <Column id=club        title="Club" />
    <Column id=partner     title="To" />
    <Column id=fee_m       title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#f97316']} />
</DataTable>
</div>

</div>

## Club Explorer

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Full transfer ledger for a single club in {inputs.season.value}.</p>

{#key clubs_in_season[0]?.team_name}
<Dropdown data={clubs_in_season} name=club value=team_name label=team_name defaultValue={clubs_in_season[0]?.team_name} title="Club" />
{/key}

<div class="grid grid-cols-2 md:grid-cols-5 gap-3 my-4">
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-gray-800 leading-none">{club_summary[0]?.signings}</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Signings</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-gray-800 leading-none">{club_summary[0]?.departures}</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Departures</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-emerald-600 leading-none">€{club_summary[0]?.spend_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Spent</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black text-orange-600 leading-none">€{club_summary[0]?.income_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Received</div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-3 shadow-sm text-center">
    <div class="text-xl font-black leading-none" style="color:{club_summary[0]?.net_spend_eur >= 0 ? '#236aa4' : '#16a34a'}">€{club_summary[0]?.net_m}m</div>
    <div class="text-gray-400 text-[10px] mt-1 uppercase tracking-wide">Net Spend</div>
  </div>
</div>

<DataTable data={club_log} rows=15 search=true>
    <Column id=transfer_date  title="Date" />
    <Column id=direction      title="Dir" align=center />
    <Column id=transfer_type  title="Type" />
    <Column id=player_name    title="Player" />
    <Column id=position       title="Pos" align=center />
    <Column id=partner        title="Counterparty" />
    <Column id=partner_country title="Country" />
    <Column id=fee_m          title="Fee" fmt='"€"0.0"m"' align=right contentType=colorscale colorPalette={['white','#236aa4']} />
</DataTable>

<div class="mt-8 text-center text-xs text-gray-400">Transfer windows bucketed into the season they affect (Jul–Jun). Fees shown where disclosed.</div>
