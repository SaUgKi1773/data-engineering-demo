---
sidebar: never
hide_toc: true
title: About This Project
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into insights. I wanted to build a real end-to-end data engineering project using only free, open-source tools — no vendor lock-in, no cloud bills. Around the same time, I had recently moved to Denmark and realised I knew very little about Danish football.

The two things clicked together: why not build an analytics product for **Superligaen**, the Danish Premier Football League? Something I could actually use myself, and that anyone curious about Danish football could benefit from too.

That's how this project was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) into a **MotherDuck** cloud data warehouse
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

```sql last_updated
select * from superligaen.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
