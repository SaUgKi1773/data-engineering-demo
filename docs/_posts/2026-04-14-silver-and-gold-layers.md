---
layout: post
title: "Silver and Gold — Transforming Data into a Star Schema"
date: 2026-04-14
categories: [data-engineering, transformation, data-modeling]
---

With 21 tables of raw JSON sitting in MotherDuck, the next step was to make the data actually usable. That meant two more layers: silver (clean, structured tables) and gold (a Kimball dimensional model designed for analytics).

## Silver: Flattening the JSON

The silver layer's job is to take each bronze table and turn it into a proper relational table — extract columns from the JSON, cast types, handle nulls, and normalise nested structures. Every bronze endpoint gets a corresponding silver model.

DuckDB's JSON handling is one of its best features. You can navigate nested JSON using arrow operators and the `->>` syntax, and `UNNEST` is available for arrays. For a fixture statistics row that looks like this in bronze:

```json
{
  "fixture": {"id": 12345},
  "statistics": [
    {"type": "Shots on Goal", "value": 4},
    {"type": "Ball Possession", "value": "55%"}
  ]
}
```

The silver transformation pivots this into a proper row with typed columns — `shots_on_goal INTEGER`, `ball_possession_pct DECIMAL`, and so on.

One rule we followed throughout: **keep all columns in silver**. When in doubt, keep it. Storage is cheap and you can always choose not to expose a column in gold or in the dashboard, but you cannot recreate data you threw away. Silver models kept logos, flags, URLs, internal IDs, everything — even things that looked useless at the time.

## The MotherDuck Memory Limit

The fixture_players silver model was the most complex one to write. Each fixture returns a deeply nested JSON structure: a list of teams, each containing a list of players, each containing a list of statistics. Getting all of that into a flat table required multiple levels of `UNNEST`.

The initial version used nested UNNESTs — unnesting teams, then unnesting players within the same query, then unnesting statistics:

```sql
SELECT ...
FROM bronze.fixture_players,
UNNEST(response->'response') AS t(team),
UNNEST(t.team->'players') AS p(player),
UNNEST(p.player->'statistics') AS s(stat)
```

This worked fine in development on a local DuckDB instance with no memory constraints. When we ran it in production on MotherDuck's free tier, it hit the **953 MB memory cap** on the Pulse compute plan and crashed.

The fix was to stop doing all the unnesting in a single query and instead use **sequential CTEs** — unpack one level per CTE, materialise it, then unpack the next level from that:

```sql
WITH teams AS (
    SELECT fixture_id, UNNEST(response->'response') AS team
    FROM bronze.fixture_players
),
players AS (
    SELECT fixture_id, team->>'id' AS team_id, UNNEST(team->'players') AS player
    FROM teams
),
stats AS (
    SELECT fixture_id, team_id, player->>'id' AS player_id, UNNEST(player->'statistics') AS stat
    FROM players
)
SELECT ...
FROM stats
```

Each CTE processes a smaller set of intermediate results rather than holding the entire explosion in memory at once. After this refactor the query ran cleanly within the memory budget.

This was one of the more interesting problems in the whole project — not because the fix was complicated, but because the failure mode was invisible in development. Local DuckDB has no memory cap. The bug only appeared in production, and the error message (`Out of Memory: cannot allocate`) was not immediately helpful in pointing to nested UNNESTs as the culprit.

## Gold: Kimball Dimensional Modelling

Once silver tables were clean and stable, I built the gold layer as a **Kimball star schema**. The fact grain is one row per team per match — meaning each fixture produces two rows in the fact table, one for the home team and one for the away team. This grain was chosen because most analytical questions in football are team-centric: how many goals has this team scored? What is their xG differential at home?

The fact table, `fct_match_results`, contains all the measurable numeric values — goals, shots, possession, passes, fouls, cards, expected goals, and points earned. Everything else is pushed into dimensions.

We ended up with 10 dimension tables:

