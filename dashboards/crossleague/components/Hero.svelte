<script>
  // The house hero: rounded-3xl banner, pitch-line overlay, centre-circle hint.
  //
  // The league sites fill it with one flag's colours. This site has five
  // countries and no flag of its own, so the gradient is built from the five
  // league hues in their fixed alphabetical order — the same order and the
  // same colours the charts use, which makes the banner double as the key the
  // header used to carry.
  import { leagues } from './navItems.js';

  // The refresh date is not repeated here; the footer already carries it.
  export let matches = null;
  export let goals = null;
  export let clubs = null;

  const stops = leagues.map((l, i) => `${l.colour} ${(i * 100) / (leagues.length - 1)}%`).join(', ');
  const fmt = (v) => (v == null ? '–' : Math.round(Number(v)).toLocaleString());
</script>

<div class="relative mb-10 overflow-hidden rounded-3xl shadow-lg"
     style="background: linear-gradient(115deg, {stops});">
  <!-- A dark wash under the hues so white type holds its contrast on all five. -->
  <div class="absolute inset-0" style="background: linear-gradient(115deg, rgba(20,22,28,0.86) 0%, rgba(20,22,28,0.72) 55%, rgba(20,22,28,0.86) 100%);"></div>

  <!-- pitch lines -->
  <div class="absolute inset-0 opacity-[0.08]"
       style="background-image: repeating-linear-gradient(90deg, white 0px, white 1px, transparent 1px, transparent 80px), repeating-linear-gradient(0deg, white 0px, white 1px, transparent 1px, transparent 80px);"></div>
  <!-- centre circle hint -->
  <div class="pointer-events-none absolute inset-0 flex items-center justify-center">
    <div class="rounded-full border border-white opacity-[0.06]" style="width:320px;height:320px;"></div>
  </div>

  <div class="relative flex flex-col items-center gap-5 px-6 py-8 text-center xl:flex-row xl:justify-between xl:px-12 xl:py-7 xl:text-left">
    <div>
      <div class="mb-1 text-[11px] uppercase text-white/50" style="letter-spacing: 0.14em;">Krogvad Analytics Hub</div>
      <div class="text-3xl font-bold leading-none tracking-tight text-white xl:text-4xl">Cross-League Analytics</div>
      <div class="mt-1 text-xs italic tracking-wide text-white/50">Powered by data. Built for football.</div>
    </div>

    <div class="flex flex-col items-center gap-3 xl:items-end">
      <div class="text-sm text-white/70 xl:text-base">
        <span class="font-semibold text-white">{fmt(matches)}</span> matches ·
        <span class="font-semibold text-white">{fmt(goals)}</span> goals ·
        <span class="font-semibold text-white">{fmt(clubs)}</span> clubs
      </div>
      <!-- The five, in the fixed order the hues were assigned. Doubles as the key. -->
      <div class="flex flex-wrap items-center justify-center gap-2">
        {#each leagues as l}
          <a href={l.site_url} target="_blank" rel="noopener"
             class="flex items-center gap-1.5 rounded-full border border-white/15 bg-white/5 px-2.5 py-1 no-underline transition-colors hover:border-white/40 hover:bg-white/10">
            <span class="h-2 w-2 flex-none rounded-full" style="background:{l.colour}"></span>
            <span class="text-[11px] font-semibold text-white/90">{l.code}</span>
            <span class="hidden text-[11px] text-white/45 sm:inline">{l.league_name}</span>
          </a>
        {/each}
      </div>
    </div>
  </div>
</div>
