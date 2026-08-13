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

  const RANKS = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧'];

  function ranked(values) {
    return Object.entries(values)
      .filter(([, v]) => v != null && !isNaN(v))
      .sort((a, b) => b[1] - a[1])
      .reduce((acc, [k], i) => ({ ...acc, [k]: i + 1 }), {});
  }
  const maxOf = (values) => Math.max(...Object.values(values).filter((v) => v != null && !isNaN(v)), 0) || 1;
</script>

<table class="w-full border-collapse">
  <thead>
    <tr>
      <th class="w-[7.5rem] px-1 pb-1 text-left text-[10px] font-semibold uppercase tracking-wider text-gray-400">Measure</th>
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
      {@const mx = maxOf(row.values)}
      <tr class="border-t border-gray-100">
        <td class="px-1 py-[3px] text-[11px] leading-tight text-gray-700">{row.measure}</td>
        {#each codes as c}
          {@const v = row.values[c.code]}
          <td class="px-[1px] py-[2px]">
            {#if v == null || isNaN(v)}
              <span class="block px-1 text-right text-[11px] text-gray-300">–</span>
            {:else}
              <span class="relative block overflow-hidden rounded-[2px]">
                <span class="absolute inset-y-0 left-0" style="width:{Math.max(v / mx * 100, 3)}%; background:{c.colour}; opacity:{rk[c.code] === 1 ? 0.42 : 0.16};"></span>
                <span class="relative flex items-baseline justify-end gap-0.5 px-1 py-[2px]">
                  <span class="text-[11px] tabular-nums {rk[c.code] === 1 ? 'font-semibold text-gray-900' : 'text-gray-700'}">{(row.format || ((x) => x.toFixed(2)))(v)}</span>
                  <span class="text-[8px] text-gray-400">{RANKS[rk[c.code] - 1]}</span>
                </span>
              </span>
            {/if}
          </td>
        {/each}
      </tr>
    {/each}
  </tbody>
</table>
