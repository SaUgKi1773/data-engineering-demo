<script>
  export let events = [];      // one row per event, chronological
  export let home_team = '';
  export let away_team = '';

  function icon(e) {
    const g = e.event_group, t = e.event_type_name || '';
    if (g === 'Goal') return '⚽';
    if (g === 'Card') return t.includes('Red') ? '🟥' : '🟨';
    if (g === 'Substitution') return '🔄';
    if (g === 'VAR') return '📺';
    return '•';
  }
  function label(e) {
    const g = e.event_group, s = (e.event_sub_type_name || '').toLowerCase();
    if (g === 'Goal') {
      if (s.includes('penalty')) return 'Goal (pen)';
      if (s.includes('own')) return 'Own goal';
      return 'Goal';
    }
    if (g === 'Card') return e.event_type_name;
    if (g === 'Substitution') return 'Substituted on';
    if (g === 'VAR') return (e.event_sub_type_name && e.event_sub_type_name !== 'Unspecified')
      ? 'VAR — ' + e.event_sub_type_name : 'VAR review';
    return e.event_type_name;
  }
  const isGoal = (e) => e.event_group === 'Goal';
  // Surname only — used on mobile so long names don't get ellipsis-trimmed.
  function shortName(n) {
    if (!n) return n;
    const p = String(n).trim().split(/\s+/);
    return p.length > 1 ? p[p.length - 1] : n;
  }

  // Insert a period divider (e.g. Half-time) whenever the period changes.
  $: rows = (() => {
    const out = [];
    let prev = null;
    for (const e of events) {
      if (prev && e.period_name !== prev) {
        out.push({ divider: prev === 'First Half' ? 'Half-time' : e.period_name });
      }
      out.push(e);
      prev = e.period_name;
    }
    return out;
  })();
</script>

<div class="tl">
  {#if events.length === 0}
    <div class="empty">No timeline events recorded for this match.</div>
  {:else}
    <div class="head">
      <div class="th home">{home_team}</div>
      <div class="th mid">&nbsp;</div>
      <div class="th away">{away_team}</div>
    </div>
    {#each rows as r}
      {#if r.divider}
        <div class="divider"><span>{r.divider}</span></div>
      {:else}
        <div class="row">
          <div class="side home">
            {#if r.team_side === 'Home'}
              <div class="chip home {isGoal(r) ? 'goal' : ''}">
                <div class="txt">
                  <div class="name"><span class="nm-full">{r.player_name || label(r)}</span><span class="nm-short">{shortName(r.player_name) || label(r)}</span></div>
                  <div class="det">{label(r)}{#if isGoal(r)} · <b>{r.home_score}–{r.away_score}</b>{/if}</div>
                </div>
                <span class="ic">{icon(r)}</span>
              </div>
            {/if}
          </div>
          <div class="mid"><span class="min">{r.minute_label}'</span></div>
          <div class="side away">
            {#if r.team_side === 'Away'}
              <div class="chip away {isGoal(r) ? 'goal' : ''}">
                <span class="ic">{icon(r)}</span>
                <div class="txt">
                  <div class="name"><span class="nm-full">{r.player_name || label(r)}</span><span class="nm-short">{shortName(r.player_name) || label(r)}</span></div>
                  <div class="det">{label(r)}{#if isGoal(r)} · <b>{r.home_score}–{r.away_score}</b>{/if}</div>
                </div>
              </div>
            {/if}
          </div>
        </div>
      {/if}
    {/each}
  {/if}
</div>

<style>
  .tl { border:1px solid #e5e7eb; border-radius:12px; background:white; padding:10px 6px 14px; }
  .empty { text-align:center; color:#9ca3af; font-size:0.875rem; padding:24px; }
  .head { display:grid; grid-template-columns:minmax(0,1fr) 52px minmax(0,1fr); align-items:center; padding-bottom:8px; margin-bottom:4px; border-bottom:1px solid #f3f4f6; }
  .th { font-size:0.8125rem; font-weight:700; }
  .th.home { text-align:right; color:#2563eb; }
  .th.away { text-align:left;  color:#f97316; }
  .row { display:grid; grid-template-columns:minmax(0,1fr) 52px minmax(0,1fr); align-items:center; }
  .side { display:flex; padding:4px 6px; }
  .side.home { justify-content:flex-end; }
  .side.away { justify-content:flex-start; }
  .mid { position:relative; align-self:stretch; display:flex; align-items:center; justify-content:center; }
  .mid::before { content:''; position:absolute; left:50%; top:0; bottom:0; width:2px; background:#e5e7eb; transform:translateX(-50%); }
  .min { position:relative; z-index:1; background:#f9fafb; border:1px solid #e5e7eb; color:#6b7280; font-size:0.6875rem; font-weight:700; border-radius:9999px; padding:2px 6px; min-width:28px; text-align:center; }
  .chip { display:flex; align-items:center; gap:8px; max-width:100%; }
  .chip.home { text-align:right; }
  .ic { font-size:1.05rem; line-height:1; flex-shrink:0; }
  .txt { min-width:0; }
  .name { font-size:0.8125rem; font-weight:700; color:#111827; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .nm-short { display:none; }
  .det { font-size:0.6875rem; color:#9ca3af; }
  .chip.goal { border-radius:8px; padding:4px 10px; }
  .chip.home.goal { background:#eff6ff; border:1px solid #dbeafe; }
  .chip.away.goal { background:#fff7ed; border:1px solid #fed7aa; }
  .divider { display:flex; align-items:center; justify-content:center; margin:8px 0; }
  .divider span { font-size:0.6875rem; font-weight:700; text-transform:uppercase; letter-spacing:0.05em; color:#9ca3af; background:#f3f4f6; border-radius:9999px; padding:3px 12px; }

  @media (max-width: 640px) {
    .head, .row { grid-template-columns:minmax(0,1fr) 40px minmax(0,1fr); }
    .side { padding:4px 2px; }
    .chip { gap:6px; }
    .ic { font-size:0.95rem; }
    .name { font-size:0.75rem; }
    .det { font-size:0.625rem; }
    .min { min-width:24px; font-size:0.625rem; padding:2px 4px; }
    .th { font-size:0.75rem; }
    .nm-full { display:none; }
    .nm-short { display:inline; }
  }
</style>
