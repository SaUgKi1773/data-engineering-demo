# Gold Layer Design — Transfers

**Status:** Draft for review · **Source:** `silver.transfers` (5,486 rows) · **Target schema:** `gold`

A Kimball star for player transfers, built on the existing gold conventions:
integer surrogate keys via `ROW_NUMBER()` (incremental-safe), special members
`-1 = Unknown` / `-2 = Not Applicable` injected by `post_hook`, role-playing
dimensions as views, no NULLs in dimension attributes, business-friendly names.

---

## 1. Star overview

```
                 dim_date          dim_transfer_status
                    │                     │
   dim_player ──── fct_team_transfers ──── dim_transfer_type
                    │        │
              dim_team   dim_transfer_partner_team (role view → dim_team)
```

- **Fact:** `fct_team_transfers` — club-centric, one row per club per transfer, mirroring `fct_team_matches`.
  League-agnostic: no "internal/external" notion — every club a transfer references gets a row.
- **New objects:** `fct_team_transfers`, `dim_transfer_type`, `dim_transfer_partner_team`, `dim_transfer_status`.
- **Conformed (reused):** `dim_date`, `dim_player`, `dim_team` (extended to hold every club a transfer references).

---

## 2. Fact — `fct_team_transfers`

> **Grain: one row per (transfer, club) — each transfer emits one row per club involved.**

- A standard two-club move → **2 rows**: selling club (`from_team`, Outgoing) and buying club
  (`to_team`, Incoming) — exactly like a match emits 2 rows.
- League-agnostic: there is **no internal/external distinction**. Every club a transfer references
  gets a row, and `dim_team` carries every such club. The model scales unchanged to other leagues.
- `from_team` is always present → an Outgoing row is always emitted. An Incoming row is emitted only
  when `to_team` is a **real club** (not null, not a placeholder). The Outgoing row's partner then
  resolves as: real `to_team` → its SK; `"Retired"` placeholder (`career_ended`) → `-2` Not
  Applicable; `"TBC"` placeholder or null `to_team` → `-1` Unknown (149 + 8 + 5 = 162 null rows).

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
| `transfer_type_sk` | INTEGER | FK → `dim_transfer_type` | resolves mechanism, direction **and** career-ending |
| `transfer_status_sk` | INTEGER | FK → `dim_transfer_status` | completed vs pending |
| `transfer_count` | INTEGER | measure (additive) | constant `1` |
| `transfer_fee_eur` | BIGINT | measure | deal value; **NULL when undisclosed** (never 0) |

> Agreed — `transfer_fee_eur` is the single fee measure. The earlier `fee_paid` / `fee_received` /
> `net_spend` columns are dropped: they were derivable, and with direction on `dim_transfer_type`
> they add no information. Net spend per club is a one-line BI expression —
> `SUM(CASE WHEN transfer_direction = 'Incoming' THEN transfer_fee_eur ELSE -transfer_fee_eur END)`
> grouped by `team_sk` — not a stored, maintained column.

### Row-generation logic

For each `silver.transfers` row, emit one row per club side that has a team:

| Side | Emit when | `team_sk` | `transfer_partner_team_sk` | direction |
|---|---|---|---|---|
| Selling side (`from_team`) | always (never null) | `from_team_id` | real `to_team` → its SK; `"Retired"` → `-2`; `"TBC"`/null → `-1` | Outgoing |
| Buying side (`to_team`) | `to_team` is a real club | `to_team_id` | `from_team_id` | Incoming |

Implemented as a `UNION ALL` of the two sides. No tracked/scope filter — a row is emitted for every
side that is a real club.

### Measure semantics (additivity)

- `transfer_count` — fully additive.
- `transfer_fee_eur` — stays **NULL** when undisclosed so `AVG`/`MAX` are honest, and `SUM` ignores
  undisclosed fees rather than treating them as €0. Because each transfer appears once per club, a
  **global** fee total is taken with a direction filter, e.g.
  `SUM(transfer_fee_eur) WHERE transfer_direction = 'Incoming'` — each transfer counted exactly once
  (see §6).

---

## 3. `dim_team` — extended (conformed)

`dim_team` is the conformed club dimension. Today it is sourced only from `ref('teams')` (the clubs
we ingest in detail). Transfers reference additional clubs we don't ingest in detail (e.g. foreign
buyers/sellers), so every club a transfer references must also exist here. Keep all existing columns
and the `-1`/`-2` members, and `UNION ALL` the additional clubs:

