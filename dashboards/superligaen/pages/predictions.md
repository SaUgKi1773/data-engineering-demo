---
sidebar: never
hide_toc: true
title: Prediction Module
---

<script>
  const teamPalette = ['#3b82f6','#ef4444','#22c55e','#f59e0b','#8b5cf6','#ec4899','#14b8a6','#f97316','#6366f1','#84cc16','#06b6d4','#a855f7'];
  let raceGroup = null;
  function toggleRaceGroup(g) { raceGroup = raceGroup === g ? null : g; }
</script>

```sql seasons
select season from (
  select season, max(is_current_season::int) as is_current
  from superligaen.mart_prediction_facts
  where match_id is not null
  group by season
)
order by is_current desc, season desc
```

```sql teams
select team_name from (
  select 'All Teams' as team_name, 0 as ord
  union all
  select distinct team_name, 1 as ord
  from superligaen.mart_prediction_facts
  where match_id is not null
    and season = '${inputs.season.value}'
) order by ord, team_name
```

```sql cards
with rows as (
    select *,
        predicted_goals_scored
            + case when 'All Teams' in ${inputs.team.value} then predicted_goals_conceded else 0 end as pred_goals,
        goals_scored
            + case when 'All Teams' in ${inputs.team.value} then goals_conceded else 0 end as act_goals
    from superligaen.mart_prediction_facts
    where match_id is not null
      and season = '${inputs.season.value}'
      and case when 'All Teams' in ${inputs.team.value}
               then team_side = 'Home'
               else team_name in ${inputs.team.value} end
)
select
    count(*) filter (is_scored)::int                                    as matches_scored,
    coalesce(sum(hit::int), 0)::int                                     as correct_picks,
    round(avg(hit::int) * 100, 1)                                       as hit_pct,
    round(sum(pred_goals) filter (is_scored), 1)                        as pred_goals_total,
    coalesce(sum(act_goals) filter (is_scored), 0)::int                 as act_goals_total,
    round(avg((abs(pred_goals - act_goals) <= 1)::int)
          filter (is_scored) * 100, 1)                                  as goals_within1_pct,
    round(avg(abs(pred_goals - act_goals)) filter (is_scored), 1)       as avg_goal_miss,
    count(*) filter (not is_scored)::int                                as pending_predictions,
    strftime(min(match_date) filter (not is_scored), '%d %B %Y')        as first_kickoff
from rows
```

```sql leader_card
-- League-wide by design: a "leader" only exists at league level, so this card
-- ignores the team filter, like the official table would.
with totals as (
    select
        team_short_name,
        coalesce(sum(points_earned), 0)
            + coalesce(sum(predicted_points) filter (not is_scored), 0)          as expected_total,
        coalesce(sum(goals_scored - goals_conceded) filter (is_scored), 0)
            + coalesce(sum(predicted_goals_scored - predicted_goals_conceded)
                       filter (not is_scored), 0)                                as expected_gd,
        coalesce(sum(goals_scored) filter (is_scored), 0)
            + coalesce(sum(predicted_goals_scored) filter (not is_scored), 0)    as expected_gf
    from superligaen.mart_prediction_facts
    where match_id is not null
      and season = '${inputs.season.value}'
    group by team_short_name
),
ranked as (
    -- standings-style tiebreak: points, goal difference, goals for
    select *, row_number() over (order by expected_total desc, expected_gd desc,
                                          expected_gf desc, team_short_name) as rk
    from totals
)
select
    (select max(round_number) from superligaen.mart_prediction_facts
     where match_id is not null and season = '${inputs.season.value}')        as as_of_round,
    max(case when rk = 1 then team_short_name end)                            as leader,
    round(max(case when rk = 1 then expected_total end), 1)                   as leader_pts,
    round(max(case when rk = 1 then expected_total end)
          - max(case when rk = 2 then expected_total end), 1)                 as lead_margin
from ranked
where rk <= 2
```

