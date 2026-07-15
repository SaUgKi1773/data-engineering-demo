<script>
  // Paginated story card: shows one slotted paragraph ("chapter") at a time,
  // with chapter tabs, prev/next arrows, and swipe left/right on touch
  // devices. SSR renders all chapters stacked so no-JS visitors (and
  // crawlers) still get the full story; hydration collapses it to the
  // active page.
  import { onMount } from 'svelte';

  export let labels = [];

  let idx = 0;
  let pagesEl;
  let mounted = false;
  let touchX = null;
  let touchY = null;

  function show(i) {
    if (!pagesEl) return;
    [...pagesEl.children].forEach((el, j) => {
      const on = j === i;
      const wasVisible = el.style.visibility === 'visible';
      // explicit 'visible' so the active page overrides the pre-hydration
      // CSS that hides everything but the first chapter; hidden chapters
      // keep their grid cell so the card never changes height
      el.style.visibility = on ? 'visible' : 'hidden';
      if (on && !wasVisible && el.animate) {
        el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 300, easing: 'ease' });
      }
    });
  }

  $: if (mounted) show(idx);

  function go(i) {
    if (!labels.length) return;
    idx = (i + labels.length) % labels.length;
  }

  function onTouchStart(e) {
    touchX = e.touches[0].clientX;
    touchY = e.touches[0].clientY;
  }

  function onTouchEnd(e) {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    const dy = e.changedTouches[0].clientY - touchY;
    touchX = touchY = null;
    // horizontal swipe only: long enough and clearly not a vertical scroll
    if (Math.abs(dx) < 48 || Math.abs(dx) < Math.abs(dy) * 1.5) return;
    const target = idx + (dx < 0 ? 1 : -1);
    if (target >= 0 && target < labels.length) go(target);
  }

  onMount(() => {
    mounted = true;
  });
</script>

<div class="sp-card" on:touchstart={onTouchStart} on:touchend={onTouchEnd}>
  <div class="sp-pages" bind:this={pagesEl}>
    <slot />
  </div>
  <div class="sp-nav">
    <div class="sp-tabs">
      {#each labels as label, i}
        <button class="sp-tab" class:active={i === idx} on:click={() => go(i)}>
          <span class="sp-num">{String(i + 1).padStart(2, '0')}</span>
          {label}
        </button>
      {/each}
    </div>
    <div class="sp-arrows">
      <button class="sp-arrow" aria-label="Previous chapter" on:click={() => go(idx - 1)}>←</button>
      <button class="sp-arrow" aria-label="Next chapter" on:click={() => go(idx + 1)}>→</button>
    </div>
  </div>
</div>

<style>
  .sp-card {
    background: #ffffff;
    border-radius: 1.25rem;
    padding: 1.5rem;
  }
  /* Browsers running JS overlay all chapters in one grid cell, so the card
     is always as tall as the longest chapter and page switches never resize
     it; no-JS visitors keep the chapters stacked in normal flow. */
  @media (scripting: enabled) {
    .sp-pages {
      display: grid;
    }
    .sp-pages > :global(*) {
      grid-area: 1 / 1;
    }
    .sp-pages > :global(:not(:first-child)) {
      visibility: hidden;
    }
  }
  .sp-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 0.75rem;
    margin-top: 1.25rem;
    padding-top: 1.25rem;
    border-top: 1px solid #f3f4f6;
  }
  .sp-tabs {
    display: flex;
    flex-wrap: wrap;
    gap: 0.375rem;
  }
  .sp-tab {
    background: none;
    border: 1px solid transparent;
    border-radius: 9999px;
    padding: 0.3rem 0.8rem;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.15em;
    color: #9ca3af;
    cursor: pointer;
    transition: color 0.15s, border-color 0.15s, background 0.15s;
  }
  .sp-tab:hover {
    color: #374151;
  }
  .sp-tab.active {
    color: #111827;
    border-color: #e5e7eb;
    background: #f9fafb;
  }
  .sp-num {
    color: #c2c7cf;
    margin-right: 0.15rem;
  }
  .sp-tab.active .sp-num {
    color: #9ca3af;
  }
  .sp-arrows {
    display: flex;
    gap: 0.5rem;
  }
  .sp-arrow {
    width: 2.1rem;
    height: 2.1rem;
    border-radius: 9999px;
    border: 1px solid #e5e7eb;
    background: white;
    color: #6b7280;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.95rem;
    line-height: 1;
    transition: color 0.15s, background 0.15s;
  }
  .sp-arrow:hover {
    background: #f9fafb;
    color: #111827;
  }
  @media (min-width: 768px) {
    .sp-card {
      padding: 2rem 2.25rem;
    }
  }
</style>
