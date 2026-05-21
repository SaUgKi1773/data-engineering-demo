---
sidebar: never
hide_toc: true
title: Player Intelligence
---

<script>
  import TeamRadar from '../../components/TeamRadar.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';

  const evidenceInputs = getInputContext();
  let clickedPlayer = null;
  let pendingScrollToDeepDive = false;
  let showBackLink = false;

  $: if (top_players?.length > 0 && pendingScrollToDeepDive) {
    pendingScrollToDeepDive = false;
    requestAnimationFrame(() => {
      const el = document.getElementById('player-deep-dive');
      const navHeight = (document.querySelector('header')?.offsetHeight ?? 64) + 16;
      if (el) window.scrollTo({ top: el.getBoundingClientRect().top + window.scrollY - navHeight, behavior: 'instant' });
    });
  }

  onMount(() => {
    const pending = sessionStorage.getItem('pendingPlayer');
    if (pending) {
      sessionStorage.removeItem('pendingPlayer');
      evidenceInputs.update(i => ({
        ...i,
        player: { label: pending, value: pending, rawValues: [{ label: pending, value: pending, selected: true }] }
      }));
      clickedPlayer = pending;
      pendingScrollToDeepDive = true;
    }
    if (sessionStorage.getItem('cameFrom') === 'match-results') {
      sessionStorage.removeItem('cameFrom');
      showBackLink = true;
    }
  });

  const cardTheme = {
    'Top Rated':    { emoji: '⭐', label: 'group-hover:text-amber-500',   border: 'hover:border-amber-300',   photo: 'group-hover:border-amber-200',   name: 'group-hover:text-amber-700',   stat: 'group-hover:text-amber-600'   },
    'Top Scorer':   { emoji: '⚽', label: 'group-hover:text-red-500',     border: 'hover:border-red-300',     photo: 'group-hover:border-red-200',     name: 'group-hover:text-red-700',     stat: 'group-hover:text-red-600'     },
    'Top Assister': { emoji: '🎯', label: 'group-hover:text-blue-500',    border: 'hover:border-blue-300',    photo: 'group-hover:border-blue-200',    name: 'group-hover:text-blue-700',    stat: 'group-hover:text-blue-600'    },
    'Top Creator':  { emoji: '✨', label: 'group-hover:text-emerald-500', border: 'hover:border-emerald-300', photo: 'group-hover:border-emerald-200', name: 'group-hover:text-emerald-700', stat: 'group-hover:text-emerald-600' },
    'Top Dribbler': { emoji: '💨', label: 'group-hover:text-violet-500',  border: 'hover:border-violet-300',  photo: 'group-hover:border-violet-200',  name: 'group-hover:text-violet-700',  stat: 'group-hover:text-violet-600'  },
    'Top Defender': { emoji: '🛡️', label: 'group-hover:text-sky-500',     border: 'hover:border-sky-300',     photo: 'group-hover:border-sky-200',     name: 'group-hover:text-sky-700',     stat: 'group-hover:text-sky-600'     },
  };

  function goToPlayer(name) {
    evidenceInputs.update(i => ({
      ...i,
      player: { label: name, value: name, rawValues: [{ label: name, value: name, selected: true }] }
    }));
    clickedPlayer = name;
    setTimeout(() => {
      const el = document.getElementById('player-deep-dive');
      const navHeight = (document.querySelector('header')?.offsetHeight ?? 64) + 16;
      if (el) window.scrollTo({ top: el.getBoundingClientRect().top + window.scrollY - navHeight, behavior: 'smooth' });
    }, 100);
  }

  const playerMetrics = [
    { key: 'attacking_pct',   label: 'Attacking'   },
    { key: 'creativity_pct',  label: 'Creativity'  },
    { key: 'possession_pct',  label: 'Possession'  },
    { key: 'defending_pct',   label: 'Defending'   },
    { key: 'physicality_pct', label: 'Physicality' },
    { key: 'impact_pct',      label: 'Impact'      },
  ];
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_player_facts
  where result in ('Win', 'Draw', 'Loss')
  group by season
) order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from superligaen.mart_player_facts
  where season = '${inputs.season.value}'
    and result in ('Win', 'Draw', 'Loss')
) order by ord, team_name
```

```sql positions
select player_position from (
  select 'All' as player_position, 0 as ord
  union all
  select distinct player_position, 1 as ord
  from superligaen.mart_player_facts
  where season = '${inputs.season.value}'
    and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
    and result in ('Win', 'Draw', 'Loss')
    and player_position is not null
) order by ord, player_position
```

```sql players_in_team
select distinct player_name
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
  and ('All' in ${inputs.position.value} OR player_position in ${inputs.position.value})
  and result in ('Win', 'Draw', 'Loss')
