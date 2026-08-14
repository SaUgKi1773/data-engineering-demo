<script>
  // Every panel on the site. The 22px title bar replaces section headings —
  // that substitution is most of the difference between a page and a console.
  // Clarifications go in `qualifier` or `note`, never in a paragraph.
  export let title = '';
  export let qualifier = '';   // lowercase grey, follows the title
  export let scope = '';       // right-aligned readout: count, unit, range
  export let note = '';        // one 10px line at the foot
  export let href = null;      // makes the title a link (teaser panels)
  export let pad = true;
</script>

<div class="flex h-full min-w-0 flex-col rounded-[3px] border border-gray-200 bg-white">
  <div class="flex h-[22px] flex-none items-center gap-1.5 border-b border-gray-200 bg-[#fafafa] px-2">
    {#if href}
      <a {href} class="flex-none text-[10px] font-semibold uppercase tracking-wider text-gray-700 no-underline hover:text-gray-900">{title} →</a>
    {:else}
      <span class="flex-none text-[10px] font-semibold uppercase tracking-wider text-gray-700">{title}</span>
    {/if}
    {#if qualifier}<span class="truncate text-[10px] text-gray-400">· {qualifier}</span>{/if}
    {#if scope}<span class="ml-auto flex-none text-[10px] tabular-nums text-gray-400">{scope}</span>{/if}
  </div>
  <div class="min-w-0 flex-1 {pad ? 'p-2' : ''}">
    <slot />
  </div>
  {#if note}
    <div class="flex-none px-2 pb-1.5 text-[10px] leading-tight text-gray-400">{note}</div>
  {/if}
</div>
