---
title: About This Project
---

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into useful insights. I wanted to build a real end-to-end data engineering project using only free, open-source tools — no vendor lock-in, no cloud bills. Around the same time, I had recently moved to Denmark and realised I knew very little about Danish football.

The two things clicked together: why not build an analytical product for **Superligaen**, the Danish Premier Football League? Something I could actually use myself, and that anyone curious about Danish football could benefit from too.

That's how this project was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [api-football.com](https://www.api-football.com/) into a **MotherDuck** cloud data warehouse
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

## The Full Journey

The complete story — every decision, every mistake, every fix — is documented in the blog:

<a href="https://saugki1773.github.io/data-engineering-demo/" target="_blank" class="inline-flex items-center gap-2 mt-2 px-5 py-3 rounded-xl bg-gray-900 text-white font-semibold hover:bg-gray-700 transition-colors no-underline">
  📖 Data Engineer's Diary
</a>

## Connect

<a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="inline-flex items-center gap-2 mt-2 px-5 py-3 rounded-xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors no-underline">
  LinkedIn — Salih Ugur Kimilli
</a>
