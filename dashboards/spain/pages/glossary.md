---
sidebar: never
hide_toc: true
title: Data Glossary
---

<script>
  import SiteFooter from '../../components/SiteFooter.svelte';
</script>

<p style="font-size:0.75rem;color:#6b7280;margin:0 0 1.5rem 0;font-style:italic;">Reference for every metric, abbreviation and format term used across the dashboard. Formulas shown in grey where applicable.</p>

---

## Competition Format

La Liga is a conventional European league season, with one wrinkle worth knowing: it does not settle ties on goal difference.

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Season</div><div class="text-sm text-gray-500 mt-0.5">Shown as e.g. <strong>2025/26</strong>, running August to May. One table, one champion. Every filter on this site operates on one season at a time.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Format</div><div class="text-sm text-gray-500 mt-0.5">A double round-robin — every club plays every other club home and away — with the club top of the table at the end crowned champion. No split, no play-off, no second phase.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Season Length</div><div class="text-sm text-gray-500 mt-0.5">Fixed. Twenty clubs, 38 rounds, 380 matches — the same in every season on this site, so season totals are directly comparable from one year to the next.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Round</div><div class="text-sm text-gray-500 mt-0.5">The matchday number within the season, counting from 1. Every match on this site belongs to one.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Tiebreak</div><div class="text-sm text-gray-500 mt-0.5">Clubs level on points are separated by their record against each other — a mini-table of just those clubs, points first and then goal difference within it — before overall goal difference is consulted at all. It decides real positions: in 2020/21 Granada finished 9th ahead of Athletic Club on the same 46 points with a goal difference 22 worse (−18 against +4). The two split their meetings — Granada won 2–0, Athletic won the return 2–1 — so they were level on head-to-head points, and Granada took it on head-to-head goal difference.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">At Stake</div><div class="text-sm text-gray-500 mt-0.5">The top of the table takes Spain's Champions League places, entering at the league phase rather than through qualifying, with the places below going to the Europa and Conference Leagues. At the other end the bottom three are relegated to the Segunda División.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Points Deductions</div><div class="text-sm text-gray-500 mt-0.5">Not applied here. Every table on this site is built from match results rather than a published table, so any points docked by the federation would be absent. No deduction is known to affect the seasons covered here, but that is the reason a table on this site could differ from the official one.</div></div>
</div>

---

## Standings Abbreviations

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">MP / GP</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Matches Played — matches played in the selected season</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">W</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Wins — matches won</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">D</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Draws — matches drawn</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">L</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Losses — matches lost</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">GF</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Goals For — total goals scored</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">GA</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Goals Against — total goals conceded</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">GD</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Goal Difference — GF − GA</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">Pts</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Points — 3 per win, 1 per draw, 0 per loss</div></div>
  <div class="p-3 sm:grid sm:grid-cols-4 sm:gap-4"><div class="font-semibold text-sm">Table Order</div><div class="text-sm text-gray-500 sm:col-span-3 mt-0.5 sm:mt-0">Clubs are ranked on points, then on the mini-table between clubs level on points, then on overall goal difference and goals scored. The table on this site is always derived from match results rather than taken from a provider's published standings.</div></div>
</div>

---