order by player_name
```


```sql top_players
with base as (
    select
        player_name,
        player_photo,
        player_position,
        max(team_name)                                              as team_name,
        max(team_logo)                                             as team_logo,
        count(distinct match_id)                                   as matches,
        sum(goals_scored)                                          as goals,
        sum(assists)                                               as assists,
        sum(dribbles_completed)                                    as dribbles,
        sum(tackles_won) + sum(interceptions) + sum(balls_recovered) as defensive_actions,
        sum(key_passes) + sum(big_chances_created)                 as chances_created,
        round(avg(rating), 2)                                      as avg_rating
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} OR team_name in ${inputs.team.value})
      and result in ('Win', 'Draw', 'Loss')
    group by player_name, player_photo, player_position
    having count(distinct match_id) >= 3
)
select category, player_name, player_photo, player_position, team_name, team_logo, stat_value, stat_label
from (
    select 'Top Scorer'   as category, player_name, player_photo, player_position, team_name, team_logo, goals::int               as stat_value, 'Goals'          as stat_label, row_number() over (order by goals             desc) as rn from base
    union all
    select 'Top Assister',              player_name, player_photo, player_position, team_name, team_logo, assists::int,                'Assists',        row_number() over (order by assists           desc) from base
    union all
    select 'Top Creator',               player_name, player_photo, player_position, team_name, team_logo, chances_created::int,        'KP+BC Created',  row_number() over (order by chances_created   desc) from base
    union all
    select 'Top Defender',              player_name, player_photo, player_position, team_name, team_logo, defensive_actions::int,      'Tkl+Int+Rec',    row_number() over (order by defensive_actions desc) from base
    union all
    select 'Top Dribbler',              player_name, player_photo, player_position, team_name, team_logo, dribbles::int,               'Dribbles',       row_number() over (order by dribbles          desc) from base
    union all
    select 'Top Rated',                 player_name, player_photo, player_position, team_name, team_logo, avg_rating::double,          'Avg Rating',     row_number() over (order by avg_rating        desc) from base where matches >= 5
)
where rn = 1
order by case category
    when 'Top Rated'    then 1
    when 'Top Scorer'   then 2
    when 'Top Assister' then 3
    when 'Top Creator'  then 4
    when 'Top Dribbler' then 5
    when 'Top Defender' then 6
end
```

{#key seasons[0]?.season}
<Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} />
{/key}

{#key teams[0]?.team_name}
<Dropdown data={teams} name=team value=team_name label=team_name multiple=true defaultValue={['All Teams']} />
{/key}

```sql player_profile
select
    player_name,
    player_photo,
    player_nationality,
    player_detailed_position,
    max(player_birth_date)                                                                 as birth_date,
    date_diff('year', max(player_birth_date)::date, current_date)                         as age,
    max(player_height)                                                                     as height,
    max(player_weight)                                                                     as weight,
    team_name,
    team_logo,
    player_position,
    count(distinct match_id)::int                                                         as matches,
    sum(minutes_played)::int                                                              as minutes,
    sum(goals_scored)::int                                                                as goals,
    sum(assists)::int                                                                     as assists,
    sum(shots_total)::int                                                                 as shots,
    sum(shots_on_target)::int                                                             as shots_on_target,
    sum(key_passes)::int                                                                  as key_passes,
    sum(big_chances_created)::int                                                         as big_chances_created,
    sum(chances_created)::int                                                             as chances_created,
    sum(tackles)::int                                                                     as tackles,
    sum(interceptions)::int                                                               as interceptions,
    sum(balls_recovered)::int                                                             as balls_recovered,
    sum(duels_won)::int                                                                   as duels_won,
    sum(duels_total)::int                                                                 as duels_total,
    sum(passes_accurate)::int                                                             as passes_accurate,
    sum(passes_total)::int                                                                as passes_total,
    sum(yellow_cards)::int                                                                as yellow_cards,
    sum(case when appearance_type = 'Starter' then 1 else 0 end)::int                    as starts,
    round(avg(rating), 2)                                                                 as avg_rating,
    round(sum(goals_scored)  * 90.0 / nullif(sum(minutes_played), 0), 2)                 as goals_per90,
    round(sum(assists)       * 90.0 / nullif(sum(minutes_played), 0), 2)                 as assists_per90,
    round((sum(goals_scored) + sum(assists)) * 90.0 / nullif(sum(minutes_played), 0), 2) as contributions_per90,
    round(100.0 * sum(passes_accurate)  / nullif(sum(passes_total), 0), 1)               as pass_accuracy,
    round(100.0 * sum(goals_scored)     / nullif(sum(shots_total),  0), 1)               as shot_conversion,
    round(100.0 * sum(duels_won)        / nullif(sum(duels_total),  0), 1)               as duel_win_pct,
    (sum(tackles) + sum(interceptions) + sum(balls_recovered))::int                      as def_actions,
    sum(case when result = 'Win'  then 1 else 0 end)::int                                as wins,
    sum(case when result = 'Draw' then 1 else 0 end)::int                                as draws,
    sum(case when result = 'Loss' then 1 else 0 end)::int                                as losses
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
group by player_name, player_photo, player_nationality, player_detailed_position, team_name, team_logo, player_position
```

```sql player_trend
select
    match_round_number                                                          as round,
    goals_scored,
    big_chances_created,
    tackles + interceptions                                                     as tkl_int,
    round(100.0 * passes_accurate / nullif(passes_total, 0), 1)                as pass_acc,
    round(100.0 * duels_won       / nullif(duels_total,   0), 1)               as duel_win,
    rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_round_number
