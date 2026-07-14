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
  import ProjectMenu from '../components/ProjectMenu.svelte';

  export let data;

  afterNavigate(() => {
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
  <div slot="content">
    <slot />
  </div>
</EvidenceDefaultLayout>

<ProjectMenu />

<InstallBanner />

<style>
  :global(header img[alt="Home"]) {
    height: 2.5rem;
  }
  /* Hide Evidence's built-in kebab; replaced by the custom ProjectMenu */
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
