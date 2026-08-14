<script>
  // A two-dimensional single-scale grid: one measure over a row/column field.
  //
  // This is the one place a colour scale is honest on this site. Elsewhere a
  // scale would compete with the league hues; here there is one measure, one
  // ramp, and no league in the picture — so the reader learns "darker is more"
  // without also having to unlearn "colour means league".
  //
  // Built as divs because Evidence has no 2-D grid, and because the value has
  // to sit inside its own cell to be read at this size.
  export let rows = [];              // row labels, top to bottom
  export let cols = [];              // column labels, left to right
  export let cells = {};             // { `${row}|${col}`: value }
  export let format = (v) => Number(v).toFixed(1);
  export let rowTitle = '';
  export let colTitle = '';
  export let empty = '·';

  // Cube-weighted so the handful of common scorelines separate instead of the
  // whole grid sitting in the middle of the ramp.
  $: values = Object.values(cells).map(Number).filter((v) => !isNaN(v) && v > 0);
  $: max = values.length ? Math.max(...values) : 1;
  const weight = (v, max) => (max > 0 ? Math.pow(v / max, 1 / 2.2) : 0);
</script>

<div class="flex min-w-0 gap-1 overflow-x-auto">
  {#if rowTitle}
    <div class="flex flex-none items-center">
      <span class="whitespace-nowrap text-[9px] font-semibold uppercase tracking-wider text-gray-400"
            style="writing-mode:vertical-rl; transform:rotate(180deg);">{rowTitle}</span>
    </div>
  {/if}

  <div class="min-w-0 flex-1">
    {#if colTitle}
      <div class="mb-0.5 text-[9px] font-semibold uppercase tracking-wider text-gray-400">{colTitle}</div>
    {/if}

    <div class="grid gap-px" style="grid-template-columns: 1.6rem repeat({cols.length}, minmax(1.9rem, 1fr));">
      <span></span>
      {#each cols as c}
        <span class="pb-0.5 text-center text-[10px] font-semibold text-gray-500">{c}</span>
      {/each}

      {#each rows as r}
        <span class="flex items-center justify-end pr-1 text-[10px] font-semibold text-gray-500">{r}</span>
        {#each cols as c}
          {@const v = Number(cells[`${r}|${c}`] ?? 0)}
          {@const w = weight(v, max)}
          <span class="group relative flex h-7 items-center justify-center rounded-[2px] text-[11px] tabular-nums"
                style="background: rgba(31, 63, 107, {(0.04 + 0.92 * w).toFixed(3)});
                       color: {w > 0.55 ? '#ffffff' : '#111827'};">
            {v > 0 ? format(v) : empty}
            <span class="pointer-events-none absolute bottom-full left-1/2 z-30 mb-1 hidden -translate-x-1/2 whitespace-nowrap rounded-[3px] bg-[#1d1d1f] px-2 py-1.5 text-[11px] leading-tight text-white shadow-lg group-hover:block">
              <span class="block font-semibold">{r} – {c}</span>
              <span class="block">{v > 0 ? format(v) : '0'}</span>
            </span>
          </span>
        {/each}
      {/each}
    </div>
  </div>
</div>
