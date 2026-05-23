---
sidebar: never
hide_toc: true
title: Match Results
---

<script>
  import MatchLineup from '../../components/MatchLineup.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';

  const pageInputs = getInputContext();

  // When match_options reloads (season/round changed) and the current match is
  // no longer in the list, update the store to the first valid match so the
  // dropdown re-mounts with the correct rawValues instead of the stale ones.
  $: if (match_options?.length > 0) {
    pageInputs.update(($i) => {
      const currentIsValid = match_options.some(o => o.match_key === $i.match?.value);
      if (currentIsValid) return $i;
      const first = match_options[0];
      return {
        ...$i,
        match: {
          value: first.match_key,
          label: first.match_label,
          rawValues: [{ value: first.match_key, label: first.match_label, selected: true }]
        }
      };
    });
  }

  let commentText = '';
  let userComments = [];

  $: matchKey = inputs?.season?.value && inputs?.round?.value && inputs?.match?.value
    ? `fanforum_${inputs.season.value}_${inputs.round.value}_${inputs.match.value}`
    : null;

  $: if (typeof window !== 'undefined' && matchKey !== undefined) {
    const stored = matchKey ? localStorage.getItem(matchKey) : null;
    userComments = stored ? JSON.parse(stored) : [];
    commentText = '';
  }

  function postComment() {
    if (!commentText.trim() || !matchKey) return;
    const entry = { text: commentText.trim(), time: new Date().toISOString().split('T')[0] };
    userComments = [...userComments, entry];
    localStorage.setItem(matchKey, JSON.stringify(userComments));
    commentText = '';
  }

  function handleKeydown(e) {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) postComment();
  }

  function daysAgo(dateVal) {
    if (!dateVal) return '';
    const match = new Date(dateVal);
    if (isNaN(match)) return '';
    match.setHours(12, 0, 0, 0);
    const today = new Date();
    today.setHours(12, 0, 0, 0);
    const diff = Math.round((today - match) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return '1 day ago';
    return `${diff} days ago`;
  }
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_match_facts
  group by season
) order by is_current desc, season desc
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

```sql rounds
select distinct cast(match_round_number as integer) as round_number
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and result in ('Win', 'Draw', 'Loss')
order by 1 desc
```

