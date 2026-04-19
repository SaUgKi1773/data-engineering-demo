---
layout: post
title: "Hitting the Limits — API Quotas and MotherDuck Memory"
date: 2026-04-18
categories: [data-engineering, infrastructure, constraints]
---

Every free tier has a ceiling. This project hit several of them in ways that were interesting enough to document separately. Some limits shaped the architecture from the start. Others appeared unexpectedly in production. All of them taught something useful.

## The 100-Call-Per-Day API Limit

api-football.com's free tier allows 100 API calls per day. This number sounds arbitrary until you start counting what a single nightly pipeline actually needs.

The incremental run fetches data for the last 5 days. Across those 5 days there might be 4 to 8 Superligaen fixtures. For each fixture, we fetch: fixture metadata (1 call), statistics (1 call), events (1 call), lineups (1 call), player stats (1 call), predictions (1 call). That is 6 calls per fixture. For 6 fixtures that is 36 calls. Then add standings (1 call), top scorers (1 call), rounds (1 call), injury data (1-2 calls). A typical incremental run consumes 40 to 50 calls.

That leaves 50 to 60 calls before the daily limit. Enough headroom for one-off corrections and the occasional full fixture reload, but not much more.

The limit has a direct architectural consequence: **the system is designed for one league**. The ingestion framework is genuinely generic — adding Turkish Süper Lig, the Danish Cup, or any other competition is a configuration change. The pipeline would handle it. The API quota would not. Adding a second league would roughly double the daily call count, leaving almost no margin for reruns.

This is a frustrating constraint because the data model and pipeline are ready to scale. The bottleneck is entirely external.

## DuckDB Version Pinning

Early in the project, the CI workflow started failing with a cryptic incompatibility error between the Python `duckdb` package and MotherDuck's server. The root cause: the duckdb package version was unpinned in `requirements.txt`, so the latest release was being installed, and the latest duckdb client was ahead of the MotherDuck server version.

MotherDuck runs a specific version of DuckDB on its cloud compute. If your local client is a newer version, the connection protocol can differ. The fix was to pin `duckdb==1.5.1` in `requirements.txt` and update it only deliberately when MotherDuck announces a server upgrade. This is standard practice for any client/server system with versioned protocols but easy to forget when you are just writing Python.

## The MotherDuck Memory Limit

The most technically interesting limit was the **953 MB memory cap** on MotherDuck's free Pulse compute tier. This was described in detail in the silver/gold post, but it is worth restating here in the context of free tier constraints.

The failure mode was specifically in the `fixture_players` model, which processes deeply nested JSON — teams containing players containing statistics. The natural DuckDB way to flatten this is nested `UNNEST` calls. In a single query with three levels of UNNEST, DuckDB needs to hold the intermediate explosion of records in memory. For a full season's worth of fixture player data, that intermediate explosion was larger than 953 MB.

What made this hard to catch in development: local DuckDB has no memory cap. The query ran fine locally and in CI (which runs `dbt compile`, not `dbt run`). It only failed in production, during a full-refresh run.

The solution — sequential CTEs that unpack one layer at a time — reduced peak memory usage dramatically because each CTE materialises its output before the next level is processed. The query took a bit longer to write but solved the problem completely.

This is a good example of a class of bugs that only appear at production scale: logic that is correct but makes assumptions about available resources that do not hold in the target environment.

## What the Architecture Was Designed For — and What It Is Not

Stepping back, the constraints above define the honest shape of this project:

**What it is:** A single-league, nightly-refresh analytics pipeline for Danish Superligaen, running entirely on free tiers.

**What it is not:** A multi-league, real-time, or high-volume data platform.

The medallion architecture, Kimball dimensional model, dbt models, and CI validation are all genuinely production-grade practices. The free tier constraints mean they are applied to a smaller domain than they could support. The code is ready to scale; the quotas are not.

If the API quota were lifted, adding more leagues would take hours. If MotherDuck memory were increased, the sequential CTE workaround could be simplified back to nested UNNESTs. If Vercel builds cost nothing to scale, the pipeline could run on match-day triggers rather than nightly. The architecture was designed with these extensions in mind, even if the current implementation is constrained.

## MotherDuck: The Overall Experience

It is worth reflecting on MotherDuck specifically because it was the part of the stack that gave the least friction throughout the project.

The onboarding is genuinely minutes. Create an account, get a token, replace the connection string with `md:` and the token, and your existing DuckDB queries run against the cloud. There is no schema migration to run, no IAM role to configure, no service account JSON to rotate. The web UI is clean and lets you run queries and browse tables interactively.

10 GB of storage on the free tier is more than enough for a Superligaen dataset — even with all the bronze JSON blobs, the database is well under 1 GB. The compute constraints (953 MB memory) are real but navigable with the right query structure.

If I were recommending a data warehouse for a side project or a prototype, MotherDuck would be my first suggestion. BigQuery is more powerful and cheaper at scale, but MotherDuck wins on time-to-first-query by a significant margin.

Next: the final chapter — launching the project publicly and adding visitor analytics.
