<script>
  // The permanent colour key, pinned in the nav band on every page.
  //
  // It is load-bearing, not decorative: because it is always on screen, every
  // panel below can set legend=false and label leagues by three-letter code.
  // Codes are 3 characters where names are 7-11 and never collide, and that
  // reclaimed width is what makes a dense layout legible.
  export let leagues = [];
</script>

<div class="flex flex-wrap items-center gap-x-3 gap-y-1">
  {#each leagues as l}
    <a href={l.site_url} target="_blank" rel="noopener"
       class="group flex items-center gap-1.5 no-underline" title="{l.league_name} — open site">
      <span class="h-[10px] w-[3px] flex-none rounded-[1px]" style="background:{l.colour}"></span>
      <span class="text-[10px] font-semibold tracking-wide text-white/85 group-hover:text-white">{l.code}</span>
      <span class="hidden text-[10px] text-white/35 group-hover:text-white/60 lg:inline">{l.league_name}</span>
    </a>
  {/each}
</div>