{#key `${inputs.season.value}|${rounds[0]?.round_number}`}
<Dropdown data={rounds} name=round value=round_number label=round_number defaultValue={rounds[0]?.round_number} order="round_number desc" />
{/key}

```sql results
select
    match_id,
    match_date,
    match_round_name                as round,
    match_round_number,
    match_name,
    match_short_name,
    score,
    sum(goals_scored)               as total_goals,
    sum(shots_on_goal)              as total_shots_on_goal,
    sum(total_shots)                as total_shots,
    sum(big_chances_created)        as total_big_chances,
    sum(yellow_cards)               as total_yellow_cards,
    sum(red_cards)                  as total_red_cards,
    referee_name                    as referee,
    season
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) = ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_id, match_date, match_round_name, match_round_number, match_name, match_short_name, score, referee_name, season
order by match_date desc
```

```sql round_kpis
select
    sum(total_goals)                                                                        as total_goals,
    round(sum(total_goals)::double / count(distinct match_id), 2)                          as avg_goals_per_match,
    round(sum(total_shots_on_goal)::double / count(distinct match_id), 1)                  as avg_shots_on_goal,
    round(sum(total_goals)::double / nullif(sum(total_big_chances), 0), 2)                   as goals_per_big_chance
from ${results}
```

```sql discussions
select persona_name, persona_icon, sort_order, message, match_date
from superligaen.llm_round_discussions
where season      = '${inputs.season.value}'
  and round_number = ${inputs.round.value}
  and match_name   = split_part('${inputs.match.value}', '|', 1)
order by sort_order
```

## Match Results — {inputs.season.value} — Round {inputs.round.value}

<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=total_goals          title="Goals Scored"       /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_goals_per_match   title="Avg Goals / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=avg_shots_on_goal     title="Avg Shots on Goal / Match"  /></div>
  <div class="rounded-xl border border-gray-300 bg-gray-100 p-4 text-center"><BigValue data={round_kpis} value=goals_per_big_chance   title="Goals / Big Chance"  fmt="0.00" /></div>
</div>

<div class="block md:hidden">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_short_name    title="Match"          wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Ch."        contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>
<div class="hidden md:block">
<DataTable data={results} rows=20>
    <Column id=match_date          title="Date"           />
    <Column id=match_name          title="Match"          wrap=true />
    <Column id=referee             title="Referee"        />
    <Column id=score               title="Score"          align=center />
    <Column id=total_goals         title="Goals"          contentType=colorscale colorPalette={['white','#22c55e']} align=center />
    <Column id=total_shots         title="Shots"          contentType=bar        colorPalette={['#6366f1']} />
    <Column id=total_big_chances   title="Big Chances"    contentType=colorscale colorPalette={['white','#f59e0b']} align=center />
    <Column id=total_yellow_cards  title="YC"             contentType=colorscale colorPalette={['white','#eab308']} align=center />
    <Column id=total_red_cards     title="RC"             contentType=colorscale colorPalette={['white','#ef4444']} align=center />
</DataTable>
</div>

```sql potw
with base as (
  select
    player_name,
    player_photo,
    team_name,
    team_logo,
    rating,
    position_group,
    minutes_played
  from superligaen.mart_player_facts
  where season = '${inputs.season.value}'
    and cast(match_round_number as integer) = ${inputs.round.value}
    and result in ('Win', 'Draw', 'Loss')
    and appearance_type in ('Starter', 'Substitute')
    and rating is not null
    and minutes_played >= 30
),
overall_ranked as (
  select *,
    ROW_NUMBER() OVER (ORDER BY rating DESC, minutes_played DESC) as rn_best,
    ROW_NUMBER() OVER (ORDER BY rating ASC,  minutes_played DESC) as rn_worst
  from base
),
position_ranked as (
  select *,
    ROW_NUMBER() OVER (PARTITION BY position_group ORDER BY rating DESC, minutes_played DESC) as rn
  from base
  where player_name not in (select player_name from overall_ranked where rn_best = 1)
),
mvp as (
  select 'MVP' as category, '⭐' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 1 as sort_order
  from overall_ranked where rn_best = 1
),
best_attacker as (
  select 'Best Attacker' as category, '⚽' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 2 as sort_order
  from position_ranked where position_group = 'Attacker' and rn = 1
),
best_midfielder as (
  select 'Best Midfielder' as category, '🎯' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 3 as sort_order
  from position_ranked where position_group = 'Midfielder' and rn = 1
),
best_defender as (
  select 'Best Defender' as category, '🛡️' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 4 as sort_order
  from position_ranked where position_group = 'Defender' and rn = 1
),
best_gk as (
  select 'Best GK' as category, '🧤' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 5 as sort_order
  from position_ranked where position_group = 'Goalkeeper' and rn = 1
),
lvp as (
  select 'LVP' as category, '📉' as icon,
         player_name, player_photo, team_name, team_logo,
         cast(round(rating, 2) as varchar) as stat_value, 'Rating' as stat_label, 6 as sort_order
  from overall_ranked where rn_worst = 1
)
select * from mvp
union all select * from best_attacker
union all select * from best_midfielder
union all select * from best_defender
union all select * from best_gk
union all select * from lvp
order by sort_order
```

{#if potw.length > 0}
## Players of the Week

<div class="grid grid-cols-3 md:grid-cols-6 gap-3 mb-6">
  {#each potw as p}
  <div style="background:white;border:1px solid #e5e7eb;border-radius:12px;padding:12px 8px;text-align:center;display:flex;flex-direction:column;align-items:center;">
    <div style="font-size:16px;height:22px;display:flex;align-items:center;justify-content:center;">{p.icon}</div>
    <div style="font-size:10px;font-weight:700;color:#6b7280;height:28px;display:flex;align-items:center;justify-content:center;line-height:1.3;margin-bottom:6px;">{p.category}</div>
    <img src={p.player_photo} alt={p.player_name}
      style="width:48px;height:48px;border-radius:50%;object-fit:cover;flex-shrink:0;margin-bottom:8px;"
      onerror="this.style.display='none'" />
    <div style="font-weight:800;font-size:11px;color:#111827;height:16px;line-height:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.player_name}</div>
    <div style="font-size:10px;color:#9ca3af;height:14px;line-height:14px;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:100%;">{p.team_name}</div>
    <div style="font-size:20px;font-weight:900;color:#111827;margin-top:8px;line-height:1;">{p.stat_value}</div>
    <div style="font-size:10px;color:#9ca3af;margin-top:2px;">{p.stat_label}</div>
  </div>
  {/each}
</div>
{/if}

---

## Match Analysis

<p style="font-size:13px;color:#6b7280;margin:-8px 0 16px;">Select a match to analyze head-to-head stats, formations, and player performance.</p>

```sql match_options
select
    match_name || '|' || cast(match_date as varchar) as match_key,
    match_short_name || '  (' || score || ')'        as match_label,
    match_date
from superligaen.mart_match_facts
where season = '${inputs.season.value}'
  and cast(match_round_number as integer) = ${inputs.round.value}
  and result in ('Win', 'Draw', 'Loss')
group by match_name, match_short_name, match_date, score
order by match_date desc
```

{#key match_options[0]?.match_key}
<Dropdown data={match_options} name=match value=match_key label=match_label defaultValue={match_options[0]?.match_key} order="match_date desc" />
{/key}

```sql mc
select
    max(case when team_side = 'Home' then team_name end)                                        as home_team,
    max(case when team_side = 'Away' then team_name end)                                        as away_team,
    max(case when team_side = 'Home' then team_short_name end)                                  as home_team_short,
    max(case when team_side = 'Away' then team_short_name end)                                  as away_team_short,
    max(score)                                                                                  as score,
    max(case when team_side = 'Home' then goals_scored end)                                     as home_goals,
    max(case when team_side = 'Away' then goals_scored end)                                     as away_goals,
    max(case when team_side = 'Home' then total_shots end)                                      as home_total_shots,
    max(case when team_side = 'Away' then total_shots end)                                      as away_total_shots,
    max(case when team_side = 'Home' then shots_on_goal end)                                    as home_sog,
    max(case when team_side = 'Away' then shots_on_goal end)                                    as away_sog,
    max(case when team_side = 'Home' then big_chances_created end)                              as home_big_chances,
    max(case when team_side = 'Away' then big_chances_created end)                              as away_big_chances,
    max(case when team_side = 'Home' then woodwork_hits end)                                    as home_woodwork,
    max(case when team_side = 'Away' then woodwork_hits end)                                    as away_woodwork,
    max(case when team_side = 'Home' then possession_pct end)                                   as home_possession,
    max(case when team_side = 'Away' then possession_pct end)                                   as away_possession,
    round(max(case when team_side = 'Home' then passes_accurate end)::double / nullif(max(case when team_side = 'Home' then total_passes end), 0) * 100, 1) as home_pass_accuracy,
    round(max(case when team_side = 'Away' then passes_accurate end)::double / nullif(max(case when team_side = 'Away' then total_passes end), 0) * 100, 1) as away_pass_accuracy,
    max(case when team_side = 'Home' then key_passes end)                                       as home_key_passes,
    max(case when team_side = 'Away' then key_passes end)                                       as away_key_passes,
    max(case when team_side = 'Home' then crosses_total end)                                    as home_crosses,
    max(case when team_side = 'Away' then crosses_total end)                                    as away_crosses,
    max(case when team_side = 'Home' then corner_kicks end)                                     as home_corners,
    max(case when team_side = 'Away' then corner_kicks end)                                     as away_corners,
    max(case when team_side = 'Home' then tackles end)                                          as home_tackles,
    max(case when team_side = 'Away' then tackles end)                                          as away_tackles,
    max(case when team_side = 'Home' then interceptions end)                                    as home_interceptions,
    max(case when team_side = 'Away' then interceptions end)                                    as away_interceptions,
    max(case when team_side = 'Home' then clearances end)                                       as home_clearances,
    max(case when team_side = 'Away' then clearances end)                                       as away_clearances,
    max(case when team_side = 'Home' then saves end)                                            as home_saves,
    max(case when team_side = 'Away' then saves end)                                            as away_saves,
    max(case when team_side = 'Home' then fouls end)                                            as home_fouls,
    max(case when team_side = 'Away' then fouls end)                                            as away_fouls,
    max(case when team_side = 'Home' then yellow_cards end)                                     as home_yc,
    max(case when team_side = 'Away' then yellow_cards end)                                     as away_yc,
    max(case when team_side = 'Home' then red_cards end)                                        as home_rc,
    max(case when team_side = 'Away' then red_cards end)                                        as away_rc
from superligaen.mart_match_facts
where match_name            = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and season                = '${inputs.season.value}'
```

<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2">

  <div class="grid grid-cols-3 text-center border-b border-gray-200 pb-4 mb-2">
    <div class="text-left font-bold text-lg text-blue-600">{mc[0]?.home_team_short}<div class="text-xs font-normal text-gray-400">Home</div></div>
    <div class="text-center text-2xl font-bold text-gray-700">{mc[0]?.score}</div>
    <div class="text-right font-bold text-lg text-orange-500">{mc[0]?.away_team_short}<div class="text-xs font-normal text-gray-400">Away</div></div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_goals}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Goals</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_goals}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0) > 0 ? (mc[0]?.home_goals ?? 0) / ((mc[0]?.home_goals ?? 0) + (mc[0]?.away_goals ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_total_shots}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Total Shots</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_total_shots}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_total_shots ?? 0) + (mc[0]?.away_total_shots ?? 0) > 0 ? (mc[0]?.home_total_shots ?? 0) / ((mc[0]?.home_total_shots ?? 0) + (mc[0]?.away_total_shots ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_sog}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Shots on Goal</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_sog}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0) > 0 ? (mc[0]?.home_sog ?? 0) / ((mc[0]?.home_sog ?? 0) + (mc[0]?.away_sog ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_big_chances}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Big Chances</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_big_chances}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_big_chances ?? 0) + (mc[0]?.away_big_chances ?? 0) > 0 ? (mc[0]?.home_big_chances ?? 0) / ((mc[0]?.home_big_chances ?? 0) + (mc[0]?.away_big_chances ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_woodwork}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Woodwork Hits</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_woodwork}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_woodwork ?? 0) + (mc[0]?.away_woodwork ?? 0) > 0 ? (mc[0]?.home_woodwork ?? 0) / ((mc[0]?.home_woodwork ?? 0) + (mc[0]?.away_woodwork ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_possession}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Possession</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_possession}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{mc[0]?.home_possession || 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_pass_accuracy}%</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Pass Accuracy</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_pass_accuracy}%</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0) > 0 ? (mc[0]?.home_pass_accuracy ?? 0) / ((mc[0]?.home_pass_accuracy ?? 0) + (mc[0]?.away_pass_accuracy ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_key_passes}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Key Passes</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_key_passes}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_key_passes ?? 0) + (mc[0]?.away_key_passes ?? 0) > 0 ? (mc[0]?.home_key_passes ?? 0) / ((mc[0]?.home_key_passes ?? 0) + (mc[0]?.away_key_passes ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_crosses}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Crosses</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_crosses}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_crosses ?? 0) + (mc[0]?.away_crosses ?? 0) > 0 ? (mc[0]?.home_crosses ?? 0) / ((mc[0]?.home_crosses ?? 0) + (mc[0]?.away_crosses ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_corners}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Corners</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_corners}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0) > 0 ? (mc[0]?.home_corners ?? 0) / ((mc[0]?.home_corners ?? 0) + (mc[0]?.away_corners ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_tackles}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Tackles</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_tackles}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_tackles ?? 0) + (mc[0]?.away_tackles ?? 0) > 0 ? (mc[0]?.home_tackles ?? 0) / ((mc[0]?.home_tackles ?? 0) + (mc[0]?.away_tackles ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_interceptions}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Interceptions</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_interceptions}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_interceptions ?? 0) + (mc[0]?.away_interceptions ?? 0) > 0 ? (mc[0]?.home_interceptions ?? 0) / ((mc[0]?.home_interceptions ?? 0) + (mc[0]?.away_interceptions ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_clearances}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Clearances</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_clearances}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_clearances ?? 0) + (mc[0]?.away_clearances ?? 0) > 0 ? (mc[0]?.home_clearances ?? 0) / ((mc[0]?.home_clearances ?? 0) + (mc[0]?.away_clearances ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_saves}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Saves</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_saves}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0) > 0 ? (mc[0]?.home_saves ?? 0) / ((mc[0]?.home_saves ?? 0) + (mc[0]?.away_saves ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_fouls}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Fouls</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_fouls}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0) > 0 ? (mc[0]?.home_fouls ?? 0) / ((mc[0]?.home_fouls ?? 0) + (mc[0]?.away_fouls ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2 border-b border-gray-100">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_yc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Yellow Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_yc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0) > 0 ? (mc[0]?.home_yc ?? 0) / ((mc[0]?.home_yc ?? 0) + (mc[0]?.away_yc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

  <div class="py-2">
    <div class="grid grid-cols-3 items-center text-center mb-1.5">
      <div class="font-semibold text-lg text-blue-600">{mc[0]?.home_rc}</div>
      <div class="text-gray-400 text-xs uppercase tracking-wide">Red Cards</div>
      <div class="font-semibold text-lg text-orange-500">{mc[0]?.away_rc}</div>
    </div>
    <div class="flex h-1 rounded-full overflow-hidden bg-orange-400">
      <div class="bg-blue-500" style="width:{(mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0) > 0 ? (mc[0]?.home_rc ?? 0) / ((mc[0]?.home_rc ?? 0) + (mc[0]?.away_rc ?? 0)) * 100 : 50}%"></div>
    </div>
  </div>

</div>

---

## Lineup

<p style="font-size:13px;color:#6b7280;margin:-8px 0 16px;">Click on a player to see their stats for this match.</p>

```sql lineup
select
    player_name,
    player_photo,
    team_name,
    team_logo,
    team_side,
    position_group,
    position_name,
    position_short_code,
    formation,
    minutes_played,
    goals_scored,
    assists,
    shots_total,
    shots_on_target,
    woodwork_hits,
    key_passes,
    big_chances_created,
    big_chances_missed,
    dribbles_completed,
    crosses_total,
    round(passes_accurate::double / nullif(passes_total, 0) * 100, 1) as pass_accuracy,
    tackles,
    interceptions,
    clearances,
    aerials_won,
    blocks,
    fouls_committed,
    fouls_drawn,
    saves,
    yellow_cards,
    red_cards,
    own_goals,
    tackles_won,
    aerials_lost,
    balls_recovered,
    last_man_tackle,
    clearances_off_line,
    duels_total,
    duels_won,
    duels_lost,
    dribbles_attempts,
    times_dribbled_past,
    dispossessed,
    possession_losses,
    passes_final_third,
    long_balls,
    long_balls_won,
    saves_inside_box,
    goalkeeper_punches,
    high_ball_claims,
    goals_conceded,
    penalty_won,
    penalty_committed,
    penalty_scored,
    penalty_missed,
    penalty_saved,
    offsides,
    yellow_red_cards,
    errors_leading_to_goal,
    errors_leading_to_shot,
    round(rating, 2) as rating
from superligaen.mart_player_facts
where match_name                 = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Starter'
order by team_side desc, position_group, position_name
```

```sql subs
select
    player_name,
    player_photo,
    team_name,
    team_side,
    position_group,
    position_name,
    position_short_code,
    formation,
    minutes_played,
    goals_scored,
    assists,
    shots_total,
    shots_on_target,
    woodwork_hits,
    key_passes,
    big_chances_created,
    big_chances_missed,
    dribbles_completed,
    crosses_total,
    round(passes_accurate::double / nullif(passes_total, 0) * 100, 1) as pass_accuracy,
    tackles,
    interceptions,
    clearances,
    aerials_won,
    blocks,
    fouls_committed,
    fouls_drawn,
    saves,
    yellow_cards,
    red_cards,
    own_goals,
    tackles_won,
    aerials_lost,
    balls_recovered,
    last_man_tackle,
    clearances_off_line,
    duels_total,
    duels_won,
    duels_lost,
    dribbles_attempts,
    times_dribbled_past,
    dispossessed,
    possession_losses,
    passes_final_third,
    long_balls,
    long_balls_won,
    saves_inside_box,
    goalkeeper_punches,
    high_ball_claims,
    goals_conceded,
    penalty_won,
    penalty_committed,
    penalty_scored,
    penalty_missed,
    penalty_saved,
    offsides,
    yellow_red_cards,
    errors_leading_to_goal,
    errors_leading_to_shot,
    round(rating, 2) as rating
from superligaen.mart_player_facts
where match_name                 = split_part('${inputs.match.value}', '|', 1)
  and cast(match_date as varchar) = split_part('${inputs.match.value}', '|', 2)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Substitute'
order by team_side desc, position_group, position_name
```

<MatchLineup {lineup} {subs} home_team={mc[0]?.home_team} away_team={mc[0]?.away_team} score={mc[0]?.score} />

{#if discussions.length > 0}

---

<div style="display:flex;align-items:baseline;gap:10px;margin-bottom:4px;">
  <h2 style="margin:0;">Fan Forum</h2>
  <span style="font-size:0.8125rem;color:#6b7280;">{discussions.length + userComments.length} comments</span>
</div>

<p style="font-size:0.8125rem;color:#6b7280;margin:0 0 20px;font-style:italic;">Fan reactions to this match. Drop your take below.</p>

<div style="display:flex;flex-direction:column;gap:0;margin-bottom:32px;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
  {#each discussions as post}
  <div style="display:flex;gap:12px;padding:16px 20px;background:white;border-bottom:1px solid #f3f4f6;">
    <div style="flex-shrink:0;width:36px;height:36px;border-radius:50%;background:#f3f4f6;display:flex;align-items:center;justify-content:center;font-size:1.125rem;line-height:1;">
      {post.persona_icon}
    </div>
    <div style="flex:1;min-width:0;">
      <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:6px;">
        <span style="font-size:0.8125rem;font-weight:700;color:#111827;">{post.persona_name}</span>
        <span style="font-size:0.75rem;color:#9ca3af;">· {daysAgo(post.match_date)}</span>
      </div>
      <div style="font-size:0.875rem;color:#374151;line-height:1.6;">{post.message}</div>
    </div>
  </div>
  {/each}

  {#each userComments as comment}
  <div style="display:flex;gap:12px;padding:16px 20px;background:white;border-bottom:1px solid #f3f4f6;">
    <div style="flex-shrink:0;width:36px;height:36px;border-radius:50%;background:#dbeafe;display:flex;align-items:center;justify-content:center;font-size:1.125rem;line-height:1;">
      👤
    </div>
    <div style="flex:1;min-width:0;">
      <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:6px;">
        <span style="font-size:0.8125rem;font-weight:700;color:#111827;">You</span>
        <span style="font-size:0.75rem;color:#9ca3af;">· {daysAgo(comment.time)}</span>
      </div>
      <div style="font-size:0.875rem;color:#374151;line-height:1.6;">{comment.text}</div>
    </div>
  </div>
  {/each}

  <div style="display:flex;gap:12px;padding:16px 20px;background:#fafafa;">
    <div style="flex-shrink:0;width:36px;height:36px;border-radius:50%;background:#dbeafe;display:flex;align-items:center;justify-content:center;font-size:1.125rem;line-height:1;">
      👤
    </div>
    <div style="flex:1;min-width:0;">
      <textarea
        bind:value={commentText}
        on:keydown={handleKeydown}
        placeholder="Add a comment…"
        rows="2"
        style="width:100%;border:1px solid #e5e7eb;border-radius:8px;padding:8px 12px;font-size:0.875rem;color:#374151;resize:none;outline:none;font-family:inherit;background:white;box-sizing:border-box;"
      ></textarea>
      {#if commentText.trim()}
      <div style="display:flex;justify-content:flex-end;margin-top:8px;">
        <button
          on:click={postComment}
          style="background:#2563eb;color:white;border:none;border-radius:6px;padding:6px 16px;font-size:0.8125rem;font-weight:600;cursor:pointer;"
        >
          Post
        </button>
      </div>
      {/if}
    </div>
  </div>
</div>
{/if}
