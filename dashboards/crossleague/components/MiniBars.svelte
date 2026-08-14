<script>
  // The vertical sibling of Rank.svelte: five bars, sorted descending, values
  // printed underneath. Built from divs rather than twenty ECharts instances —
  // ECharts will not compress below ~180px cleanly, and divs let each bar carry
  // its own league colour. Between them, Rank and MiniBars cover every ranked
  // visual on the site, which is how swapXY never gets called.
  export let title = '';
  export let rows = [];              // [{ code, value, colour }] pre-sorted desc
  export let format = (v) => Number(v).toFixed(2);
  export let height = 54;

  $: max = Math.max(...rows.map((r) => Number(r.value) || 0), 0) || 1;
</script>

<div class="flex flex-col rounded-[3px] border border-gray-200 bg-white px-2 py-1.5">
  <div class="truncate text-[10px] font-semibold uppercase tracking-wider text-gray-500">{title}</div>

  {#if rows.length}
    <div class="mt-0.5 flex items-baseline gap-1">
      <span class="h-2 w-2 flex-none rounded-full" style="background:{rows[0].colour}"></span>
      <span class="text-[11px] font-semibold text-gray-500">{rows[0].code}</span>
      <span class="text-[15px] font-semibold leading-none tabular-nums text-gray-900">{format(rows[0].value)}</span>
    </div>

    <div class="mt-1.5 flex items-end gap-1" style="height:{height}px;">
      {#each rows as r, i}
        <span class="flex-1 rounded-t-[2px]"
              style="height:{Math.max((Number(r.value) || 0) / max * 100, 2)}%; background:{r.colour}; opacity:{i === 0 ? 1 : 0.45};"></span>
      {/each}
    </div>

    <div class="mt-0.5 flex gap-1">
      {#each rows as r}
        <span class="flex-1 text-center text-[9px] font-medium leading-tight text-gray-500">{r.code}</span>
      {/each}
    </div>
    <div class="flex gap-1">
      {#each rows as r, i}
        <span class="flex-1 text-center text-[9px] leading-tight tabular-nums {i === 0 ? 'font-semibold text-gray-900' : 'text-gray-400'}">{format(r.value)}</span>
      {/each}
    </div>
  {/if}
</div>