```

```sql player_match_log
select
    strftime(match_date, '%Y-%m-%d')              as match_date,
    match_round_name                              as round,
    opponent_team_name                            as opponent,
    opponent_team_short_name                      as opponent_short,
    team_side                                     as home_away,
    case result
        when 'Win'  then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#22c55e;color:white;border-radius:4px;font-size:12px;font-weight:700;">W</span>'
        when 'Draw' then '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#eab308;color:white;border-radius:4px;font-size:12px;font-weight:700;">D</span>'
        else             '<span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:20px;background:#ef4444;color:white;border-radius:4px;font-size:12px;font-weight:700;">L</span>'
    end                                           as result_badge,
    -- Attacking
    goals_scored                                                                    as goals,
    assists,
    shots_on_target,
    round(100.0 * goals_scored / nullif(shots_total, 0), 1)                         as shot_conv,
    woodwork_hits,
    -- Creativity
    big_chances_created,
    chances_created,
    key_passes,
    round(100.0 * crosses_accurate / nullif(crosses_total, 0), 1)                   as cross_acc,
    passes_final_third,
    -- Possession
    round(100.0 * passes_accurate / nullif(passes_total, 0), 1)                     as pass_acc,
    round(100.0 * dribbles_completed / nullif(dribbles_attempts, 0), 1)             as dribble_success,
    round(100.0 * long_balls_won / nullif(long_balls, 0), 1)                        as long_ball_success,
    -- Defending
    tackles + interceptions                                                          as tkl_int,
    round(100.0 * tackles_won / nullif(tackles, 0), 1)                              as tackle_success,
    balls_recovered,
    times_dribbled_past,
    errors_leading_to_goal,
    -- Physicality
    round(100.0 * duels_won / nullif(duels_total, 0), 1)                            as duel_win,
    fouls_drawn,
    round(100.0 * aerials_won / nullif(aerials_won + aerials_lost, 0), 1)           as aerial_success,
    -- Impact
    rating
from superligaen.mart_player_facts
where season = '${inputs.season.value}'
  and player_name = '${inputs.player.value}'
  and result in ('Win', 'Draw', 'Loss')
