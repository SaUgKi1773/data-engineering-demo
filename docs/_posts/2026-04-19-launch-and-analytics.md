---
layout: post
title: "Global Launch and Adding Analytics"
date: 2026-04-19
categories: [data-engineering, analytics, deployment]
---

By April 19th, 2026 — roughly ten days after the first real commit — the pipeline was stable, the dashboard had seven pages, the README was updated to reflect the current architecture, and the nightly job was running cleanly. It was time to call it launched.

The live dashboard is at [superligaanalytics.vercel.app](https://superligaanalytics.vercel.app/).

## What Shipped at Launch

The final state of the project at launch:

- **Bronze layer** — 21 endpoints ingested nightly from api-football.com into MotherDuck
- **Silver layer** — 18 dbt models that flatten and type-cast the raw JSON
- **Gold layer** — Kimball star schema: 10 dimension tables and `fct_match_results`
- **Dashboard** — 7 Evidence.dev pages: Home, Standings, Match Results, Upcoming Fixtures, League Analytics, Team Analytics, Referee Analytics
- **Orchestration** — GitHub Actions nightly pipeline: bronze → silver → gold → Vercel deploy
- **CI** — dbt compile on every pull request to main
- **Dev/prod separation** — `superligaen_dev` and `superligaen` databases, `dev` and `prod` dbt targets
- **112 pull requests merged** across the development sprint

The one final polish item before launch: the home page navigation grid had cards in an order that did not feel right. Upcoming Fixtures should come before Team Analysis. League Analysis should come before Team Analysis too. Two one-line changes, merged, deployed.

## Adding Visitor Analytics

Once the site was live, the natural question was: is anyone visiting it? We needed analytics.

The options were straightforward: Vercel Analytics (built into the hosting platform), Cloudflare Web Analytics (a separate free service), or Google Analytics (the industry default but heavier and requiring a cookie consent banner under GDPR).

Google Analytics was ruled out immediately. GDPR cookie banners are user-hostile and unnecessary for a project where we genuinely do not need detailed personal data — we just want page view counts and visitor numbers.

Both Vercel Analytics and Cloudflare Web Analytics are **cookieless and privacy-first**. They count visits using aggregated signals rather than tracking individuals. No consent banner required.

We decided to use both — not because we needed redundancy, but because each gives you a slightly different view of traffic data, and running both costs nothing.

## The First Analytics Attempt (And How It Broke Everything)

Adding Vercel Analytics was not as simple as enabling a toggle in the Vercel dashboard. For SvelteKit apps (which Evidence.dev is built on), you need to install the `@vercel/analytics` npm package and call `inject()` somewhere in your app.

The natural place for a call that should run on every page is a layout component. Evidence.dev (SvelteKit) supports a `pages/+layout.svelte` file. I created one:

```svelte
<script>
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';
  onMount(() => inject());
</script>

<slot />
```

This broke the site completely. Every page lost its navigation, sidebar, theming, and layout chrome.

The reason: Evidence.dev has its own built-in `+layout.svelte` that imports its stylesheet, loads its default layout component (`EvidenceDefaultLayout`), and handles the app shell. When you create a `pages/+layout.svelte`, Evidence copies your file into its template directory, **overwriting its own layout**. My file only had `<slot />` — which rendered the page content but none of Evidence's surrounding UI.

The fix required knowing what Evidence's own layout looked like. Once that was clear, the correct version wraps Evidence's layout rather than replacing it:

```svelte
<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';

  export let data;

  onMount(() => inject());
</script>

<EvidenceDefaultLayout {data}>
  <slot slot="content" />
</EvidenceDefaultLayout>
```

This correctly extends Evidence's layout rather than replacing it.

## Adding Cloudflare Web Analytics

Adding the Cloudflare beacon alongside Vercel Analytics required one more trick. The Cloudflare script tag looks like this in standard HTML:

```html
<script defer src="https://static.cloudflareinsights.com/beacon.min.js"
  data-cf-beacon='{"token": "your-token"}'></script>
```

The `{` and `}` characters in the `data-cf-beacon` attribute value are Svelte template delimiters. If you put this tag inside a `<svelte:head>` block, Svelte's compiler tries to parse `{"token": "..."}` as a template expression and fails with a parse error.

The workaround: inject the script using `document.createElement` inside the `onMount` callback, where Svelte's template compiler does not process the string:

```javascript
onMount(() => {
  inject(); // Vercel Analytics

  const script = document.createElement('script');
  script.defer = true;
  script.src = 'https://static.cloudflareinsights.com/beacon.min.js';
  script.dataset.cfBeacon = JSON.stringify({ token: 'your-token' });
  document.head.appendChild(script);
});
```

This is less elegant than a `<script>` tag in the HTML but works correctly and is straightforward to understand.

## Reflections on Ten Days

This project went from initial commit to live dashboard in approximately ten days of active development. That is fast enough that almost every architectural choice was made under time pressure, with incomplete information, and revised at least once.

The tools that delivered exactly what they promised: MotherDuck, DuckDB, dbt, GitHub Actions. No surprises, no unexplained failures, no time spent on yak-shaving.

The tools that required more navigation: Netlify (build limits), Cloudflare Pages (file size limits), Vercel (deploy hook unreliability), Evidence.dev (some underdocumented behaviour around layouts and template syntax).

The choices I would make the same way: MotherDuck as the warehouse, dbt for transformations, Evidence.dev for the dashboard, Vercel for hosting, the Kimball star schema, the dev/prod database separation, the delete-before-insert idempotency pattern.

The choices I would make differently: evaluate hosting platforms against build frequency and output size before committing; add dbt tests from the beginning rather than deferring them; set up dbt documentation from the start.

The ambitions that did not make it in: multi-league support (blocked by API quota), dbt tests, dbt documentation, real-time match events (requires a paid API tier), mobile app version of the dashboard.

The project is now in maintenance mode. The nightly pipeline runs, the data updates, and the dashboard reflects last night's results every morning. For a project built entirely on free tiers in ten days, that is a good place to be.