## Goals & Shooting

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Goals</div><div class="text-sm text-gray-500 mt-0.5">Goals scored, excluding own goals unless otherwise stated</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Own Goals</div><div class="text-sm text-gray-500 mt-0.5">Goals put into a team's own net. Credited to the benefiting team's score, while the event itself names the player who scored it.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Total Shots</div><div class="text-sm text-gray-500 mt-0.5">All attempts at goal — on target, off target and blocked. Left blank rather than counted as zero when a match has no shot data recorded at all.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Shots on Goal <span class="font-normal text-gray-400">(SoG)</span></div><div class="text-sm text-gray-500 mt-0.5">Shots on target — attempts that required a save or resulted in a goal. Blocked shots are not included.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Shots off Target / Blocked</div><div class="text-sm text-gray-500 mt-0.5">Attempts that missed the frame, and attempts stopped by an outfield defender before reaching the goalkeeper</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Shot Accuracy (%) <span class="font-normal text-gray-400">(Shot Acc %)</span></div><div class="text-sm text-gray-500 mt-0.5">Share of shots that were on target — a measure of striking quality, not of scoring</div><div class="text-xs text-gray-400 mt-0.5">Shots on Goal ÷ Total Shots × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Shot Conversion (%) <span class="font-normal text-gray-400">(Shot Conv %)</span></div><div class="text-sm text-gray-500 mt-0.5">Share of shots that resulted in a goal — a measure of finishing</div><div class="text-xs text-gray-400 mt-0.5">Goals ÷ Total Shots × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Goals / Match · Goals Conceded / Match</div><div class="text-sm text-gray-500 mt-0.5">Goals scored or conceded divided by matches played in the current filter selection</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Expected Goals <span class="font-normal text-gray-400">(xG)</span></div><div class="text-sm text-gray-500 mt-0.5">The number of goals an average team would be expected to score from the same chances, based on shot quality. From 2025/26 only.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Big Chances Created</div><div class="text-sm text-gray-500 mt-0.5">High-quality scoring opportunities created — situations where a player would be expected to score. From 2025/26 only.</div></div>
</div>

---

## Passing & Possession

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Possession (%) <span class="font-normal text-gray-400">(Poss %)</span></div><div class="text-sm text-gray-500 mt-0.5">Share of total ball possession in a match, as published by the data provider</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Pass Accuracy (%) <span class="font-normal text-gray-400">(Pass Acc %)</span></div><div class="text-sm text-gray-500 mt-0.5">Share of passes that successfully reached a teammate</div><div class="text-xs text-gray-400 mt-0.5">Accurate Passes ÷ Total Passes × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Key Passes</div><div class="text-sm text-gray-500 mt-0.5">The final pass before a shot — the ball that creates a shooting opportunity, whether or not it leads to a goal. From 2025/26 only.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Expected Assists <span class="font-normal text-gray-400">(xA)</span></div><div class="text-sm text-gray-500 mt-0.5">The assists a team would be expected to record from the chances it created, based on the quality of those chances. From 2025/26 only.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Cross Accuracy (%) <span class="font-normal text-gray-400">(Cross Acc %)</span></div><div class="text-sm text-gray-500 mt-0.5">Share of crosses — deliveries from wide areas into the box — that found a teammate. From 2025/26 only.</div><div class="text-xs text-gray-400 mt-0.5">Accurate Crosses ÷ Total Crosses × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Passes into Final Third</div><div class="text-sm text-gray-500 mt-0.5">Passes that carry the ball into the attacking third of the pitch. From 2025/26 only.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Dribble Success (%)</div><div class="text-sm text-gray-500 mt-0.5">Share of attempts to carry the ball past an opponent that succeeded. From 2025/26 only.</div><div class="text-xs text-gray-400 mt-0.5">Dribbles Completed ÷ Dribbles Attempted × 100</div></div>
</div>

---

## Defending

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Clean Sheet (%)</div><div class="text-sm text-gray-500 mt-0.5">Share of matches in which the team conceded nothing. Expressed as a rate rather than a count so it stays comparable when the match filters narrow the selection.</div><div class="text-xs text-gray-400 mt-0.5">Matches with 0 Conceded ÷ Matches Played × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Saves</div><div class="text-sm text-gray-500 mt-0.5">Shots on target stopped by the goalkeeper. Available for every season.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Tackle Success (%)</div><div class="text-sm text-gray-500 mt-0.5">Share of tackle attempts that won the ball. From 2025/26 only.</div><div class="text-xs text-gray-400 mt-0.5">Tackles Won ÷ Total Tackles × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Interceptions</div><div class="text-sm text-gray-500 mt-0.5">Passes cut out before reaching their intended target. From 2025/26 only.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Clearances</div><div class="text-sm text-gray-500 mt-0.5">Balls hacked away from a team's own danger area without the intent to find a teammate. From 2025/26 only.</div></div>
</div>

---

