<svelte:head>
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Krogvad Hub" />
  <meta name="theme-color" content="#ffffff" />
  <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
  <meta property="og:site_name" content="Krogvad Analytics Hub" />
  <meta property="og:type" content="website" />
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