```sql race
-- Solid line: actual points only, accumulated over played matches, anchored at
-- (0, 0) so every team starts the race at the origin. Pending fixtures
-- (postponed ones included) never contribute here — they live in the dashed
-- forecast series.
select round, team_name, round_group, cumulative_points, cumulative_gd
from (
    select
        round_number as round,
        team_name,
        standings_type as round_group,
        sum(points_earned) over (partition by team_name order by round_number)::int as cumulative_points,
        sum(goals_scored - goals_conceded)
            over (partition by team_name order by round_number)::int                as cumulative_gd
    from superligaen.mart_prediction_facts
    where match_id is not null
      and is_scored
      and season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} or team_name in ${inputs.team.value})
    union all
    select distinct 0, team_name, standings_type, 0, 0
    from superligaen.mart_prediction_facts
    where match_id is not null
      and season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} or team_name in ${inputs.team.value})
)
order by max(cumulative_points) over (partition by team_name) desc, team_name, round
```

```sql race_forecast
-- Dashed line: anchored at each team's last played round with its actual
-- total, then adds predicted points for every pending fixture in round order.
-- A postponed fixture from an earlier round blends into the first forecast
-- segment (never plotted at or before the anchor, which would draw a step).
with rows as (
    select round_number, team_name, standings_type, is_scored, points_earned, predicted_points,
           goals_scored, goals_conceded, predicted_goals_scored, predicted_goals_conceded
    from superligaen.mart_prediction_facts
    where match_id is not null
      and season = '${inputs.season.value}'
      and ('All Teams' in ${inputs.team.value} or team_name in ${inputs.team.value})
),
base as (
    select
        team_name,
        max(standings_type)                                    as round_group,
        coalesce(sum(points_earned), 0)                        as actual_total,
        coalesce(sum(goals_scored - goals_conceded), 0)        as actual_gd,
        coalesce(max(case when is_scored then round_number end), 0) as last_played_round
    from rows
    group by team_name
),
pending as (
    select
        r.team_name,
        b.round_group,
        r.round_number as orig_round,
        greatest(r.round_number, b.last_played_round + 1) as round,
        b.actual_total
            + sum(r.predicted_points) over (partition by r.team_name order by r.round_number) as cum,
        b.actual_gd
            + sum(r.predicted_goals_scored - r.predicted_goals_conceded)
                  over (partition by r.team_name order by r.round_number)                     as cum_gd
    from rows r
    join base b using (team_name)
    where not r.is_scored
)
select team_name, round_group, round,
       round(max_by(cum,    orig_round), 1) as cumulative_points,
       round(max_by(cum_gd, orig_round), 1) as cumulative_gd
from pending
group by team_name, round_group, round
union all
select team_name, round_group, last_played_round as round,
       actual_total::decimal(10,1) as cumulative_points,
       actual_gd::decimal(10,1)    as cumulative_gd
from base
order by team_name, round
```

```sql upcoming
select
    strftime(match_date, '%Y-%m-%d')        as "Date",
    round_name                              as "Round",
    team_short_name || ' - ' || opponent_team_short_name as "Match",
    round(win_probability  * 100)::int      as "Home %",
    round(draw_probability * 100)::int      as "Draw %",
    round(loss_probability * 100)::int      as "Away %",
    case model_pick
        when 'Win'  then team_short_name
        when 'Loss' then opponent_team_short_name
        else 'Draw'
    end                                     as "Model Pick",
    printf('%.1f – %.1f', predicted_goals_scored, predicted_goals_conceded) as "Predicted Goals"
from superligaen.mart_prediction_facts
where match_id is not null
  and not is_scored
  and team_side = 'Home'
  and season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value}
       or team_name in ${inputs.team.value}
       or opponent_team_name in ${inputs.team.value})
order by match_date asc
```

```sql rounds_record
select
    round_number                                     as round,
    case when hit then 'Correct' else 'Missed' end   as outcome,
    count(*)::int                                    as picks
from superligaen.mart_prediction_facts
where match_id is not null
  and is_scored
  and team_side = 'Home'
  and season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value}
       or team_name in ${inputs.team.value}
       or opponent_team_name in ${inputs.team.value})
group by round_number, outcome
order by round_number, outcome
```

