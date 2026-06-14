# Gold Layer Design — Transfers

**Status:** Draft for review · **Source:** `silver.transfers` (5,486 rows) · **Target schema:** `gold`

A Kimball star for player transfers, built on the existing gold conventions:
integer surrogate keys via `ROW_NUMBER()` (incremental-safe), special members
`-1 = Unknown` / `-2 = Not Applicable` injected by `post_hook`, role-playing
dimensions as views, no NULLs in dimension attributes, business-friendly names.

---

## 1. Star overview

```
                 dim_date
                    │
   dim_player ──── fct_team_transfers ──── dim_transfer_type
                    │        │
              dim_team   dim_transfer_partner_team (role view → dim_team)
                    │
        (+ dim_transfer_status — optional junk dim)
```

- **Fact:** `fct_team_transfers` — one *perspective* fact, club-centric, mirroring `fct_team_matches`.
- **New objects:** `fct_team_transfers`, `dim_transfer_type`, `dim_transfer_partner_team`, (optional) `dim_transfer_status`.
- **Conformed (reused):** `dim_date`, `dim_player`, `dim_team` (extended).

---

## 2. Fact — `fct_team_transfers`

> **Grain: one row per tracked (Superliga) club, per transfer that club was a party to.**

- Intra-league move (both clubs tracked) → **2 rows** (one per club), exactly like a match emits 2 rows.
- Move involving an external club → **1 row** (only the tracked side).
- "Tracked" is resolved at build time from `ref('teams')` — it is **not** a stored attribute.

**Materialization:** `incremental`, `delete+insert`, `unique_key = ['transfer_id', 'team_sk']`,
`{{ gold_incremental_filter() }}` in the incremental `WHERE` (house pattern).

### Columns

| Column | Type | Kind | Source / rule |
|---|---|---|---|
| `transfer_id` | BIGINT | degenerate dim | `silver.transfers.id` (event natural key) |
| `date_sk` | INTEGER | FK → `dim_date` | `COALESCE(dd.date_sk, -1)` on `transfer_date` |
| `team_sk` | INTEGER | FK → `dim_team` | the tracked club (subject side) |
| `transfer_partner_team_sk` | INTEGER | FK → `dim_transfer_partner_team` | the other club (role view) |
| `player_sk` | INTEGER | FK → `dim_player` | `COALESCE(dp.player_sk, -1)` |
| `transfer_type_sk` | INTEGER | FK → `dim_transfer_type` | resolves mechanism **and** direction |
| `transfer_count` | INTEGER | measure (additive) | constant `1` |
| `transfer_fee_eur` | BIGINT | measure | deal value; **NULL when undisclosed** (never 0) |
| `fee_paid_eur` | BIGINT | measure (additive) | `transfer_fee_eur` when Incoming & disclosed, else NULL |
| `fee_received_eur` | BIGINT | measure (additive) | `transfer_fee_eur` when Outgoing & disclosed, else NULL |
| `net_spend_eur` | BIGINT | measure (additive) | `+fee` when Incoming, `−fee` when Outgoing (disclosed only) |

### Row-generation logic

For each `silver.transfers` row, emit a subject row per side that is a tracked club:

| Side | Emit when | `team_sk` | `transfer_partner_team_sk` | direction |
|---|---|---|---|---|
| Buying side (`to_team`) | `to_team_id` is tracked | `to_team_id` | `from_team_id` | Incoming |
| Selling side (`from_team`) | `from_team_id` is tracked | `from_team_id` | `to_team_id` | Outgoing |

Implemented as a `UNION ALL` of the two sides, each filtered to tracked membership.

### Measure semantics (additivity)

- `transfer_fee_eur` — stays **NULL** when undisclosed so `AVG`/`MAX` are honest. `SUM` over
  distinct transfers is additive; over the perspective fact it double-counts intra-league
  moves (see §6).
- `fee_paid_eur` / `fee_received_eur` / `net_spend_eur` — fully additive *when grouped/filtered by
  `team_sk`*. `SUM(net_spend_eur) WHERE team_sk = X` = club X's net spend. NULLs (undisclosed)
  are ignored by `SUM` by design — **undisclosed fees are excluded, not treated as €0**.

---

## 3. `dim_team` — extended (conformed)

Keep all existing columns and the `-1`/`-2` members. Add external clubs (transfer
counterparties, frequently foreign and absent from `ref('teams')`) via `UNION ALL`:

- In-scope clubs: unchanged, full attributes from `ref('teams')` / `ref('team_names')`.
- External clubs: distinct `from_team_id`/`to_team_id` seen in `silver.transfers`, with
  `team_name` / `team_logo` / `team_country` from the embedded `fromteam`/`toteam` fields.
  In-scope-only attributes (`team_venue_name`, `team_venue_city`, `team_venue_capacity`,
  `team_founded_year`, `team_code`, `team_short_name`) → `'Not Applicable …'` text (**no NULLs**).