| Dimension | What it represents |
|---|---|
| `dim_date` | Calendar attributes of the match date |
| `dim_time` | Hour of kick-off and period of day (Morning / Afternoon / Evening / Night) |
| `dim_team` | Club identity — name, code, country, logo |
| `dim_opponent_team` | Role-playing dimension — same structure as `dim_team`, aliased to represent the opposing club |
| `dim_match` | Match metadata — round, season, names, status |
| `dim_league` | League identity — name, country, logo, flag |
| `dim_stadium` | Venue — name, city, capacity, surface |
| `dim_referee` | Referee name |
| `dim_team_side` | Home or Away |
| `dim_match_result` | Win, Draw, or Loss |

Having `dim_team` and `dim_opponent_team` as separate dimensions makes self-join queries much cleaner. A query like "show me all home results where the opponent was a top-four side" is a simple join rather than a correlated subquery.

## Surrogate Keys and Sentinel Rows

Every dimension uses an integer **surrogate key** as its primary key — `team_sk`, `match_sk`, and so on. These are stable across runs: when a new referee appears, they get a new SK, and existing referees keep theirs. This is the standard Kimball pattern.

Each dimension also has two **sentinel rows**:

- `-1 Unknown [Attribute]` — for records where the value exists but is genuinely unknown
- `-2 Not Applicable [Attribute]` — for records where the dimension does not apply

These sentinel rows mean the fact table can always have a valid foreign key, even for fixtures that have no referee assigned yet (common for upcoming matches) or for venues that are listed as TBD. Dashboard queries never need a `LEFT JOIN` or a null check — every fact row joins cleanly.

One early version of the sentinel rows had generic labels like `-1 Unknown` and `-2 Not Applicable`. We later updated them to be attribute-specific: `-1 Unknown Referee`, `-2 Not Applicable Stadium`, and so on. This makes them instantly readable in query results without having to check which dimension you are looking at.

## The Data Model

The star schema centres on a single fact table joined to ten dimensions. The grain is one row per team per match — each fixture produces two rows, one for the home team and one for the away team.

```
                    dim_date         dim_time
                       │                │
         dim_referee ──┤                ├── dim_team_side
                       │                │
dim_match ─────────────┤  fct_match  ├──────── dim_team
                       │   _results  │
dim_league ────────────┤                ├── dim_opponent_team
                       │                │
         dim_stadium ──┤                ├── dim_match_result
```

**`fct_match_results` — foreign keys**

| Column | References |
|---|---|
| `date_sk` | `dim_date` |
| `time_sk` | `dim_time` |
| `team_sk` | `dim_team` |
| `opponent_team_sk` | `dim_team` (role-playing as opponent) |
| `league_sk` | `dim_league` |
| `stadium_sk` | `dim_stadium` |
| `referee_sk` | `dim_referee` |
| `match_sk` | `dim_match` |
| `team_side_sk` | `dim_team_side` |
| `match_result_sk` | `dim_match_result` |

**`fct_match_results` — measures**

| Measure | Description |
|---|---|
| `points_earned` | 3 (win), 1 (draw), 0 (loss), NULL (not finished) |
| `goals_scored` | Goals scored by this team |
| `goals_conceded` | Goals conceded by this team |
| `goals_ht_scored` | Half-time goals scored |
| `goals_ht_conceded` | Half-time goals conceded |
| `shots_on_goal` | Shots on target |
| `shots_off_goal` | Shots off target |
| `total_shots` | All shots attempted |
| `blocked_shots` | Shots blocked |
| `shots_insidebox` | Shots from inside the box |
| `shots_outsidebox` | Shots from outside the box |
| `ball_possession_pct` | Ball possession percentage |
| `total_passes` | Total passes attempted |
| `passes_accurate` | Accurate passes |
| `fouls` | Fouls committed |
| `corner_kicks` | Corner kicks |
| `offsides` | Offsides |
| `yellow_cards` | Yellow cards received |
| `red_cards` | Red cards received |
| `goalkeeper_saves` | Saves by the goalkeeper |
| `expected_goals` | xG (where available from the API) |

Next: building the dashboard on top of this model.
