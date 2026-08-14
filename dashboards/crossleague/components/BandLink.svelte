<script>
  // The rail that opens each band on Home — the house section head, the same
  // eyebrow-plus-hairline the league sites and the Hub use above every block.
  //
  // Home is a doorway to the other four pages, so on a phone this rail is the
  // page navigation in the body; it keeps a slightly larger name there and
  // settles to the house size from sm up. The colour is fixed across
  // breakpoints on purpose: a responsive variant would out-rank the hover
  // state in the generated CSS.
  export let href;
  export let name;
  export let note = '';
</script>

<a {href} class="group mb-3 mt-10 flex items-center gap-3 no-underline">
  <span class="flex-none text-[13px] font-semibold uppercase tracking-widest text-gray-500 transition-colors group-hover:text-gray-900 sm:text-[11px] sm:text-gray-400">{name}</span>
  <span class="flex-none text-[12px] leading-none text-gray-300 transition-all group-hover:translate-x-0.5 group-hover:text-gray-500">→</span>
  {#if note}
    <span class="hidden min-w-0 truncate text-[12px] text-gray-400 sm:inline">{note}</span>
  {/if}
  <span class="h-px flex-1 bg-gray-200"></span>
</a>