## Dueling & Discipline

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Aerial Success (%)</div><div class="text-sm text-gray-500 mt-0.5">Share of aerial duels — contests for the ball in the air — that the team won. From 2025/26 only.</div><div class="text-xs text-gray-400 mt-0.5">Aerial Duels Won ÷ Total Aerial Duels × 100</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Fouls</div><div class="text-sm text-gray-500 mt-0.5">Fouls committed by a team. Available for every season.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Offsides</div><div class="text-sm text-gray-500 mt-0.5">Times a team was caught offside</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Yellow Cards <span class="font-normal text-gray-400">(YC)</span></div><div class="text-sm text-gray-500 mt-0.5">Cautions received during a match</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Red Cards <span class="font-normal text-gray-400">(RC)</span></div><div class="text-sm text-gray-500 mt-0.5">Dismissals received during a match, including second yellows</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Penalty Success (%)</div><div class="text-sm text-gray-500 mt-0.5">Share of penalties taken that were scored. Penalties awarded and missed are both carried in the event stream.</div><div class="text-xs text-gray-400 mt-0.5">Penalties Scored ÷ Penalties Taken × 100</div></div>
</div>

---

## Team Radar Scores

Each of the six radar axes is a **composite score** for the selected season, ranging from 0 (worst in the league) to 100 (best).

The calculation has two steps: every underlying measure is percent-ranked across all clubs in the selection, then those ranks are averaged into a composite in which one **anchor measure** carries double weight. A final rank-normalisation means each axis always has exactly one club at 100 and one at 0, however close the field actually is.

Rates are preferred over volumes throughout, so a club under constant pressure is not rewarded for the sheer number of defensive actions it is forced into.

**An axis can be blank.** Four of the six are built on measures that start in 2025/26. When a filter selects earlier seasons, that axis is drawn at the centre with an em dash rather than being scored — an unscored axis is shown as unknown, never as zero.

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3">
    <div class="font-semibold text-sm">Attacking</div>
    <div class="text-sm text-gray-500 mt-0.5">Goal threat and shooting volume. Anchor: <strong>goals per match</strong> (2× weight). Supporting: shots on goal per match, shot accuracy %, corners per match. Available for every season.</div>
    <div class="text-xs text-gray-400 mt-0.5">(2×goals + sog + shot_acc% + corners) ÷ 5</div>
  </div>
  <div class="p-3">
    <div class="font-semibold text-sm">Creativity</div>
    <div class="text-sm text-gray-500 mt-0.5">Chance creation and delivery. Anchor: <strong>big chances created per match</strong> (2× weight). Supporting: expected assists per match, key passes per match, cross accuracy %, passes into the final third per match. From 2025/26 only.</div>
    <div class="text-xs text-gray-400 mt-0.5">(xa + 2×big_chances + key_passes + cross_acc% + passes_final_third) ÷ 6</div>
  </div>
  <div class="p-3">
    <div class="font-semibold text-sm">Possession & Control</div>
    <div class="text-sm text-gray-500 mt-0.5">Ball retention and carrying. Anchor: <strong>pass accuracy %</strong> (2× weight). Supporting: average possession %, dribble success %. Needs dribble data, so from 2025/26 only.</div>
    <div class="text-xs text-gray-400 mt-0.5">(possession% + 2×pass_acc% + dribble_success%) ÷ 4</div>
  </div>
  <div class="p-3">
    <div class="font-semibold text-sm">Defending</div>
    <div class="text-sm text-gray-500 mt-0.5">Defensive solidity. Anchor: <strong>goals conceded per match</strong> (2× weight, inverted — fewer is better). Supporting: tackle success %, interceptions per match, clearances per match, saves per match. From 2025/26 only.</div>
    <div class="text-xs text-gray-400 mt-0.5">(2×conceded↓ + tackle_success% + interceptions + clearances + saves) ÷ 6</div>
  </div>
  <div class="p-3">
    <div class="font-semibold text-sm">Physicality</div>
    <div class="text-sm text-gray-500 mt-0.5">Aerial presence and control of the foul count. Anchor: <strong>aerial success %</strong> (2× weight). Supporting: aerial duels per match, fouls per match (inverted — fewer is better). From 2025/26 only.</div>
    <div class="text-xs text-gray-400 mt-0.5">(2×aerial_success% + aerial_duels + fouls↓) ÷ 4</div>
  </div>
  <div class="p-3">
    <div class="font-semibold text-sm">Winning</div>
    <div class="text-sm text-gray-500 mt-0.5">Match-winning ability. A single measure — win rate — with no composite averaging, because the outcome speaks for itself. Available for every season.</div>
    <div class="text-xs text-gray-400 mt-0.5">Wins ÷ Matches Played</div>
  </div>