- Detailed clubs: unchanged, full attributes from `ref('teams')` / `ref('team_names')`.
- Transfer-only clubs: distinct `from_team_id`/`to_team_id` from `silver.transfers` not already
  present, with `team_name` / `team_logo` / `team_country` from the embedded `fromteam`/`toteam`
  fields. Attributes the transfer payload doesn't carry (`team_venue_name`, `team_venue_city`,
  `team_venue_capacity`, `team_founded_year`, `team_code`, `team_short_name`) → `'Not Applicable …'`
  text (**no NULLs**).
- `placeholder = true` clubs (e.g. "TBC") are **not** admitted — they resolve to `-1`.
- **No scope flag** — there is no internal/external distinction; a club is a club.

SK assignment continues the existing incremental `MAX(team_sk)+ROW_NUMBER()` scheme so existing
SKs are stable and newly-referenced clubs get new positive SKs.

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
9 business rows + `-1` / `-2`. Natural drill path:
**`transfer_basis` → `transfer_nature` → `transfer_type_name`**.

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
| 9 | Retirement | Outgoing | Retirement | Career End | false |
| -1 | Unknown | Unknown | Unknown | Unknown | false |
| -2 | Not Applicable | Not Applicable | Not Applicable | Not Applicable | false |

**Source mapping** (`silver.transfers` → row), by source `type_name` and `career_ended`, split by
whether the club is `to_team` (Incoming) or `from_team` (Outgoing):

| Source `type_name` | `career_ended` | `transfer_nature` | Incoming row | Outgoing row |
|---|---|---|---|---|
| `Transfer` | false | Permanent | 1 | 2 |
| `Free Transfer` | false | Free | 3 | 4 |
| `Loan` | false | Loan | 5 | 6 |
| `End of loan` | false | Loan Return | 7 | 8 |
| `Transfer` | true | Retirement | — (no club) | 9 |

Notes:
- **Retirement** carries the silver `career_ended` flag. In the data these 54 rows are all a
  `Transfer` whose `to_team` is the placeholder club **"Retired"** (id `268821`, `placeholder=true`)
  with a NULL fee — the player leaves football, no club gains him. So it is **Outgoing-only**: one
  row from the last club, partner `-2 Not Applicable`, **no Incoming row** (§2).
- `transfer_basis` rolls **Free up to Permanent** (a free transfer is a permanent move with no
  fee) — the economically correct binary. `Retirement` is its own basis (`Career End`), as it is
  neither a permanent move to another club nor a loan.
- `is_fee_bearing` is true only for `Permanent` (matches the silver note that `amount` is
  populated only for a subset of permanent moves).
- Rows 7–9 labels are tunable — "End of loan" and the retirement placeholder are inherently fuzzy.

Build as a small static model (`VALUES` / seed-style), incremental-safe SKs, `-1` / `-2` members via `post_hook`.

---

## 6. Global fee totals — handled by a direction filter

Each transfer appears once per club, so a naive `SUM(transfer_fee_eur)` over the whole fact
double-counts two-club moves. This is **not a real limitation**: every transfer has exactly one
Incoming row and one Outgoing row, so filtering on direction counts each transfer once —

```sql
-- correct global fee total
SELECT SUM(transfer_fee_eur)
FROM fct_team_transfers
WHERE transfer_direction = 'Incoming';
```

The fee lives on a single measure (`transfer_fee_eur`) and `dim_transfer_type.transfer_direction`
does the de-duplication. No atomic side-fact is needed.
---

## 7. `dim_transfer_status` — completed vs pending

Scoped to deal state only, per review — `career_ended` moved to `dim_transfer_type`
(§5, `is_career_ending`). 2 business rows + members.

| `transfer_status_sk` | `transfer_status` |
|---|---|
| 1 | Completed |
| 2 | Pending |
| -1 | Unknown |
| -2 | Not Applicable |

- `transfer_status` from `silver.transfers.completed` (`true → Completed`, `false → Pending`).
- Adds `transfer_status_sk` FK to the fact.
---

## 8. Open items for review (round 2)

1. Overall model & grain sign-off (now one row per club per transfer, league-agnostic).
2. `career_ended` treatment — modeled as a single Outgoing-only `Retirement` type (`to_team` is the
   "Retired" placeholder; player leaves football). Confirm.
3. `dim_transfer_type` label wording — rows 7–8 (`Returning from Loan` / `Loan Spell Ended`) and
   row 9 (`Retirement`).

---

## 9. Build order (once approved) — dev target only

1. Extend `dim_team` (add clubs referenced only by transfers).
2. `dim_transfer_partner_team` (role view).
3. `dim_transfer_type` and `dim_transfer_status`.
4. `fct_team_transfers`.
5. Singular tests (direction/grain uniqueness, partner resolution, fee only on `is_fee_bearing` types)
   + `_schema.yml` entries.

> No prod writes. Build and validate against the dev target; prod only on explicit approval.
