# Measure Catalogue

This document defines all facts and calculated measures used across the data model and dashboards. Facts are sourced from `mart_match_facts` and `mart_player_facts`. Grain is annotated per fact: **T** = team level, **P** = player level, **B** = both.

---

## 1. Attacking

Raw facts that describe goal threat and finishing.

| Fact | Grain |
|---|---|
| `goals_scored` | B |
| `shots_total` | B |
| `shots_on_target` | B |
| `shots_off_target` | B |
| `shots_blocked` | B |
| `woodwork_hits` | B |
| `big_chances_missed` | B |
| `penalty_scored` | B |
| `penalty_missed` | B |

### Calculated Measures

| Measure | Formula |
|---|---|
| Shot Accuracy % | `SUM(shots_on_target) / NULLIF(SUM(shots_total), 0)` |
| Shot Conversion % | `SUM(goals_scored) / NULLIF(SUM(shots_total), 0)` |
| On-Target Conversion % | `SUM(goals_scored) / NULLIF(SUM(shots_on_target), 0)` |
| Penalty Success % | `SUM(penalty_scored) / NULLIF(SUM(penalty_scored) + SUM(penalty_missed), 0)` |
| Non-Penalty Goals | `SUM(goals_scored) - SUM(penalty_scored)` |

---

## 2. Creativity & Playmaking

Facts describing chance creation, passing, and delivery.

| Fact | Grain |
|---|---|
| `assists` | P |
| `big_chances_created` | B |
| `chances_created` | B |
| `passes_total` | B |
| `passes_accurate` | B |
| `key_passes` | P |
| `crosses_total` | B |
| `crosses_accurate` | B |

### Calculated Measures

| Measure | Formula |
|---|---|
| Pass Accuracy % | `SUM(passes_accurate) / NULLIF(SUM(passes_total), 0)` |
| Cross Accuracy % | `SUM(crosses_accurate) / NULLIF(SUM(crosses_total), 0)` |
| Chance Quality Ratio | `SUM(big_chances_created) / NULLIF(SUM(chances_created), 0)` — what share of created chances were clear-cut |

> **Note:** Previously called "Expected Assist Trigger (EAT)". Renamed because it measures the quality ratio of created chances, not an expected-value metric.

---

## 3. Possession & Ball Carrying

Facts describing control, movement, and set-piece pressure.

| Fact | Grain |
|---|---|
| `possession_pct` | T |
| `dribbles_attempts` | P |
| `dribbles_completed` | P |
| `fouls_drawn` | P |
| `offsides` | B |
| `corner_kicks` | T |

### Calculated Measures

| Measure | Formula |
|---|---|
| Avg Possession % | `AVG(possession_pct)` |
| Dribble Success % | `SUM(dribbles_completed) / NULLIF(SUM(dribbles_attempts), 0)` |

---

## 4. Defending & Duels

Facts describing defensive actions and physical contests.

| Fact | Grain |
|---|---|
| `tackles` | B |
| `tackles_won` | B |
| `clearances` | B |
| `interceptions` | B |
| `blocks` | B |
| `aerials_won` | B |
| `aerials_lost` | B |
| `duels_total` | B |
| `duels_won` | B |
| `fouls_committed` | B |

### Calculated Measures

| Measure | Formula |
|---|---|
| Tackle Success % | `SUM(tackles_won) / NULLIF(SUM(tackles), 0)` |
| Aerial Duel Success % | `SUM(aerials_won) / NULLIF(SUM(aerials_won) + SUM(aerials_lost), 0)` |
| Total Duel Success % | `SUM(duels_won) / NULLIF(SUM(duels_total), 0)` |

---

## 5. Goalkeeping & Errors

Facts specific to goalkeeper performance and defensive mistakes.

| Fact | Grain |
|---|---|
| `goals_conceded` | T |
| `saves` | P |
| `saves_inside_box` | P |
| `errors_leading_to_goal` | P |

### Calculated Measures

| Measure | Formula |
|---|---|
| Save % | `SUM(saves) / NULLIF(SUM(saves) + SUM(goals_conceded), 0)` |
| Box Save Ratio | `SUM(saves_inside_box) / NULLIF(SUM(saves), 0)` |

---

## 6. Discipline

Facts describing cards and foul behaviour.

| Fact | Grain |
|---|---|
| `yellow_cards` | B |
| `yellow_red_cards` | B |
| `red_cards` | B |

### Calculated Measures

| Measure | Formula |
|---|---|
| Total Dismissals | `SUM(red_cards) + SUM(yellow_red_cards)` |
| Fouls Per Card | `SUM(fouls_committed) / NULLIF(SUM(yellow_cards) + SUM(red_cards) + SUM(yellow_red_cards), 0)` |

---

## 7. Match Context

Facts describing match-level outcomes and timing. All are team-grain only.

| Fact | Grain |
|---|---|
| `minutes_played` | P |
| `points_earned` | T |
| `goals_ht_scored` | T |
| `goals_ht_conceded` | T |

### Calculated Measures

| Measure | Formula |
|---|---|
| Goal Difference | `SUM(goals_scored) - SUM(goals_conceded)` |
| Half-Time Goal Difference | `SUM(goals_ht_scored) - SUM(goals_ht_conceded)` |
| Points Per Game (PPG) | `AVG(points_earned)` |

---

## 8. Performance

Player-level quality scores. Kept separate because they are composite outputs, not raw event counts.

| Fact | Grain |
|---|---|
| `rating` | P |

### Calculated Measures

| Measure | Formula |
|---|---|
| Avg Player Rating | `AVG(rating)` |

---

## Per-90 Normalisation

For any player-grain counting fact, a per-90 variant can be derived as:

```
fact / NULLIF(minutes_played, 0) * 90
```

Priority candidates: `goals_scored`, `assists`, `shots_total`, `key_passes`, `big_chances_created`, `tackles`, `interceptions`.

---

## Display Order by Context

### Match Analysis — Team Comparison

Group and order stats as follows when presenting a head-to-head match view:

1. **Attacking:** Goals → Total Shots → Shots on Goal → Big Chances → Woodwork Hits
2. **Possession:** Possession % → Pass Accuracy → Corners → Offsides
3. **Defending:** Tackles → Saves
4. **Discipline:** Fouls → Yellow Cards → Red Cards

### Player Popup — Stat Sheet

Order stats for a player detail view as follows (only show stats > 0):

1. **Context:** Minutes Played
2. **Attacking:** Goals → Assists → Shots → Shots on Target
3. **Creativity:** Key Passes → Big Chances Created → Dribbles
4. **Defending:** Tackles → Interceptions → Clearances → Aerials Won → Blocks → Saves
5. **Discipline:** Fouls → Yellow Cards → Red Cards

> Rating is displayed separately in the popup header, not in this list.