order by match_date desc
```

```sql league_context
with base as (
    select
        player_name,
        -- Attacking
        sum(goals_scored)         * 90.0 / nullif(sum(minutes_played), 0)                           as goals_per90,
        sum(assists)              * 90.0 / nullif(sum(minutes_played), 0)                           as assists_per90,
        sum(shots_on_target)      * 90.0 / nullif(sum(minutes_played), 0)                           as sot_per90,
        100.0 * sum(goals_scored)          / nullif(sum(shots_total), 0)                            as shot_acc_pct,
        sum(woodwork_hits)        * 90.0 / nullif(sum(minutes_played), 0)                           as woodwork_per90,
        -- Creativity
        sum(big_chances_created)  * 90.0 / nullif(sum(minutes_played), 0)                           as big_chances_per90,
        sum(chances_created)      * 90.0 / nullif(sum(minutes_played), 0)                           as chances_per90,
        sum(key_passes)           * 90.0 / nullif(sum(minutes_played), 0)                           as key_passes_per90,
        100.0 * sum(big_chances_created)   / nullif(sum(chances_created), 0)                        as chance_quality_pct,
        100.0 * sum(crosses_accurate)      / nullif(sum(crosses_total), 0)                          as cross_acc_pct,
        sum(passes_final_third)   * 90.0 / nullif(sum(minutes_played), 0)                           as passes_final_third_per90,
        -- Possession
        100.0 * sum(passes_accurate)       / nullif(sum(passes_total), 0)                           as pass_acc_pct,
        100.0 * sum(dribbles_completed)    / nullif(sum(dribbles_attempts), 0)                      as dribble_success_pct,
        100.0 * sum(long_balls_won)        / nullif(sum(long_balls), 0)                             as long_ball_success_pct,
        -- Defending
        (sum(tackles) + sum(interceptions)) * 90.0 / nullif(sum(minutes_played), 0)                as tkl_int_per90,
        100.0 * sum(tackles_won)           / nullif(sum(tackles), 0)                               as tackle_success_pct,
        sum(balls_recovered)      * 90.0 / nullif(sum(minutes_played), 0)                           as balls_recovered_per90,
        sum(times_dribbled_past)  * 90.0 / nullif(sum(minutes_played), 0)                           as times_dribbled_past_per90,
        sum(errors_leading_to_goal) * 90.0 / nullif(sum(minutes_played), 0)                         as errors_per90,
        -- Physicality
        100.0 * sum(duels_won)             / nullif(sum(duels_total), 0)                            as duel_win_pct,
        sum(fouls_drawn)          * 90.0 / nullif(sum(minutes_played), 0)                           as fouls_drawn_per90,
        100.0 * sum(aerials_won)           / nullif(sum(aerials_won) + sum(aerials_lost), 0)        as aerial_success_pct,
        -- Impact
        avg(rating)                                                                                  as avg_rating
    from superligaen.mart_player_facts
    where season = '${inputs.season.value}'
      and result in ('Win', 'Draw', 'Loss')
    group by player_name
    having sum(minutes_played) >= 450
),
ranked as (
    select
        player_name,
        -- Attacking: anchor goals/90 (2×), + assists/90, sot/90, shot_acc%, woodwork/90 → /6
        round((2 * percent_rank() over (order by goals_per90)
                 + percent_rank() over (order by assists_per90)
                 + percent_rank() over (order by sot_per90)
                 + percent_rank() over (order by shot_acc_pct)
                 + percent_rank() over (order by woodwork_per90)) / 6 * 100)                        as attacking_pct,
        -- Creativity: anchor big_chances/90 (2×), + chances/90, key_passes/90, chance_quality%, cross_acc%, passes_final_third/90 → /7
        round((  percent_rank() over (order by chances_per90)
               + 2 * percent_rank() over (order by big_chances_per90)
               + percent_rank() over (order by key_passes_per90)
               + percent_rank() over (order by chance_quality_pct)
               + percent_rank() over (order by cross_acc_pct)
               + percent_rank() over (order by passes_final_third_per90)) / 7 * 100)               as creativity_pct,
        -- Possession: anchor pass_acc% (2×), + dribble_success%, long_ball_success% → /4
        round((2 * percent_rank() over (order by pass_acc_pct)
                 + percent_rank() over (order by dribble_success_pct)
                 + percent_rank() over (order by long_ball_success_pct)) / 4 * 100)                as possession_pct,
        -- Defending: anchor (tkl+int)/90 (2×), + tackle_success%, balls_recovered/90, times_dribbled_past/90 ↓, errors/90 ↓ → /6
        round((2 * percent_rank() over (order by tkl_int_per90)
                 + percent_rank() over (order by tackle_success_pct)
                 + percent_rank() over (order by balls_recovered_per90)
                 + percent_rank() over (order by times_dribbled_past_per90 desc)
                 + percent_rank() over (order by errors_per90 desc)) / 6 * 100)                    as defending_pct,
        -- Physicality: anchor duel_win% (2×), + fouls_drawn/90, aerial_success% → /4
        round((2 * percent_rank() over (order by duel_win_pct)
                 + percent_rank() over (order by fouls_drawn_per90)
                 + percent_rank() over (order by aerial_success_pct)) / 4 * 100)                   as physicality_pct,
        -- Impact: avg_rating (single)
        round(percent_rank() over (order by avg_rating) * 100)                                     as impact_pct
    from base
)
select * from ranked where player_name = '${inputs.player.value}'
```

---

## Top Players

<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
{#each top_players as tp}
<div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col items-center text-center cursor-pointer {cardTheme[tp.category]?.border} hover:shadow-md transition-all duration-200 group" on:click={() => goToPlayer(tp.player_name)} role="button" tabindex="0" on:keypress={(e) => e.key === 'Enter' && goToPlayer(tp.player_name)}>
  <div class="text-xs font-semibold text-gray-500 uppercase tracking-widest mb-3 transition-colors {cardTheme[tp.category]?.label}">{cardTheme[tp.category]?.emoji} {tp.category}</div>
  <img src="{tp.player_photo}" alt="{tp.player_name}" class="h-16 w-16 rounded-full object-cover mb-3 border-2 border-gray-100 transition-colors {cardTheme[tp.category]?.photo}" onerror="this.style.display='none'" />
  <div class="text-sm font-bold text-gray-900 leading-tight min-h-10 flex items-start justify-center transition-colors {cardTheme[tp.category]?.name}">{tp.player_name}</div>
  <div class="text-xs text-gray-400 mt-1">{tp.player_position}</div>
  <img src="{tp.team_logo}" alt="{tp.team_name}" class="h-7 w-7 object-contain mt-1" onerror="this.style.display='none'" />
  <div class="mt-auto pt-3 text-2xl font-black text-gray-800 transition-colors {cardTheme[tp.category]?.stat}">{tp.stat_value}</div>
  <div class="text-xs text-gray-400">{tp.stat_label}</div>
</div>
{/each}
</div>

---

<div id="player-deep-dive"></div>

{#if showBackLink}
<a href="/match-results" class="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-800 transition-colors mb-4">← Match Results</a>
{/if}

## Player Deep Dive

*Filter by position and team, then select a player to explore their profile, season stats, player characteristics, performance timeline, and match log.*

{#key positions.map(p => p.player_position).join(',')}
<Dropdown data={positions} name=position value=player_position label=player_position multiple=true defaultValue={['All']} />
{/key}

{#key `${clickedPlayer ?? ''}|${players_in_team[0]?.player_name ?? ''}`}
<Dropdown data={players_in_team} name=player value=player_name label=player_name defaultValue={players_in_team[0]?.player_name} />
{/key}

## Player Profile

{#each player_profile as p}
<div class="rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6 md:p-8 mb-6 shadow-xl">
  <div class="flex flex-col md:flex-row items-center md:items-start gap-6">
    <img src="{p.player_photo}" alt="{p.player_name}"
      class="h-28 w-28 rounded-full object-cover border-4 border-white/20 shadow-xl flex-shrink-0"
      onerror="this.style.display='none'" />
    <div class="flex-1 text-center md:text-left">
      <div class="text-3xl md:text-4xl font-extrabold text-white leading-tight">{p.player_name}</div>
      <div class="flex items-center justify-center md:justify-start gap-2 mt-2">
        <img src="{p.team_logo}" alt="{p.team_name}" class="h-5 w-5 object-contain" onerror="this.style.display='none'" />
        <span class="text-gray-300 text-sm">{p.team_name}</span>
        <span class="text-gray-500 text-sm">·</span>
        <span class="text-gray-400 text-sm">{p.player_position}</span>
      </div>
      <div class="text-sm text-gray-400 mt-3">
        {p.player_nationality ?? '—'} · {p.age != null ? p.age + ' yrs' : '—'} · {p.height ? p.height + ' cm' : '—'} · {p.weight ? p.weight + ' kg' : '—'}
      </div>
      <div class="text-xs text-gray-500 mt-1">{p.player_detailed_position ?? p.player_position}</div>
      <div class="flex flex-wrap justify-center md:justify-start gap-3 mt-5">
        {#if p.avg_rating != null}
        <span class="px-3 py-1 rounded-full bg-white/10 text-white text-sm font-bold">★ {p.avg_rating}</span>
        {/if}
        <span class="px-3 py-1 rounded-full bg-green-500/20 text-green-400 text-sm font-bold">{p.wins}W</span>
        <span class="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-sm font-bold">{p.draws}D</span>
        <span class="px-3 py-1 rounded-full bg-red-500/20 text-red-400 text-sm font-bold">{p.losses}L</span>
        <span class="px-3 py-1 rounded-full bg-gray-500/20 text-gray-400 text-sm">{p.minutes} mins</span>
      </div>
    </div>
  </div>
</div>
{/each}

---

## Season Overview

{#each player_profile as p}
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Goals</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.goals}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} shots · {p.shot_conversion != null ? p.shot_conversion + '% conv.' : '—'}</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Assists</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.assists}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.key_passes} key passes · {p.big_chances_created} big chances</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">G+A / 90</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.contributions_per90}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.goals_per90} G · {p.assists_per90} A per 90</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Shots on Target</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.shots_on_target}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.shots} total shots</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Pass Accuracy</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.pass_accuracy != null ? p.pass_accuracy + '%' : '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.passes_accurate} of {p.passes_total} passes</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Duel Win %</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.duel_win_pct != null ? p.duel_win_pct + '%' : '—'}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.duels_total} total duels</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Defensive Actions</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.def_actions}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.tackles} tkl · {p.interceptions} int · {p.balls_recovered} rec</div>
  </div>

  <div class="rounded-xl border border-gray-200 bg-white shadow-sm p-4 flex flex-col">
    <div class="text-xs text-gray-500 text-center mb-2">Appearances</div>
    <div class="text-3xl font-black text-center text-gray-900 flex-1 flex items-center justify-center">{p.matches}</div>
    <div class="text-xs text-gray-400 text-center mt-3">{p.starts} starts</div>
  </div>

</div>
{/each}

---

## Player Characteristics

*Composite percentile score among all players with 450+ minutes in {inputs.season.value}. Each axis combines multiple rate metrics weighted by their importance to that dimension. Higher = better relative to the league.*

{#each league_context as lc}
<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6 items-center">

  <div class="flex flex-col gap-3">

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Attacking</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-amber-400" style="width:{lc.attacking_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.attacking_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Creativity</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-sky-400" style="width:{lc.creativity_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.creativity_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Possession</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-indigo-500" style="width:{lc.possession_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.possession_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Defending</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-teal-500" style="width:{lc.defending_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.defending_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Physicality</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-orange-400" style="width:{lc.physicality_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.physicality_pct}</div>
    </div>

    <div class="flex items-center gap-3">
      <div class="text-xs text-gray-500 w-28 shrink-0 text-right">Impact</div>
      <div class="flex-1 bg-gray-100 rounded-full h-2.5">
        <div class="h-2.5 rounded-full bg-violet-500" style="width:{lc.impact_pct}%"></div>
      </div>
      <div class="text-xs font-bold text-gray-700 w-8 shrink-0 text-right">{lc.impact_pct}</div>
    </div>

  </div>

  <TeamRadar data={league_context} metrics={playerMetrics} />

</div>
{/each}

---

## Performance Timeline

*Select a measure to see how it evolved across rounds. Rating is always shown as the secondary axis.*

```sql timeline_measures
select * from (values
  ('goals_scored',        'Goals'),
  ('big_chances_created', 'Big Chances Created'),
  ('pass_acc',            'Pass Accuracy %'),
  ('tkl_int',             'Tkl + Interceptions'),
  ('duel_win',            'Duel Win %')
) t(value, label)
```

<Dropdown data={timeline_measures} name=measure value=value label=label defaultValue="goals_scored" />

{#if inputs.measure.value === 'goals_scored'}
<BarChart
    data={player_trend}
    x=round
    y=goals_scored
    y2=rating
    y2SeriesType=line
    title="Attacking — Goals per Match"
    xAxisTitle="Round"
    yAxisTitle="Goals"
    y2AxisTitle="Rating"
    colorPalette={['#fbbf24','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'big_chances_created'}
<BarChart
    data={player_trend}
    x=round
    y=big_chances_created
    y2=rating
    y2SeriesType=line
    title="Creativity — Big Chances Created"
    xAxisTitle="Round"
    yAxisTitle="Big Chances"
    y2AxisTitle="Rating"
    colorPalette={['#38bdf8','#94a3b8']}
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'pass_acc'}
<BarChart
    data={player_trend}
    x=round
    y=pass_acc
    y2=rating
    y2SeriesType=line
    title="Possession — Pass Accuracy %"
    xAxisTitle="Round"
    yAxisTitle="Pass Acc %"
    y2AxisTitle="Rating"
    colorPalette={['#6366f1','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'tkl_int'}
<BarChart
    data={player_trend}
    x=round
    y=tkl_int
    y2=rating
    y2SeriesType=line
    title="Defending — Tackles + Interceptions"
    xAxisTitle="Round"
    yAxisTitle="Tkl + Int"
    y2AxisTitle="Rating"
    colorPalette={['#14b8a6','#94a3b8']}
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{:else if inputs.measure.value === 'duel_win'}
<BarChart
    data={player_trend}
    x=round
    y=duel_win
    y2=rating
    y2SeriesType=line
    title="Physicality — Duel Win %"
    xAxisTitle="Round"
    yAxisTitle="Duel Win %"
    y2AxisTitle="Rating"
    colorPalette={['#fb923c','#94a3b8']}
    y2Min=0
    y2Max=10
    echartsOptions={{yAxis: [{minInterval: 1}, {min: 0, max: 10}]}}
/>
{/if}

---

## Match Log

*Use the selectors below to add or remove columns per domain.*

```sql impact_measures
select * from (values
  ('rating', 'Rating')
) t(value, label)
```

```sql attacking_measures
select * from (values
  ('goals',           'Goals'),
  ('assists',         'Assists'),
  ('shots_on_target', 'Shots on Target'),
  ('shot_conv',       'Shot Conv %'),
  ('woodwork_hits',   'Woodwork Hits')
) t(value, label)
```

```sql creativity_measures
select * from (values
  ('big_chances_created', 'Big Chances Created'),
  ('all_chances',         'Chances Created'),
  ('key_passes',          'Key Passes'),
  ('cross_acc',           'Cross Acc %'),
  ('passes_final_third',  'Passes Final Third')
) t(value, label)
```

```sql possession_measures
select * from (values
  ('pass_acc',          'Pass Acc %'),
  ('dribble_success',   'Dribble Success %'),
  ('long_ball_success', 'Long Ball Success %')
) t(value, label)
```

```sql defending_measures
select * from (values
  ('tkl_int',             'Tkl + Int'),
  ('tackle_success',      'Tackle Success %'),
  ('balls_recovered',     'Balls Recovered'),
  ('times_dribbled_past', 'Times Dribbled Past'),
  ('errors_leading_to_goal', 'Errors Leading to Goal')
) t(value, label)
```

```sql physicality_measures
select * from (values
  ('duel_win',       'Duel Win %'),
  ('fouls_drawn',    'Fouls Drawn'),
  ('aerial_success', 'Aerial Success %')
) t(value, label)
```

<div class="grid grid-cols-2 md:grid-cols-3 gap-2 mb-4">
  <Dropdown data={impact_measures}      name=imp value=value label=label multiple=true defaultValue={['rating']}              title="Impact"      />
  <Dropdown data={attacking_measures}   name=atk value=value label=label multiple=true defaultValue={['goals']}               title="Attacking"   />
  <Dropdown data={creativity_measures}  name=cre value=value label=label multiple=true defaultValue={['big_chances_created']} title="Creativity"  />
  <Dropdown data={possession_measures}  name=pos value=value label=label multiple=true defaultValue={['pass_acc']}            title="Possession"  />
  <Dropdown data={defending_measures}   name=def value=value label=label multiple=true defaultValue={['tkl_int']}             title="Defending"   />
  <Dropdown data={physicality_measures} name=phy value=value label=label multiple=true defaultValue={['duel_win']}            title="Physicality" />
</div>

{#key `${inputs.imp.value}|${inputs.atk.value}|${inputs.cre.value}|${inputs.pos.value}|${inputs.def.value}|${inputs.phy.value}`}
<div class="hidden md:block">
<DataTable data={player_match_log} rows=20>
    <Column id=match_date   title="Date"     />
    <Column id=round        title="Round"    />
    <Column id=home_away    title="H/A"      align=center />
    <Column id=opponent     title="Opponent" />
    <Column id=result_badge title="Result"   contentType=html align=center />
    {#if inputs.imp.value?.includes('rating')}
    <Column id=rating              title="Rating"         align=center contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {/if}
    {#if inputs.atk.value?.includes('goals')}
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.cre.value?.includes('big_chances_created')}
    <Column id=big_chances_created title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('all_chances')}
    <Column id=chances_created     title="Chances"        align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('key_passes')}
    <Column id=key_passes          title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('cross_acc')}
    <Column id=cross_acc           title="Cross Acc %"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('passes_final_third')}
    <Column id=passes_final_third  title="Final 3rd Pass" align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.pos.value?.includes('pass_acc')}
    <Column id=pass_acc          title="Pass Acc %"       align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('dribble_success')}
    <Column id=dribble_success   title="Dribble %"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('long_ball_success')}
    <Column id=long_ball_success title="Long Ball %"      align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.def.value?.includes('tkl_int')}
    <Column id=tkl_int             title="Tkl+Int"        align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('tackle_success')}
    <Column id=tackle_success      title="Tackle %"       align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('balls_recovered')}
    <Column id=balls_recovered     title="Balls Rec."     align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('times_dribbled_past')}
    <Column id=times_dribbled_past title="Drib. Past"     align=center />
    {/if}
    {#if inputs.def.value?.includes('errors_leading_to_goal')}
    <Column id=errors_leading_to_goal title="Errors"      align=center />
    {/if}
    {#if inputs.phy.value?.includes('duel_win')}
    <Column id=duel_win       title="Duel Win %"  align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn    title="Fouls Drawn" align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('aerial_success')}
    <Column id=aerial_success title="Aerial %"    align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
</DataTable>
</div>
<div class="block md:hidden">
<DataTable data={player_match_log} rows=20>
    <Column id=match_date      title="Date"     />
    <Column id=opponent_short  title="Opponent" />
    <Column id=result_badge title="Result"   contentType=html align=center />
    {#if inputs.imp.value?.includes('rating')}
    <Column id=rating              title="Rating"         align=center contentType=colorscale colorPalette={['white','#8b5cf6']} />
    {/if}
    {#if inputs.atk.value?.includes('goals')}
    <Column id=goals           title="Goals"       align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('assists')}
    <Column id=assists         title="Assists"     align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shots_on_target')}
    <Column id=shots_on_target title="SoT"         align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('shot_conv')}
    <Column id=shot_conv       title="Shot Conv %"  align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.atk.value?.includes('woodwork_hits')}
    <Column id=woodwork_hits   title="Woodwork"    align=center contentType=colorscale colorPalette={['white','#fbbf24']} />
    {/if}
    {#if inputs.cre.value?.includes('big_chances_created')}
    <Column id=big_chances_created title="Big Chances"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('all_chances')}
    <Column id=chances_created     title="Chances"        align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('key_passes')}
    <Column id=key_passes          title="Key Passes"     align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('cross_acc')}
    <Column id=cross_acc           title="Cross Acc %"    align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.cre.value?.includes('passes_final_third')}
    <Column id=passes_final_third  title="Final 3rd Pass" align=center contentType=colorscale colorPalette={['white','#38bdf8']} />
    {/if}
    {#if inputs.pos.value?.includes('pass_acc')}
    <Column id=pass_acc          title="Pass Acc %"       align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('dribble_success')}
    <Column id=dribble_success   title="Dribble %"        align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.pos.value?.includes('long_ball_success')}
    <Column id=long_ball_success title="Long Ball %"      align=center contentType=colorscale colorPalette={['white','#6366f1']} />
    {/if}
    {#if inputs.def.value?.includes('tkl_int')}
    <Column id=tkl_int             title="Tkl+Int"        align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('tackle_success')}
    <Column id=tackle_success      title="Tackle %"       align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('balls_recovered')}
    <Column id=balls_recovered     title="Balls Rec."     align=center contentType=colorscale colorPalette={['white','#14b8a6']} />
    {/if}
    {#if inputs.def.value?.includes('times_dribbled_past')}
    <Column id=times_dribbled_past title="Drib. Past"     align=center />
    {/if}
    {#if inputs.def.value?.includes('errors_leading_to_goal')}
    <Column id=errors_leading_to_goal title="Errors"      align=center />
    {/if}
    {#if inputs.phy.value?.includes('duel_win')}
    <Column id=duel_win       title="Duel Win %"  align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('fouls_drawn')}
    <Column id=fouls_drawn    title="Fouls Drawn" align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
    {#if inputs.phy.value?.includes('aerial_success')}
    <Column id=aerial_success title="Aerial %"    align=center contentType=colorscale colorPalette={['white','#fb923c']} />
    {/if}
</DataTable>
</div>

{/key}