---
layout: home
title: "Building Superligaen Analytics"
---

This blog documents the end-to-end journey of building [Superligaen Analytics](https://superligaanalytics.vercel.app/) — a live data engineering project that ingests football data from the Danish premier league, transforms it through a medallion architecture, and serves it on a public dashboard.

The project was built in roughly **10 days** in April 2026, and almost nothing went according to the original plan. Every major tool choice had to be revisited at least once. This is the honest account of what happened, why, and what I'd do differently.

---

**Posts in order:**

1. [The Idea — Why I Built This](/data-engineering-demo/2026/04/09/the-idea.html)
2. [The Idea and Choosing a Data Source](/data-engineering-demo/2026/04/10/choosing-the-data-source.html)
3. [Building the Bronze Layer — Raw Ingestion](/data-engineering-demo/2026/04/11/building-the-bronze-layer.html)
4. [Silver and Gold — Transforming Data into a Star Schema](/data-engineering-demo/2026/04/14/silver-and-gold-layers.html)
5. [The Dashboard — Discovering Evidence.dev](/data-engineering-demo/2026/04/16/building-the-dashboard.html)
6. [The Deployment Saga — Netlify, Cloudflare, and Finally Vercel](/data-engineering-demo/2026/04/18/deployment-saga.html)
7. [Migrating to dbt — When Raw SQL Isn't Enough](/data-engineering-demo/2026/04/18/dbt-migration.html)
8. [Hitting the Limits — API Quotas and MotherDuck Memory](/data-engineering-demo/2026/04/18/hitting-the-limits.html)
9. [Global Launch and Adding Analytics](/data-engineering-demo/2026/04/19/launch-and-analytics.html)

---

**Live dashboard:** [superligaanalytics.vercel.app](https://superligaanalytics.vercel.app/)  
**Source code:** [github.com/SaUgKi1773/data-engineering-demo](https://github.com/SaUgKi1773/data-engineering-demo)
