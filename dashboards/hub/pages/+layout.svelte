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
  import { afterNavigate } from '$app/navigation';
  import { inject } from '@vercel/analytics';
  import HeaderMenuButton from '../components/HeaderMenuButton.svelte';
  import SideNav from '../components/SideNav.svelte';

  export let data;

  let menuOpen = false;

  afterNavigate(() => {
    menuOpen = false;
  });

  onMount(() => {
    inject();
  });
</script>

<EvidenceDefaultLayout {data} hideBreadcrumbs={true} neverShowQueries={true} hideMenu={true} logo="/header-logo.svg">
  <slot slot="content" />
</EvidenceDefaultLayout>

<HeaderMenuButton on:open={() => (menuOpen = true)} />
<SideNav open={menuOpen} on:close={() => (menuOpen = false)} />

<style>
  /* Evidence injects html{scroll-behavior:smooth} globally. Chrome does not
     downgrade a smooth scroll to an instant one under prefers-reduced-motion —
     it drops the scroll entirely, so every in-page anchor silently does nothing
     for those readers, the hero's own "Explore our platforms" included.
     Verified: with smooth the anchor moved the page 0px, with auto it moved
     1,715px. */
  @media (prefers-reduced-motion: reduce) {
    :global(html) { scroll-behavior: auto !important; }
  }

  :global(header img[alt="Home"]) {
    height: 2.5rem;
  }
  /* Hide Evidence's built-in kebab; navigation is the custom side pane. */
  :global(header button[aria-label="Menu"]) {
    display: none;
  }
</style>
