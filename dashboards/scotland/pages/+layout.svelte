<svelte:head>
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Premiership" />
  <meta name="theme-color" content="#1D4ED8" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <meta property="og:site_name" content="Scottish Premiership Analytics" />
  <meta property="og:type" content="website" />
</svelte:head>

<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { afterNavigate } from '$app/navigation';
  import { inject } from '@vercel/analytics';
  import InstallBanner from '../components/InstallBanner.svelte';
  import HeaderMenuButton from '../components/HeaderMenuButton.svelte';
  import SideNav from '../components/SideNav.svelte';
  import BottomNav from '../components/BottomNav.svelte';

  export let data;

  let menuOpen = false;

  afterNavigate(() => {
    menuOpen = false;
    setTimeout(() => window.scrollTo(0, 0), 0);
  });

  onMount(() => {
    inject();
    const script = document.createElement('script');
    script.defer = true;
    script.src = 'https://static.cloudflareinsights.com/beacon.min.js';
    script.dataset.cfBeacon = JSON.stringify({ token: '167db4d57c9742e1883b3e1ea858bccc' });
    document.head.appendChild(script);
  });
</script>

<EvidenceDefaultLayout {data} hideBreadcrumbs={true} neverShowQueries={true} hideMenu={true} logo="/header-logo.svg">
  <div slot="content" class="nav-content">
    <slot />
  </div>
</EvidenceDefaultLayout>

<HeaderMenuButton on:open={() => (menuOpen = true)} />
<SideNav open={menuOpen} on:close={() => (menuOpen = false)} />
<BottomNav />

<InstallBanner />

<style>
  /* Keep page content clear of the fixed bottom nav bar (mobile only, where it shows). */
  @media (max-width: 767px) {
    .nav-content {
      padding-bottom: calc(4rem + env(safe-area-inset-bottom) + 1rem);
    }
  }
  :global(header img[alt="Home"]) {
    height: 2.5rem;
  }
  /* Hide Evidence's built-in kebab; navigation is the custom side pane + bottom bar. */
  :global(header button[aria-label="Menu"]) {
    display: none;
  }
  :global(.standings-table table) {
    table-layout: fixed;
    width: 100%;
  }
  :global(.standings-table table th:nth-child(1)),
  :global(.standings-table table td:nth-child(1)) { width: 1.5rem; }
  :global(.standings-table table th:nth-child(n+3)),
  :global(.standings-table table td:nth-child(n+3)) { width: 2.2rem; }
  @media (min-width: 768px) {
    :global(.standings-table table th:nth-child(1)),
    :global(.standings-table table td:nth-child(1)) { width: 2.2rem; }
    :global(.standings-table table th:nth-child(n+3)),
    :global(.standings-table table td:nth-child(n+3)) { width: 3.5rem; }
  }
</style>
