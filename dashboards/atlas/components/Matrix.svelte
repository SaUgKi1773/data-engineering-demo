<script>
  // Measures down, leagues across, with the comparison running ACROSS each row.
  //
  // This is hand-built rather than a DataTable for one specific reason: an
  // Evidence colour scale runs DOWN a column, and these rows carry different
  // units — scaled that way, passes paints the whole grid black and nothing
  // else registers. Here each cell's bar is scaled to its own ROW's maximum, so
  // the leader's bar fills its cell in every row at once. That single rule is
  // what makes the leader obvious in twenty rows simultaneously.
  //
  // Columns stay in a fixed order and are never re-sorted by value: a reader
  // scanning twenty rows needs the columns to stay put. Ranking is expressed by
  // the fill and the superscript instead.
  export let codes = [];   // [{ code, colour }] fixed order
  export let rows = [];    // [{ measure, values: { CODE: number } , format }]

  function ranked(values) {
    return Object.entries(values)
      .filter(([, v]) => v != null && !isNaN(v))
      .sort((a, b) => b[1] - a[1])
      .reduce((acc, [k], i) => ({ ...acc, [k]: i + 1 }), {});
  }
  const nums = (values) => Object.values(values).filter((v) => v != null && !isNaN(v));
  // 0 for the row's lowest league, 1 for its highest, cubed.
  function weight(v, values) {
    const n = nums(values);
    if (!n.length) return 0;
    const lo = Math.min(...n), hi = Math.max(...n);
    if (hi === lo) return 1;
    return Math.pow((v - lo) / (hi - lo), 3);
  }
</script>

<div class="-mx-2 overflow-x-auto px-2">
<table class="w-full min-w-[19rem] border-collapse">
  <thead>
    <tr>
      <th class="sticky left-0 z-10 w-[6.5rem] bg-white px-1 pb-1 text-left text-[10px] font-semibold uppercase tracking-wider text-gray-400">Measure</th>
      {#each codes as c}
        <th class="px-0.5 pb-1 text-center">
          <span class="mx-auto mb-0.5 block h-[3px] w-full rounded-[1px]" style="background:{c.colour}"></span>
          <span class="text-[10px] font-semibold text-gray-600">{c.code}</span>
        </th>
      {/each}
    </tr>
  </thead>
  <tbody>
    {#each rows as row}
      {@const rk = ranked(row.values)}
      <tr class="border-t border-gray-100">
        <td class="sticky left-0 z-10 whitespace-nowrap bg-white px-1 py-[3px] text-[11px] leading-tight text-gray-700">{row.measure}</td>
        {#each codes as c}
          {@const v = row.values[c.code]}
          <td class="px-[1px] py-[2px] min-w-[2.4rem]">
            {#if v == null || isNaN(v)}
              <span class="block px-1 text-right text-[11px] text-gray-300">–</span>
            {:else}
              {@const w = weight(v, row.values)}
              <span class="block rounded-[2px] px-1 py-[2px] text-right"
                    style="background:rgba(31,63,107,{(0.05 + 0.88 * w).toFixed(3)});">
                <span class="text-[11px] tabular-nums {w > 0.5 ? 'font-semibold text-white' : rk[c.code] === 1 ? 'font-semibold text-gray-900' : 'text-gray-700'}">{(row.format || ((x) => x.toFixed(2)))(v)}</span>
              </span>
            {/if}
          </td>
        {/each}
      </tr>
    {/each}
  </tbody>
</table>
</div>
