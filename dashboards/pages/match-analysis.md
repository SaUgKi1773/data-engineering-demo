---
sidebar: never
hide_toc: true
title: Match Analysis
---

<script>
  import MatchLineup from '../../components/MatchLineup.svelte';
  import { getInputContext } from '@evidence-dev/sdk/utils/svelte';

  const pageInputs = getInputContext();

  onMount(() => {
    const sp = new URLSearchParams(window.location.search);
    const m = sp.get('match');
    if (!m) return;
    pageInputs.update(($i) => ({
      ...$i,
      match: { value: m, label: m, rawValues: [{ value: m, label: m, selected: true }] }
    }));
  });

  let commentText = '';
  let userComments = [];

  $: matchKey = inputs?.match?.value ? `fanforum_${inputs.match.value}` : null;

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

  const personaColors = {
    'Søren':   { bg: '#dbeafe', text: '#1d4ed8' },
    'Flemming': { bg: '#dcfce7', text: '#15803d' },
    'Rasmus':  { bg: '#ede9fe', text: '#6d28d9' },
    'Maja':    { bg: '#fce7f3', text: '#be185d' },
  };
  function avatarStyle(name) {
    const c = personaColors[name] ?? { bg: '#f3f4f6', text: '#374151' };
    return `background:${c.bg};color:${c.text};`;
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

```sql mc
select *
from superligaen.mart_match_results
where match_id = cast('${inputs.match.value}' as bigint)
```

```sql discussions
select persona_name, sort_order, message
from superligaen.llm_round_discussions
where match_id = cast('${inputs.match.value}' as bigint)
order by sort_order
```

```sql lineup
select *
from superligaen.mart_match_lineup
where match_id = cast('${inputs.match.value}' as bigint)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Starter'
order by team_side desc, position_group, position_name
```

```sql subs
select *
from superligaen.mart_match_lineup
where match_id = cast('${inputs.match.value}' as bigint)
  and result in ('Win', 'Draw', 'Loss')
  and appearance_type = 'Substitute'
order by team_side desc, position_group, position_name
```

<a href="/match-results" style="display:inline-flex;align-items:center;gap:6px;font-size:0.8125rem;font-weight:600;color:#6b7280;text-decoration:none;margin-bottom:16px;">← Match Results</a>

## Head-to-Head

{#if mc.length > 0}
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
{:else}
<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2 text-center text-gray-400 text-sm">
  Loading match data…
</div>
{/if}

---

## Lineup

<p style="font-size:13px;color:#6b7280;margin:-8px 0 16px;">Click on a player to see their stats for this match.</p>

{#if lineup.length > 0}
<MatchLineup {lineup} {subs} home_team={mc[0]?.home_team} away_team={mc[0]?.away_team} score={mc[0]?.score} />
{:else}
<div class="rounded-xl border border-gray-200 bg-white p-6 mt-2 text-center text-gray-400 text-sm">
  Loading lineup…
</div>
{/if}

---

<div style="display:flex;align-items:baseline;gap:10px;margin-bottom:4px;">
  <h2 style="margin:0;">Fan Forum</h2>
  {#if discussions.length + userComments.length > 0}
  <span style="font-size:0.8125rem;color:#6b7280;">{discussions.length + userComments.length} comments</span>
  {/if}
</div>

<p style="font-size:0.8125rem;color:#6b7280;margin:0 0 20px;font-style:italic;">Fan reactions to this match. Drop your take below.</p>

<div style="display:flex;flex-direction:column;gap:0;margin-bottom:32px;border:1px solid #e5e7eb;border-radius:12px;overflow:hidden;">
  {#each discussions as post}
  <div style="display:flex;gap:12px;padding:16px 20px;background:white;border-bottom:1px solid #f3f4f6;">
    <div style="flex-shrink:0;width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:0.8125rem;font-weight:700;{avatarStyle(post.persona_name)}">
      {post.persona_name[0]}
    </div>
    <div style="flex:1;min-width:0;">
      <div style="display:flex;align-items:baseline;gap:8px;margin-bottom:6px;">
        <span style="font-size:0.8125rem;font-weight:700;color:#111827;">{post.persona_name}</span>
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
