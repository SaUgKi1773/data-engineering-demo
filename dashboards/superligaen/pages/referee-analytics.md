---
sidebar: never
hide_toc: true
title: Referee Intelligence
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';
  const pageInputs = getInputContext();

  $: if (referees?.length > 0) {
    pageInputs.update(($i) => {
      const currentIsValid = referees.some(r => r.referee_name === $i.referee?.value);
      if (currentIsValid) return $i;
      const first = referees[0];
      return { ...$i, referee: { value: first.referee_name, label: first.referee_name, rawValues: [{ value: first.referee_name, label: first.referee_name, selected: true }] } };
    });
  }
</script>

```sql seasons
select distinct season
from superligaen.mart_referee_season
order by season desc
```

```sql referees
select referee_name, matches_managed
from superligaen.mart_referee_season
where season = '${inputs.season.value}'
order by matches_managed desc
```

```sql league_kpis
-- League-wide officiating summary for the season. Card/foul/VAR rates are per
-- match. One referee per match, so sum(matches_managed) = matches officiated.
-- Home card share weights each referee's home-yellow % by their yellow volume.
select
    count(*)                                                                   as total_referees,
    sum(matches_managed)                                                       as matches,
    round(sum(total_yellow_cards)::double / sum(matches_managed), 2)           as yc_per_match,
    round(sum(total_red_cards)::double    / sum(matches_managed), 2)           as rc_per_match,
    round(sum(total_fouls)::double        / sum(matches_managed), 1)           as fouls_per_match,
    round(sum(var_reviews)::double / sum(matches_managed), 2)                  as var_per_match,
    sum(var_reviews)                                                            as total_var_reviews,
    sum(goals_disallowed)                                                       as total_goals_disallowed,
    round(sum(coalesce(home_card_pct, 0) * total_cards)::double
          / nullif(sum(total_cards), 0), 1)                                    as home_card_share
from superligaen.mart_referee_season
where season = '${inputs.season.value}'
```

```sql landscape
select
    referee_name,
    matches_managed,
    total_yellow_cards,
    total_red_cards,
    avg_yellows_per_match,
    avg_reds_per_match,
    avg_fouls_per_match,
    home_card_pct,
    var_reviews,
    goals_disallowed,
    penalties_cancelled
from superligaen.mart_referee_season
where season = '${inputs.season.value}'
order by matches_managed desc
```

```sql var_by_team
with t as (
    select
        team_name,
        goals_disallowed, penalties_cancelled,
        goals_disallowed + penalties_cancelled as total
    from superligaen.mart_var_team
    where season = '${inputs.season.value}'
),
long as (
    select team_name, total, 'Goals Disallowed'    as outcome, goals_disallowed    as decisions from t
    union all select team_name, total, 'Penalties Cancelled',  penalties_cancelled              from t
)
select team_name, outcome, decisions
from long
where total > 0
order by total desc, team_name
```

```sql ref_profile
select * from superligaen.mart_referee_season
where season = '${inputs.season.value}'
  and referee_name = '${inputs.referee.value}'
```

```sql referee_team_exposure
select team_name, count(*)::int as matches
from (
    select referee_name, season, home_team as team_name from superligaen.mart_match_card
    union all
    select referee_name, season, away_team as team_name from superligaen.mart_match_card
) t
where referee_name = '${inputs.referee.value}'
  and season = '${inputs.season.value}'
group by team_name
order by matches desc
```

```sql referee_match_log
select
    mc.match_date,
    mc.match_round_name                            as round,
    mc.match_name,
    mc.score,
    (mc.home_yc + mc.away_yc)::int                 as yellow_cards,
    (mc.home_rc + mc.away_rc)::int                 as red_cards,
    (mc.home_fouls + mc.away_fouls)::int           as fouls,
    coalesce(vm.var_reviews, 0)::int               as var_reviews,
    coalesce(vm.goals_disallowed, 0)::int          as goals_disallowed,
    coalesce(vm.penalties_cancelled, 0)::int       as penalties_cancelled
from superligaen.mart_match_card mc
left join superligaen.mart_var_match vm on vm.match_id = mc.match_id
where mc.referee_name = '${inputs.referee.value}'
  and mc.season = '${inputs.season.value}'
order by mc.match_date desc
```

<p style="font-size:0.85rem;color:#4b5563;margin:0 0 1.25rem 0;">A season-long read on how the Superliga is officiated — the discipline every referee brings to a match, how evenly they treat home and away sides, and the growing footprint of VAR. Pick a season to reset the league landscape, then drop into any referee for their personal profile.</p>

<div class="flex flex-wrap gap-3 items-end mb-6">
  {#key seasons[0]?.season}
  <Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} title="Season" />
  {/key}
</div>

## The Season in Discipline — {inputs.season.value}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every headline officiating number for the season at a glance — how freely cards and fouls are given, how routine VAR has become, and whether the league leans toward the home side. Card, foul and VAR figures are per match.</p>

