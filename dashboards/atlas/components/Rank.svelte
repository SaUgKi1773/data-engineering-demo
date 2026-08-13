<script>
  // A ranked list drawn as bars, rather than as a chart.
  //
  // Evidence's bar chart cannot do this: swapXY renders every bar as a sliver
  // in this build, and colouring one bar per league needs five single-point
  // series, which grouped mode spreads across the plot with gaps. Drawing the
  // rows here gives each league its own colour, the value beside the bar and a
  // layout that reads as designed rather than as a default chart.
  //
  // rows: [{ label, sublabel, value, colour, href }]  — already sorted.
  export let rows = [];
  export let format = (v) => v;
  export let showRank = true;
  export let compact = false;
  export let dense = false;   // 3px bars, 11px text — 25 rows in 430px

  // Bars are proportional to the largest value, always from zero.
  $: max = Math.max(...rows.map((r) => Number(r.value) || 0), 0) || 1;
  $: gap = dense ? 'gap-0.5' : compact ? 'gap-1' : 'gap-1.5';
  $: barH = dense ? 'h-3' : compact ? 'h-4' : 'h-5';
  $: txt = dense ? 'text-[11px]' : compact ? 'text-[13px]' : 'text-sm';
  $: labelW = dense ? 'w-[8rem]' : 'w-[9.5rem]';
</script>

<div class="flex flex-col {gap}">
  {#each rows as row, i}
    <div class="group flex items-center gap-3">
      {#if showRank}
        <span class="w-5 flex-none text-right text-[11px] font-medium tabular-nums text-gray-400">{i + 1}</span>
      {/if}

      <span class="{labelW} flex-none truncate {txt} font-medium text-gray-900" title={row.label}>
        {#if row.href}
          <a href={row.href} target="_blank" rel="noopener" class="no-underline text-gray-900 hover:text-gray-500">{row.label}</a>
        {:else}
          {row.label}
        {/if}
        {#if row.sublabel}
          <span class="ml-1.5 text-[11px] font-normal text-gray-400">{row.sublabel}</span>
        {/if}
      </span>

      <span class="relative min-w-0 flex-1">
        <span class="block rounded-[2px] transition-all duration-300 {barH}"
              style="width: {Math.max((Number(row.value) || 0) / max * 100, 1.5)}%; background: {row.colour || '#1d1d1f'};"></span>
      </span>

      <span class="w-14 flex-none text-right {txt} font-semibold tabular-nums text-gray-900">
        {format(row.value)}
      </span>
    </div>
  {/each}
</div>
