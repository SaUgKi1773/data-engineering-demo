<script>
  // 76px headline tile. The 4px split bar is the density trick: five
  // league-coloured segments whose widths are each league's share of this
  // measure, so "Goals 33,104" also answers "and whose goals are they".
  export let label = '';
  export let value = '';
  export let delta = null;      // signed number, already computed
  export let deltaFmt = (v) => (v > 0 ? '+' : '') + Number(v).toFixed(2);
  export let split = [];        // [{ colour, share }] summing to 100
</script>

<div class="flex h-[76px] flex-col justify-between bg-white px-2.5 py-1.5">
  <div class="truncate text-[10px] font-semibold uppercase tracking-wider text-gray-500">{label}</div>
  <div class="text-[22px] font-semibold leading-none tabular-nums text-gray-900">{value}</div>

  {#if split.length}
    <div class="flex h-[4px] w-full overflow-hidden rounded-[1px]">
      {#each split as s}
        <span style="width:{s.share}%; background:{s.colour};"></span>
      {/each}
    </div>
  {:else}
    <div class="h-[4px]"></div>
  {/if}

  <div class="text-[11px] leading-none tabular-nums {delta == null ? 'text-transparent' : delta < 0 ? 'text-[#c0392b]' : 'text-gray-500'}">
    {delta == null ? '·' : deltaFmt(delta)}
  </div>
</div>
