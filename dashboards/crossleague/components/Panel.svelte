<script>
  // Every panel on the site.
  //
  // Wears the house card: rounded-xl, hairline border, soft shadow, white on
  // white — the same surface the league sites use for their tiles, rather than
  // the flat 3px-radius instrument this site started as. The title is an
  // uppercase eyebrow in the house's tracking-widest grey, so a panel head and
  // a section head read as the same family.
  export let title = '';
  export let qualifier = '';   // lowercase grey, follows the title
  export let scope = '';       // right-aligned readout: count, unit, range
  export let note = '';        // one small line at the foot
  export let href = null;      // makes the title a link (teaser panels)
  export let pad = true;
</script>

<div class="flex h-full min-w-0 flex-col rounded-xl border border-gray-200 bg-white shadow-sm">
  <div class="flex flex-none flex-wrap items-baseline gap-x-2 gap-y-0.5 border-b border-gray-100 px-3 py-2">
    {#if href}
      <a {href} class="flex-none text-[11px] font-semibold uppercase tracking-widest text-gray-500 no-underline transition-colors hover:text-gray-900">{title} →</a>
    {:else}
      <span class="flex-none text-[11px] font-semibold uppercase tracking-widest text-gray-500">{title}</span>
    {/if}
    {#if qualifier}<span class="truncate text-[11px] text-gray-400">{qualifier}</span>{/if}
    {#if scope}<span class="ml-auto flex-none text-[11px] tabular-nums text-gray-400">{scope}</span>{/if}
  </div>
  <div class="min-w-0 flex-1 {pad ? 'p-3' : ''}">
    <slot />
  </div>
  {#if note}
    <div class="flex-none px-3 pb-2 text-[11px] leading-tight text-gray-400">{note}</div>
  {/if}
</div>
