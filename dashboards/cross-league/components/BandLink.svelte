<script>
  // The rail that opens each band on Home.
  //
  // Home is a doorway to the other four pages, so on a phone this is the only
  // page navigation in the body — which is why the name is LARGER on mobile
  // than on the desktop console. On a wide screen the tab bar is always in
  // view and the rail can recede to 10px; on a phone it has to carry the
  // wayfinding on its own. The colour stays fixed across breakpoints so no
  // responsive variant can out-rank the hover state.
  export let href;
  export let name;
  export let note = '';
</script>

<a {href} class="group mb-1 mt-4 flex items-center gap-2 no-underline sm:mt-3">
  <span class="flex-none text-[12px] font-semibold uppercase tracking-wider text-gray-800 sm:text-[10px]">{name}</span>
  <span class="flex-none text-[11px] leading-none text-gray-400 group-hover:text-gray-700 sm:text-[10px]">→</span>
  {#if note}
    <span class="hidden min-w-0 truncate text-[10px] text-gray-400 sm:inline">{note}</span>
  {/if}
  <span class="h-px flex-1 bg-gray-200"></span>
</a>
