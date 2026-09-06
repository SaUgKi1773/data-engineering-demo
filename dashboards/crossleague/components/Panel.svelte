<script>
  // Every panel on the site.
  //
  // Wears the house card: rounded-xl, hairline border, soft shadow, white on
  // white — the same surface the league sites use for their tiles, rather than
  // the flat 3px-radius instrument this site started as. The title is an
  // uppercase eyebrow in the house's tracking-widest grey, so a panel head and
  // a section head read as the same family.
  //
  // With href the whole card becomes the link, not just its title: on Home a
  // panel is a teaser for a page, and the chart is the part the reader aims
  // at. Hover borrows the league sites' card state — border darkens, shadow
  // lifts, arrow nudges — so a clickable panel announces itself the same way
  // their nav cards do.
  export let title = '';
  export let qualifier = '';   // lowercase grey, follows the title
  export let scope = '';       // right-aligned readout: count, unit, range
  export let note = '';        // one small line at the foot
  export let href = null;      // makes the whole card a link (teaser panels)
  export let pad = true;

  // A chart draws its own controls inside the card — Evidence's "Save Image"
  // and "Download Data" are buttons, and a button click bubbles to the card
  // link. Cancel the navigation for those so the control does its own job.
  // Nested links need no guard: the browser already follows the inner one.
  function guardControls(e) {
    if (!href) return;
    const control = e.target?.closest?.('button, input, select, textarea, [role="button"]');
    if (control) e.preventDefault();
  }
</script>

<svelte:element
  this={href ? 'a' : 'div'}
  {...(href ? { href } : {})}
  on:click={guardControls}
  class="group/panel flex h-full min-w-0 flex-col rounded-xl border border-gray-200 bg-white no-underline shadow-sm {href
    ? 'transition-all duration-200 hover:border-gray-400 hover:shadow-md'
    : ''}">
  <div class="flex flex-none flex-wrap items-baseline gap-x-2 gap-y-0.5 border-b border-gray-100 px-3 py-2">
    <span class="flex-none text-[11px] font-semibold uppercase tracking-widest text-gray-500 {href
      ? 'transition-colors group-hover/panel:text-gray-900'
      : ''}">{title}</span>
    {#if qualifier}<span class="truncate text-[11px] text-gray-400">{qualifier}</span>{/if}
    {#if scope}<span class="ml-auto flex-none text-[11px] tabular-nums text-gray-400">{scope}</span>{/if}
    {#if href}
      <span class="flex-none text-[12px] leading-none text-gray-300 transition-all duration-200 group-hover/panel:translate-x-0.5 group-hover/panel:text-gray-500 {scope ? '' : 'ml-auto'}">→</span>
    {/if}
  </div>
  <div class="min-w-0 flex-1 {pad ? 'p-3' : ''}">
    <slot />
  </div>
  {#if note}
    <div class="flex-none px-3 pb-2 text-[11px] leading-tight text-gray-400">{note}</div>
  {/if}
</svelte:element>
