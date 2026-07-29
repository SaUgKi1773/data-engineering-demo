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

Then, over dinner, a friend made a case I hadn't expected: *you should do Liga MX — the structure is completely different from anything you've got.* He was right, and that was exactly the appeal. Two tournaments inside a single season, each with its own table and its own champion. A knockout — the **liguilla** — that decides the title, so topping the table wins you nothing but a seeding. A play-in round that has changed format twice in five years. Almost everything the pipeline quietly assumed about "a league season" turned out to be a European assumption rather than a football one.

There was a bigger reason too. These sites are not standalone projects — each one is a data product under [**Krogvad Analytics Hub**](https://krogvadanalyticshub.vercel.app/), sharing a single warehouse and a single nightly pipeline. The plan for the Hub has always been worldwide. Mexico was a genuinely good candidate: a big league, a distinctive shape, an audience that isn't mine.

That's how this site was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) and [Highlightly](https://soccer.highlightly.net/) into a **MotherDuck** cloud data warehouse
- Conforms both providers onto shared keys, so a club is one club no matter who reported it
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

```sql last_updated
select * from ligamx.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