```sql log
select
    strftime(match_date, '%Y-%m-%d')        as "Date",
    round_name                              as "Round",
    team_short_name || ' - ' || opponent_team_short_name as "Match",
    coalesce(score, '–')                    as "Score",
    printf('%.1f – %.1f', predicted_goals_scored, predicted_goals_conceded) as "Predicted Goals",
    round(win_probability  * 100)::int      as "Home %",
    round(draw_probability * 100)::int      as "Draw %",
    round(loss_probability * 100)::int      as "Away %",
    case model_pick
        when 'Win'  then team_short_name
        when 'Loss' then opponent_team_short_name
        else 'Draw'
    end                                     as "Model Pick",
    case actual_result
        when 'Win'  then team_short_name
        when 'Loss' then opponent_team_short_name
        else 'Draw'
    end                                     as "Result",
    case when hit
         then '<span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-green-500 text-white">✓</span>'
         else '<span class="inline-flex items-center justify-center w-6 h-5 text-xs font-bold rounded bg-red-500 text-white">✗</span>'
    end                                     as "Hit"
from superligaen.mart_prediction_facts
where match_id is not null
  and is_scored
  and team_side = 'Home'
  and season = '${inputs.season.value}'
  and ('All Teams' in ${inputs.team.value}
       or team_name in ${inputs.team.value}
       or opponent_team_name in ${inputs.team.value})
order by match_date desc
```

<p style="font-size:0.8125rem;color:#6b7280;margin:0 0 1.5rem 0;">Before every fixture, our data science team's match model publishes win, draw and loss probabilities. This page looks forward — what the model expects next — and keeps the receipts: every prediction is frozen before kickoff, never edited afterwards, and scored against what actually happened.</p>