{#each league_kpis as k}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Referees</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.total_referees ?? '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{k.matches} matches officiated</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Yellow Cards / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.yc_per_match ?? '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{k.rc_per_match} red · {k.fouls_per_match} fouls / match</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Home Team Card Share</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.home_card_share != null ? k.home_card_share + '%' : '—'}</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">VAR Reviews / Match</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{k.var_per_match ?? '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{k.total_var_reviews} reviews · {k.total_goals_disallowed} goals disallowed</div>
  </div>

</div>
{/each}

---

## Strictness & Bias

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every referee ranked by how freely they book (left), then by how evenly they treat the two sides (right). The league averages <b>{league_kpis[0]?.yc_per_match}</b> yellows per match; a referee above 50% on the right gives more of their cards to the home team.</p>

<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">

<BarChart
    data={landscape}
    x=referee_name
    y={['avg_yellows_per_match','avg_reds_per_match']}
    title="Cards per Match"
    yAxisTitle="Cards / Match"
    colorPalette={['#eab308','#ef4444']}
    swapXY=true
    type=stacked
    sort=true
/>

<BarChart
    data={landscape}
    x=referee_name
    y=home_card_pct
    title="Share of Cards to the Home Team"
    yAxisTitle="Home Card %"
    yFmt='0.0'
    colorPalette={['#6366f1']}
    swapXY=true
    sort=true
/>

</div>

---

## Who VAR Ruled Against — {inputs.season.value}

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The calls that went against each team this season — goals ruled out and penalties scrubbed by video review — ranked by how often a team was on the wrong end. Each decision is counted for the team it was taken from; the goals and penalties VAR awarded, and routine card checks, are left out. Categorised from 2023/24 onward.</p>

<BarChart
    data={var_by_team}
    x=team_name
    y=decisions
    series=outcome
    title="VAR Rulings Against Each Team"
    xAxisTitle="Team"
    yAxisTitle="Decisions against"
    type=stacked
    swapXY=true
    colorPalette={['#ef4444','#f59e0b']}
    sort=true
/>

---

## Season Leaderboard

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The full table behind the charts above — cards, fouls, and the VAR rulings that landed in each referee's matches this season. Sortable and searchable; the colour scales highlight the outliers at a glance.</p>

<DataTable data={landscape} rows=15 search=true downloadable=true>
    <Column id=referee_name          title="Referee"           wrap=true />
    <Column id=matches_managed       title="Games"             contentType=colorscale colorPalette={['white','#3b82f6']} align=center />
    <Column id=total_yellow_cards    title="YC"                contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards       title="RC"                contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=avg_fouls_per_match   title="Fouls / Match"     contentType=colorscale colorPalette={['white','#f97316']} />
    <Column id=var_reviews           title="VAR Reviews"       contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=goals_disallowed      title="Goals Disallowed"  contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=penalties_cancelled   title="Pens Cancelled"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
</DataTable>

<div class="border-t-2 border-gray-100 mt-12 mb-2"></div>

## Referee Deep Dive

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Zoom into a single official — their season profile, the clubs they saw most, and their full match-by-match record including the VAR calls in each game.</p>

{#key referees[0]?.referee_name}
<div class="flex flex-wrap gap-3 items-end mb-6">
  <Dropdown data={referees} name=referee value=referee_name label=referee_name defaultValue={referees[0]?.referee_name} title="Referee" />
</div>
{/key}

{#each ref_profile as r}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-8 shadow-xl">
  <div class="text-center md:text-left">
    <div class="text-3xl md:text-4xl font-extrabold text-white tracking-tight">{r.referee_name}</div>
    <div class="text-gray-400 text-sm mt-1 mb-5">{inputs.season.value} · {r.matches_managed} matches officiated</div>
    <div class="flex flex-wrap justify-center md:justify-start gap-x-8 gap-y-4">
      <div class="text-center"><div class="text-2xl font-black text-yellow-400">{r.total_yellow_cards}</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Yellow Cards</div></div>
      <div class="text-center"><div class="text-2xl font-black text-red-400">{r.total_red_cards}</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Red Cards</div></div>
      <div class="text-center"><div class="text-2xl font-black text-white">{r.avg_yellows_per_match}</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">YC / Match</div></div>
      <div class="text-center"><div class="text-2xl font-black text-white">{r.avg_fouls_per_match}</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Fouls / Match</div></div>
      <div class="text-center"><div class="text-2xl font-black text-white">{r.home_card_pct}%</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">Home Card %</div></div>
      <div class="text-center"><div class="text-2xl font-black text-white">{r.var_reviews}</div><div class="text-xs text-gray-400 uppercase tracking-widest mt-1">VAR Reviews</div></div>
    </div>
  </div>
</div>
{/each}

### Team Exposure

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Which clubs {inputs.referee.value} took charge of most this season.</p>

<BarChart
    data={referee_team_exposure}
    x=team_name
    y=matches
    title="Matches per Team"
    yAxisTitle="Matches"
    colorPalette={['#6366f1']}
    swapXY=true
    sort=true
/>

### Match Log

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The full game-by-game record — cards and fouls, plus what the video team changed in each match: reviews, goals ruled out, and penalties scrubbed.</p>

<DataTable data={referee_match_log} rows=10 search=true downloadable=true>
    <Column id=match_date          title="Date"   />
    <Column id=round               title="Round"  />
    <Column id=match_name          title="Match"  wrap=true />
    <Column id=score               title="Score"  align=center />
    <Column id=yellow_cards        title="YC"     contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=red_cards           title="RC"     contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=fouls               title="Fouls"  contentType=colorscale colorPalette={['white','#f97316']} align=center />
    <Column id=var_reviews         title="VAR"    contentType=colorscale colorPalette={['white','#6366f1']} align=center />
    <Column id=goals_disallowed    title="Goals Disallowed" contentType=colorscale colorPalette={['white','#ef4444']} align=center />
    <Column id=penalties_cancelled title="Pens Cancelled"   contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
</DataTable>

```sql last_updated
select * from superligaen.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
