---
sidebar: never
hide_toc: true
title: About This Project
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into insights. This site started life as [Superliga Analytics](https://saugki1773.github.io/data-engineering-blog/) — an end-to-end data engineering project for Danish football built entirely on free, open-source tools: no vendor lock-in, no cloud bills.

Then came the first feature request from an actual user: *"I would like to see the statistics for the Scottish league too."* The data pipeline had been built league-agnostic, so the **Scottish Premiership** — with its famous split, its 38-round rhythm, and the fiercest rivalry in football — became the second league in the family.

That's how this site was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) into a **MotherDuck** cloud data warehouse
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

```sql last_updated
select * from scotland.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
