<script>
  // 76px headline tile. The 4px split bar is the density trick: five
  // league-coloured segments whose widths are each league's share of this
  // measure, so "Goals 33,104" also answers "and whose goals are they".
  export let label = '';
  export let value = '';
  export let split = [];        // [{ colour, share }] summing to 100
  export let foot = '';         // who leads this measure
  export let footColour = null;
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

  <div class="flex items-center gap-1 text-[11px] leading-none text-gray-500">
    {#if footColour}<span class="h-1.5 w-1.5 flex-none rounded-full" style="background:{footColour}"></span>{/if}
    <span class="truncate">{foot}</span>
  </div>
</div>