- `placeholder = true` clubs (e.g. "TBC") are **not** admitted — they resolve to `-1`.
- **No scope flag** — "tracked vs external" is a build-time set, not a stored attribute.

SK assignment continues the existing incremental `MAX(team_sk)+ROW_NUMBER()` scheme so existing
in-scope SKs are stable and external clubs get new positive SKs.

---

## 4. `dim_transfer_partner_team` — role view over `dim_team`

`materialized='view'`, parallel to `dim_opponent_team`:

| Column | Source |
|---|---|
| `transfer_partner_team_sk` | `team_sk` |
| `transfer_partner_team_id` | `team_id` |
| `transfer_partner_team_name` | `team_name` |
| `transfer_partner_team_logo` | `team_logo` |
| `transfer_partner_team_country` | `team_country` |

---

## 5. `dim_transfer_type` — new

Combines mechanism **and** direction (low-cardinality, correlated → one mini-dimension).
8 business rows + `-1`. Natural drill path: **`transfer_basis` → `transfer_nature` → `transfer_type_name`**.

| `transfer_type_sk` | `transfer_type_name` | `transfer_direction` | `transfer_nature` | `transfer_basis` | `is_fee_bearing` |
|---|---|---|---|---|---|
| 1 | Permanent Signing | Incoming | Permanent | Permanent | true |
| 2 | Permanent Sale | Outgoing | Permanent | Permanent | true |
| 3 | Free Signing | Incoming | Free | Permanent | false |
| 4 | Free Departure | Outgoing | Free | Permanent | false |
| 5 | Loan In | Incoming | Loan | Loan | false |
| 6 | Loan Out | Outgoing | Loan | Loan | false |
| 7 | Returning from Loan | Incoming | Loan Return | Loan | false |
| 8 | Loan Spell Ended | Outgoing | Loan Return | Loan | false |
| -1 | Unknown | Unknown | Unknown | Unknown | false |

**Source mapping** (`silver.transfers` → row), by source `type_name` × whether the tracked club is `to_team` (Incoming) or `from_team` (Outgoing):

| Source `type_name` | `transfer_nature` | Incoming row | Outgoing row |
|---|---|---|---|
| `Transfer` | Permanent | 1 | 2 |
| `Free Transfer` | Free | 3 | 4 |
| `Loan` | Loan | 5 | 6 |
| `End of loan` | Loan Return | 7 | 8 |

Notes:
- `transfer_basis` rolls **Free up to Permanent** (a free transfer is a permanent move with no
  fee) — the economically correct binary, unlike a mechanism-only grouping.
- `is_fee_bearing` is true only for `Permanent` (matches the silver note that `amount` is
  populated only for a subset of permanent moves).
- Rows 7–8 labels are tunable — "End of loan" is an inherently ambiguous event.

Build as a small static model (`VALUES` / seed-style), incremental-safe SKs, `-1` member via `post_hook`.

---

## 6. Known caveat — league-wide fee totals

Because intra-league transfers appear twice (once per club), a **league-wide** unique fee total
(`SUM(transfer_fee_eur)` over the whole fact) double-counts them. This fact is built **for per-club
analysis** — always filter/group by `team_sk`. League totals should use `COUNT(DISTINCT transfer_id)`
or be sourced from a thin atomic fact if one is added later. (Same trade-off `fct_team_matches`
sidesteps by framing goals per-subject; here the fee is a shared event attribute, so it cannot be.)

---

## 7. Optional — `dim_transfer_status` (junk dim)

The Kimball-correct home for the two low-cardinality state flags, instead of booleans on the fact.
4 rows + members.

| `transfer_status_sk` | `deal_status` | `career_status` |
|---|---|---|
| 1 | Completed | Active |
| 2 | Completed | Career Ended |
| 3 | Pending | Active |
| 4 | Pending | Career Ended |

- `deal_status` from `silver.transfers.completed`; `career_status` from `career_ended`.
- Adds `transfer_status_sk` FK to the fact.
- **Decision needed:** include now, or omit until a use case appears?

---

## 8. Open items for review

1. Overall model & grain sign-off.
2. `dim_transfer_status` — in or out?
3. Rows 7–8 wording in `dim_transfer_type` (`Returning from Loan` / `Loan Spell Ended`).
4. Confirm `net_spend_eur` sign convention (spend positive: purchases `+`, sales `−`).

---

## 9. Build order (once approved) — dev target only

1. Extend `dim_team` (add external clubs).
2. `dim_transfer_partner_team` (role view).
3. `dim_transfer_type` (+ `dim_transfer_status` if approved).
4. `fct_team_transfers`.
5. Singular tests (fee-direction consistency, partner resolution, grain uniqueness) + `_schema.yml` entries.

> No prod writes. Build and validate against the dev target; prod only on explicit approval.