<div class="flex flex-wrap gap-3 items-end mb-6">
  {#key seasons[0]?.season}
  <Dropdown data={seasons} name=season value=season label=season order="season desc" defaultValue={seasons[0]?.season} title="Season" />
  {/key}
  {#key inputs.season.value}
  <Dropdown data={teams} name=team value=team_name label=team_name multiple=true defaultValue={['All Teams']} title="Team" />
  {/key}
</div>

<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
  <div class="rounded-xl border border-gray-200 bg-white p-4">
    <div class="text-xs text-gray-400 font-semibold uppercase tracking-wide">Completed Match Prediction</div>
    <div class="text-3xl font-black text-gray-800 my-2 text-center">{cards[0].matches_scored}</div>
    <div class="flex justify-between text-xs mt-3">
      <span class="text-gray-500">Correct picks: <span class="font-bold text-gray-700">{cards[0].correct_picks}</span></span>
      <span class="text-gray-500">Success rate: <span class="font-bold {cards[0].hit_pct == null ? 'text-gray-700' : cards[0].hit_pct >= 50 ? 'text-green-600' : cards[0].hit_pct >= 40 ? 'text-amber-600' : 'text-red-600'}">{cards[0].hit_pct == null ? '–' : cards[0].hit_pct + '%'}</span></span>
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4">
    <div class="text-xs text-gray-400 font-semibold uppercase tracking-wide">Goals · Predicted vs Actual</div>
    <div class="text-3xl font-black text-gray-800 my-2 text-center">{cards[0].pred_goals_total ?? '–'} <span class="text-gray-300 text-xl">/</span> {cards[0].act_goals_total}</div>
    <div class="flex justify-between text-xs mt-3">
      <span class="text-gray-500">Avg. miss: <span class="font-bold {cards[0].avg_goal_miss == null ? 'text-gray-700' : cards[0].avg_goal_miss <= 0.8 ? 'text-green-600' : cards[0].avg_goal_miss <= 1.2 ? 'text-amber-600' : 'text-red-600'}">{cards[0].avg_goal_miss == null ? '–' : cards[0].avg_goal_miss + ' goals'}</span></span>
      <span class="text-gray-500">Within ±1 goal: <span class="font-bold {cards[0].goals_within1_pct == null ? 'text-gray-700' : cards[0].goals_within1_pct >= 65 ? 'text-green-600' : cards[0].goals_within1_pct >= 50 ? 'text-amber-600' : 'text-red-600'}">{cards[0].goals_within1_pct == null ? '–' : cards[0].goals_within1_pct + '%'}</span></span>
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4">
    <div class="text-xs text-gray-400 font-semibold uppercase tracking-wide">Predicted Leader · Round {leader_card[0].as_of_round}</div>
    <div class="text-2xl font-black text-gray-800 my-2 text-center leading-9">{leader_card[0]?.leader ?? '–'}</div>
    <div class="flex justify-between text-xs mt-3">
      <span class="text-gray-500">Expected points: <span class="font-bold text-gray-700">{leader_card[0]?.leader_pts == null ? '–' : '~' + leader_card[0].leader_pts}</span></span>
      <span class="text-gray-500">Lead over 2nd: <span class="font-bold text-gray-700">{leader_card[0]?.lead_margin == null ? '–' : '+' + leader_card[0].lead_margin}</span></span>
    </div>
  </div>
  <div class="rounded-xl border border-gray-200 bg-white p-4">
    <div class="text-xs text-gray-400 font-semibold uppercase tracking-wide">Predictions on the Books</div>
    <div class="text-3xl font-black text-gray-800 my-2 text-center">{cards[0].pending_predictions}</div>
    <div class="flex justify-between text-xs mt-3">
      <span class="text-gray-500">Next kickoff: <span class="font-bold text-gray-700">{cards[0].first_kickoff ?? '–'}</span></span>
    </div>
  </div>
</div>

### The Points Race — Played & Forecast

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Cumulative points round by round: solid lines are real results, dashed lines are the model's frozen predictions for the fixtures still to come. Hover a round to see the full ranking.</p>

<div style="display:flex;flex-wrap:wrap;gap:1.25rem;align-items:center;font-size:0.75rem;color:#6b7280;margin:0 0 0.5rem 0;">
  <span style="display:inline-flex;align-items:center;gap:6px;"><span style="display:inline-block;width:24px;border-top:2px solid #6b7280;"></span>Played</span>
  <span style="display:inline-flex;align-items:center;gap:6px;"><span style="display:inline-block;width:24px;border-top:2px dashed #6b7280;"></span>Forecast</span>
  {#if race.some(r => r.round_group === 'Championship Group' || r.round_group === 'Relegation Group')}
  <span role="button" tabindex="0" on:click={() => toggleRaceGroup('Championship Group')} on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && toggleRaceGroup('Championship Group')}
        style="display:inline-flex;align-items:center;gap:6px;cursor:pointer;user-select:none;
               opacity:{raceGroup === null || raceGroup === 'Championship Group' ? 1 : 0.35};
               font-weight:{raceGroup === 'Championship Group' ? 700 : 400};">
    <span style="display:inline-block;width:24px;border-top:3.5px solid #6b7280;"></span>Championship Group</span>
  <span role="button" tabindex="0" on:click={() => toggleRaceGroup('Relegation Group')} on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && toggleRaceGroup('Relegation Group')}
        style="display:inline-flex;align-items:center;gap:6px;cursor:pointer;user-select:none;
               opacity:{raceGroup === null || raceGroup === 'Relegation Group' ? 1 : 0.35};
               font-weight:{raceGroup === 'Relegation Group' ? 700 : 400};">
    <span style="display:inline-block;width:24px;border-top:1.25px solid #9ca3af;"></span>Relegation Group</span>
  {/if}
</div>

<LineChart
    data={race}
    emptySet=pass
    emptyMessage="No predictions for this season yet"
    x=round
    y=cumulative_points
    series=team_name
    xAxisTitle="Round"
    yAxisTitle="Cumulative Points"
    colorPalette={teamPalette}
    echartsOptions={{tooltip: {formatter: (function() { const grpOf = {}; for (const r of race) grpOf[r.team_name] = r.round_group; for (const r of race_forecast) if (!(r.team_name in grpOf)) grpOf[r.team_name] = r.round_group; const hasGroups = Object.values(grpOf).some(g => g === 'Championship Group' || g === 'Relegation Group'); const gdOf = {}; for (const r of race) gdOf[r.team_name + '|' + r.round] = Number(r.cumulative_gd); for (const r of race_forecast) { const k = r.team_name + '|' + r.round; if (!(k in gdOf)) gdOf[k] = Number(r.cumulative_gd); } return function(params) { const seen = new Set(); const uniq = params.filter(p => { const nm = p.seriesName.replace(' (forecast)', ''); if (p.value == null || p.value[1] == null || seen.has(nm)) return false; if (hasGroups && raceGroup !== null && grpOf[nm] !== raceGroup) return false; seen.add(nm); return true; }); if (uniq.length === 0) return ''; const round = uniq[0].value[0]; const gd = (p) => gdOf[p.seriesName.replace(' (forecast)', '') + '|' + p.value[0]] ?? 0; const sorted = [...uniq].sort((a, b) => (b.value[1] - a.value[1]) || (gd(b) - gd(a))); let out = '<span style="font-weight:600;">Round ' + round + '</span>'; for (const p of sorted) { const isFc = p.seriesName.includes(' (forecast)'); out += '<br><span style="font-size:11px;">' + p.marker + ' ' + p.seriesName.replace(' (forecast)', '') + '</span><span style="float:right;margin-left:10px;font-size:12px;' + (isFc ? 'font-style:italic;color:#9ca3af;' : '') + '">' + (isFc ? '~' : '') + p.value[1] + '</span>'; } return out; }; })()}, series: (function() { const grpOf = {}; for (const r of race) grpOf[r.team_name] = r.round_group; for (const r of race_forecast) if (!(r.team_name in grpOf)) grpOf[r.team_name] = r.round_group; const hasGroups = Object.values(grpOf).some(g => g === 'Championship Group' || g === 'Relegation Group'); const widthOf = (t) => !hasGroups ? 2 : (grpOf[t] === 'Championship Group' ? 3.5 : 1.25); const hiddenOf = (t) => hasGroups && raceGroup !== null && grpOf[t] !== raceGroup; const solidTeams = [...new Set(race.map(r => r.team_name))]; const fcTeams = [...new Set(race_forecast.map(r => r.team_name))]; const allTeams = [...solidTeams]; for (const t of fcTeams) if (!allTeams.includes(t)) allTeams.push(t); const colorOf = {}; allTeams.forEach((t, i) => { colorOf[t] = teamPalette[i % teamPalette.length]; }); const byTeam = {}; for (const r of race_forecast) { (byTeam[r.team_name] = byTeam[r.team_name] || []).push([Number(r.round), Number(r.cumulative_points)]); } const base = solidTeams.map(t => { const cfg = {lineStyle: {width: widthOf(t)}}; if (hiddenOf(t)) cfg.data = []; return cfg; }); const fc = fcTeams.map(t => ({name: t + ' (forecast)', type: 'line', showSymbol: false, color: colorOf[t], lineStyle: {type: 'dashed', width: widthOf(t)}, data: hiddenOf(t) ? [] : byTeam[t]})); return base.concat(fc); })()}}
    legend=false
    chartAreaHeight=300
/>

### Next Predictions

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every fixture currently on the books. Predicted goals are the model's expected goals for each side — 1.7 is a real expectation, even if no one ever scores 0.7 of a goal.</p>

<DataTable data={upcoming} rows=10 search=true emptySet=pass emptyMessage="No predictions on the books right now">
    <Column id="Date"            />
    <Column id="Round"           align=center />
    <Column id="Match"           />
    <Column id="Home %"          align=center />
    <Column id="Draw %"          align=center />
    <Column id="Away %"          align=center />
    <Column id="Model Pick"      align=center />
    <Column id="Predicted Goals" align=center />
</DataTable>

## The Track Record

### The Round-by-Round Record

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">Every round's predictions, split into picks that landed and picks that missed — the season's form guide for the model itself.</p>

<BarChart
    data={rounds_record}
    emptySet=pass
    emptyMessage="No predictions scored yet"
    x=round
    y=picks
    series=outcome
    type=stacked
    seriesColors={{'Correct': '#22c55e', 'Missed': '#ef4444'}}
    xAxisTitle="Round"
    yAxisTitle="Predictions"
    chartAreaHeight=280
/>

### Every Prediction, Scored

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1rem 0;font-style:italic;">The full record — every fixture the model predicted before kickoff and how it turned out, scoreline expectations included. Nothing is removed or restated.</p>

<DataTable data={log} rows=15 search=true emptySet=pass emptyMessage="No predictions scored yet — the first verdicts land after the opening fixtures">
    <Column id="Date"            />
    <Column id="Round"           align=center />
    <Column id="Match"           />
    <Column id="Score"           align=center />
    <Column id="Predicted Goals" align=center />
    <Column id="Home %"          align=center />
    <Column id="Draw %"          align=center />
    <Column id="Away %"          align=center />
    <Column id="Model Pick"      align=center />
    <Column id="Result"          align=center />
    <Column id="Hit"             contentType=html align=center />
</DataTable>

<p style="font-size:0.6875rem;color:#9ca3af;margin:2rem 0 0 0;">How it works: probabilities come from a Poisson goals model fitted on the last two seasons of results. Predictions refresh nightly until three hours before kickoff, then freeze — nothing is ever predicted or revised after a match has started. The model's pick is its highest-probability outcome; a hit means that outcome happened. Points expected by the model are 3 × win probability + 1 × draw probability. With a team selected, the goals card compares that team's own goals to the model's expectation; on All Teams it compares full-match totals.</p>
