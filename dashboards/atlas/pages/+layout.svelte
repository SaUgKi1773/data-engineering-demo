<svelte:head>
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-title" content="Krogvad" />
  <meta name="theme-color" content="#1d1d1f" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <meta property="og:site_name" content="Krogvad Cross-League Analytics" />
  <meta property="og:type" content="website" />
</svelte:head>

<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';
  import TopTabs from '../components/TopTabs.svelte';
  import LeagueKey from '../components/LeagueKey.svelte';
  import { tabs, leagues } from '../components/navItems.js';

  export let data;
  onMount(() => inject());
</script>

<!-- ══ THE SHELL ═══════════════════════════════════════════════════════════
     Two dark bands carrying identity and navigation, sticky to the top of the
     window. Evidence's own header is hidden below; it costs ~64px and offers a
     drawer icon where this needs permanent tabs. -->
<div class="sticky top-0 z-50">
  <div class="flex h-8 items-center gap-3 bg-[#1d1d1f] px-4">
    <a href="/" class="flex flex-none items-center gap-2 no-underline">
      <img src="/logo-circle.svg" alt="" class="h-[18px] w-[18px]" />
      <span class="text-[11px] font-semibold tracking-wide text-white">KROGVAD</span>
      <span class="hidden text-[10px] uppercase tracking-[0.18em] text-white/35 sm:inline">Cross-League Analytics</span>
    </a>
    <span class="ml-auto flex-none truncate text-[10px] tabular-nums text-white/40">
      5 leagues · Denmark · Scotland · Spain · Turkey · Mexico
    </span>
  </div>

  <div class="flex h-[34px] items-stretch gap-4 border-b border-black/40 bg-[#26262a] px-4">
    <TopTabs {tabs} />
    <div class="ml-auto flex flex-none items-center">
      <LeagueKey {leagues} />
    </div>
  </div>
</div>

<EvidenceDefaultLayout {data} hideBreadcrumbs={true} neverShowQueries={true} hideMenu={true}>
  <div slot="content" class="console">
    <slot />
  </div>
</EvidenceDefaultLayout>

<style>
  /* Evidence's own header and title block are replaced by the bands above. */
  :global(header) { display: none !important; }
  :global(.markdown h1:first-of-type) { display: none; }

  /* A console is a flat instrument on a grey ground, not cards on white. */
  :global(body) { background: #f5f5f7; }
  :global(.console) {
    max-width: 1400px;
    margin: 0 auto;
    padding: 8px 16px 32px;
  }
  /* The page's own prose defaults fight a dense grid; neutralise them. */
  :global(.console p) { margin: 0; }
  :global(.console > div + div) { margin-top: 0; }

  /* Evidence's content wrapper reserves room for the page title and breadcrumb
     bar this layout removes; without these the first panel starts ~100px down. */
  :global(article) { padding-top: 0 !important; margin-top: 0 !important; }
  /* Evidence reserves 74px of margin for its fixed header; this layout hides
     that header and supplies its own sticky bands, so the reservation is dead
     space above the first panel. */
  :global(main) { padding-top: 0 !important; margin-top: 0 !important; }
  :global(.markdown) { padding-top: 0 !important; }
  :global(#evidence-main-content) { padding-top: 0 !important; }
</style>
