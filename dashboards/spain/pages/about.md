---
sidebar: never
hide_toc: true
title: About This Project
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into insights. This site started life as [Superliga Analytics](https://saugki1773.github.io/data-engineering-blog/) — an end-to-end data engineering project for Danish football, built entirely on free, open-source tools: no vendor lock-in, no cloud bills.

**La Liga** needed no special justification. It is one of the most-watched leagues in the world, and after a Danish league, a Scottish one, a Mexican one and a Turkish one, the pipeline had been proven against enough odd shapes — a championship split, two tournaments and a knockout, a league that keeps changing size — that a straight 20-club double round-robin was the easy part. What it offered instead was depth: six full seasons, 380 matches each, every one of them complete.

These sites are not standalone projects. Each one is a data product under [**Krogvad Analytics Hub**](https://krogvadanalyticshub.vercel.app/), sharing a single warehouse and a single nightly pipeline, and the plan for the Hub has always been worldwide.

That's how this site was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) and [Highlightly](https://soccer.highlightly.net/) into a **MotherDuck** cloud data warehouse
- Conforms both providers onto shared keys, so a club is one club no matter who reported it
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

```sql last_updated
select * from spain.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
