<svelte:head>
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Krogvad Hub" />
  <meta name="theme-color" content="#1D4ED8" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <meta property="og:site_name" content="Krogvad Analytics Hub" />
  <meta property="og:type" content="website" />
  <!-- Absolute URL: LinkedIn/Slack scrapers don't resolve relative og:image paths -->
  <meta property="og:image" content="https://krogvadanalyticshub.vercel.app/og-card.png" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta name="twitter:image" content="https://krogvadanalyticshub.vercel.app/og-card.png" />
</svelte:head>

<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';

  export let data;

  onMount(() => {
    inject();
  });
</script>

<EvidenceDefaultLayout {data} hideBreadcrumbs={true} neverShowQueries={true} hideMenu={true} logo="/header-logo.svg">
  <slot slot="content" />
</EvidenceDefaultLayout>

<style>
  :global(header img[alt="Home"]) {
    height: 2.5rem;
  }
  /* Hide Evidence's built-in kebab menu — the hub has no pages to navigate */
  :global(header button[aria-label="Menu"]) {
    display: none;
  }
</style>
