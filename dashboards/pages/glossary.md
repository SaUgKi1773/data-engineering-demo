---
sidebar: never
hide_toc: true
title: Data Glossary
---

# Data Glossary

A reference for all metrics, abbreviations, and KPIs used across the dashboard.

---

## Standings Abbreviations

<div class="overflow-x-auto">

| Abbreviation | Full Name | Description |
|---|---|---|
| **MP** | Matches Played | Total number of matches played in the season |
| **W** | Wins | Matches won |
| **D** | Draws | Matches drawn |
| **L** | Losses | Matches lost |
| **GF** | Goals For | Total goals scored |
| **GA** | Goals Against | Total goals conceded |
| **GD** | Goal Difference | GF − GA |
| **Pts** | Points | 3 per win, 1 per draw, 0 per loss |

</div>

---

## Match & Performance Metrics

<div class="overflow-x-auto">

| Metric | Description | Formula |
|---|---|---|
| **Goals Scored / Match** | Average goals scored per game | Goals Scored ÷ Matches Played |
| **Goals Conceded / Match** | Average goals conceded per game | Goals Conceded ÷ Matches Played |
| **Win Rate (%)** | Percentage of matches won | (Wins ÷ Matches Played) × 100 |
| **Clean Sheets** | Matches where the team conceded zero goals | Count of matches with Goals Conceded = 0 |
| **Points Per Game** | Average points earned per match | Total Points ÷ Matches Played |

</div>

---

## Shooting Metrics

<div class="overflow-x-auto">

| Metric | Abbreviation | Description | Formula |
|---|---|---|---|
| **Shots on Goal** | SoG | Shots that were on target (required a save or resulted in a goal) | — |
| **Shot Conversion (%)** | Shot Conv % | Share of total shots that resulted in a goal | (Goals ÷ Total Shots) × 100 |
| **On-Target Conversion (%)** | On-Target Conv. | Share of on-target shots that resulted in a goal | (Goals ÷ Shots on Goal) × 100 |

</div>

---

## Advanced Metrics

<div class="overflow-x-auto">

| Metric | Abbreviation | Description | Formula |
|---|---|---|---|
| **Expected Goals** | xG | A model-based estimate of how many goals a team was expected to score, based on the quality of chances created. Values above 1.0 per match indicate strong attacking play. | Provided by api-football.com |
| **xG Overperformance** | xG OP | How many more (or fewer) goals a team scored compared to what their chances were worth. Positive = clinical finishing; negative = wasteful. | Goals Scored − xG |
| **Average xG / Match** | Avg xG | Average expected goals per match | Total xG ÷ Matches Played |

</div>

---

## Passing & Possession

<div class="overflow-x-auto">

| Metric | Abbreviation | Description | Formula |
|---|---|---|---|
| **Possession (%)** | Poss % | Share of total ball possession in a match | Provided by api-football.com |
| **Pass Accuracy (%)** | Pass Acc | Share of passes that reached a teammate | (Accurate Passes ÷ Total Passes) × 100 |

</div>

---

## Discipline Metrics

<div class="overflow-x-auto">

| Metric | Abbreviation | Description |
|---|---|---|
| **Yellow Cards** | YC | Cautions issued during a match |
| **Red Cards** | RC | Dismissals issued during a match (includes second yellows) |
| **Fouls** | — | Fouls committed by a team in a match |
| **Aggression Index** | — | A weighted composite of fouls and cards per match. Higher values indicate more physical or aggressive play. |

</div>

**Aggression Index formula:**

```
Aggression Index = (Fouls + Yellow Cards × 5 + Red Cards × 15) ÷ Matches Played
```

---

## Goalkeeper Metrics

<div class="overflow-x-auto">

| Metric | Abbreviation | Description |
|---|---|---|
| **Saves / Match** | Avg Saves | Average number of saves made by the goalkeeper per match |

</div>

---

## Other

<div class="overflow-x-auto">

| Term | Description |
|---|---|
| **Home / Away** | Whether the team played at their own stadium (Home) or at the opponent's stadium (Away) |
| **Kick-Off Time** | Local Danish time the match started |
| **Round** | The matchday or round number within the season |
| **Season** | Displayed as e.g. 2025/26, referring to the football season that started in 2025 |

</div>
