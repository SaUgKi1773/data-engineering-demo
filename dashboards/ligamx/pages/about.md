---
sidebar: never
hide_toc: true
title: About This Project
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into insights. This site started life as [Superliga Analytics](https://saugki1773.github.io/data-engineering-blog/) — an end-to-end data engineering project for Danish football, built entirely on free, open-source tools: no vendor lock-in, no cloud bills. A stranger's feature request then added the Scottish Premiership.

Liga MX arrived over dinner, from a friend: *you should do Liga MX — the structure is completely different from anything you've got.* He was right, and that was exactly the appeal. Two tournaments inside a single season, each with its own table and its own champion. A knockout — the **liguilla** — that decides the title, so topping the table wins you nothing but a seeding. A play-in round that has changed format twice in five years. Almost everything the pipeline quietly assumed about "a league season" turned out to be a European assumption rather than a football one.

There was a bigger reason too. These sites are not standalone projects — each one is a data product under [**Krogvad Analytics Hub**](https://krogvadanalyticshub.vercel.app/), sharing a single warehouse and a single nightly pipeline. The plan for the Hub has always been worldwide, not European, and a group covering Denmark and Scotland isn't worldwide — it's Northern European with ambitions. Mexico was a genuinely good candidate: a big league, a distinctive shape, an audience that isn't mine.

That's how this site was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) and [Highlightly](https://soccer.highlightly.net/) into a **MotherDuck** cloud data warehouse
- Conforms both providers onto shared keys, so a club is one club no matter who reported it
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

## Source Code

Everything — the ingestion scripts, dbt models, and this Evidence dashboard — is open source.

<div class="-mt-3">
<a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-gray-900 text-white font-semibold hover:bg-gray-700 transition-colors no-underline">
  Source Code on GitHub
</a>
</div>

## Get the Data

Prefer SQL over dashboards? The full gold layer behind this site — all leagues, refreshed nightly — is available as a free read-only [MotherDuck](https://motherduck.com/) share you can query straight from DuckDB. You'll need a free MotherDuck account; request access below and I'll grant it to your account.

<div class="-mt-3">
<a href="https://forms.gle/2wDZcfwm8jk6aWGS9" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-amber-600 text-white font-semibold hover:bg-amber-700 transition-colors no-underline">
  🗄️ Request Data Access
</a>
</div>

## The Full Journey

The complete story — every decision, every mistake, every fix — is documented in the blog:
<div class="-mt-3">
<a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-gray-900 text-white font-semibold hover:bg-gray-700 transition-colors no-underline">
  📖 Data Engineer's Diary
</a>
</div>

## Support This Project

This dashboard is free to use and updated every day. If you find it useful, consider buying me a coffee.
<div class="-mt-3">
<a href="https://revolut.me/salihugurkimilli" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors no-underline">
  Support via Revolut
</a>
</div>

## Share an Idea

Have a suggestion for the dashboard? Open an issue on GitHub — no account needed beyond a free sign-up.

<div class="-mt-3">
<a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new?template=suggestion.md" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-teal-600 text-white font-semibold hover:bg-teal-700 transition-colors no-underline">
  Share a Suggestion
</a>
</div>

## Part of Krogvad Analytics Hub

This dashboard is one of several data products under the Krogvad Analytics Hub.

<div class="-mt-3">
<a href="https://krogvadanalyticshub.vercel.app/" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-indigo-600 text-white font-semibold hover:bg-indigo-700 transition-colors no-underline">
  Krogvad Analytics Hub
</a>
</div>

## Connect

Happy to chat about the project, data behind it, or the design choices along the way. Let's connect!

<div class="-mt-3">
<a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors no-underline">
  LinkedIn — Salih Ugur Kimilli
</a>
</div>

```sql last_updated
select * from ligamx.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