</div>

---

## Match Timing & Game State

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">15-Minute Interval</div><div class="text-sm text-gray-500 mt-0.5">Match events are bucketed by the minute they occurred — 1–15, 16–30, and so on. Stoppage time is counted separately as <strong>45+</strong> and <strong>90+</strong> rather than being folded into the preceding bucket.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Half-Time vs Full-Time</div><div class="text-sm text-gray-500 mt-0.5">The score at the interval compared with the final score — the basis for reading how matches turn after the break</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Trailing / Led</div><div class="text-sm text-gray-500 mt-0.5"><strong>Trailing</strong> means the team was behind at any point in the match, not only at half-time. <strong>Led</strong> is the mirror — ahead at any point.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Comeback Wins</div><div class="text-sm text-gray-500 mt-0.5">Matches won after having trailed at some point</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Points from Trailing</div><div class="text-sm text-gray-500 mt-0.5">Points collected in matches where the team fell behind — a measure of what a squad rescues rather than what it protects</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Leads Lost</div><div class="text-sm text-gray-500 mt-0.5">Matches lost despite having led at some point</div></div>
  <div class="p-3"><div class="font-semibold text-sm">VAR Review</div><div class="text-sm text-gray-500 mt-0.5">A recorded video review during a match. Review counts run from 2020/21; what each review decided is categorised from 2024/25.</div></div>
</div>

---

## Predictions

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Predicted Result</div><div class="text-sm text-gray-500 mt-0.5">The outcome the model considers most likely — home win, draw or away win — with the probability it assigns to each</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Predicted Goals</div><div class="text-sm text-gray-500 mt-0.5">The scoreline the model expects for the fixture</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Accuracy by Round</div><div class="text-sm text-gray-500 mt-0.5">Share of completed matches in each round where the predicted result matched the actual one</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Expected Points / Projected</div><div class="text-sm text-gray-500 mt-0.5">Points a club is forecast to add over its remaining fixtures, from the model's probabilities. On the cumulative chart, the solid line is points actually earned and the projected line continues it to the end of the season.</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Pending / Completed</div><div class="text-sm text-gray-500 mt-0.5">Whether a prediction concerns a fixture still to be played, or one that has finished and can be scored against the result</div></div>
</div>

---

## Context & Navigation

<div class="divide-y divide-gray-100 rounded-xl border border-gray-200 overflow-hidden">
  <div class="p-3"><div class="font-semibold text-sm">Home / Away <span class="font-normal text-gray-400">(H/A)</span></div><div class="text-sm text-gray-500 mt-0.5">Whether the club played at its own ground or the opponent's</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Kick-off</div><div class="text-sm text-gray-500 mt-0.5">Match start time in local Spanish time (CET/CEST, UTC+1 in winter and UTC+2 in summer)</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Time Slot</div><div class="text-sm text-gray-500 mt-0.5">Kick-off grouped into five windows: Morning (05:00–10:59) · Noon (11:00–13:59) · Afternoon (14:00–17:59) · Evening (18:00–20:59) · Night (21:00–04:59)</div></div>
  <div class="p-3"><div class="font-semibold text-sm">Stadium / City / Referee</div><div class="text-sm text-gray-500 mt-0.5">Venue and officiating details for a match, where published</div></div>
</div>

```sql last_updated
select * from spain.last_updated
```

<SiteFooter lastUpdated={last_updated[0]?.last_updated} />
