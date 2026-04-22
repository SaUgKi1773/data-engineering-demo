# Superligaen Analytics

An end-to-end data engineering project tracking the Danish premier football league (Superligaen) — from raw API ingestion to a live analytics dashboard.

**Live dashboard →** [superligaanalytics.vercel.app](https://superligaanalytics.vercel.app/)

---

## Architecture

```
api-football.com
       │
       ▼
  Bronze layer        Raw JSON stored in MotherDuck (one table per endpoint)
       │
       ▼
  Silver layer        Cleaned, typed, structured relational tables  (dbt)
       │
       ▼
  Gold layer          Kimball star schema  ─────────────────────────────┐
                      (dims + fct_match_results)        (dbt)           │
                                                                        ▼
                                                             Evidence.dev dashboard
                                                             deployed on Vercel
```

The nightly GitHub Actions pipeline runs all three layers sequentially, then triggers a Vercel rebuild so the dashboard always reflects last night's data.

---

## Tech stack

| Layer | Tool |
|---|---|
| Data warehouse | MotherDuck (DuckDB cloud) |
| Ingestion | Python (`ingestion/`) |
| Transformations | dbt-duckdb (`dbt/`) |
| Orchestration | GitHub Actions (nightly + manual triggers) |
| BI / Dashboard | Evidence.dev |
| Hosting | Vercel |

---

## Data model

The gold layer follows **Kimball dimensional modelling**. Fact grain: **one row per team per match** (each fixture produces two rows — one for the home team, one for the away team).

```mermaid
erDiagram
    fct_match_results {
        int date_sk FK
        int time_sk FK
        int team_sk FK
        int opponent_team_sk FK
        int league_sk FK
        int stadium_sk FK
        int referee_sk FK
        int match_sk FK
        int team_side_sk FK
        int match_result_sk FK
        int goals_scored
        int goals_conceded
        int shots_on_goal
        int total_shots
        int shots_insidebox
        int shots_outsidebox
        decimal ball_possession_pct
        int total_passes
        int passes_accurate
        int fouls
        int corner_kicks
        int offsides
        int yellow_cards
        int red_cards
        int goalkeeper_saves
        decimal expected_goals
        int points_earned
    }

    dim_date {
        int date_sk PK
        date date
        int year
        int month
        varchar month_name
        int quarter
        int week_number
        int day_of_week
        varchar day_name
        varchar is_weekend
        varchar season
    }

    dim_time {
        int time_sk PK
        int hour
        int minute
        varchar period_of_day
    }

    dim_team {
        int team_sk PK
        int team_id
        varchar team_name
        varchar team_code
        varchar team_country
        int team_founded_year
        varchar team_logo
    }

    dim_opponent_team {
        int opponent_team_sk PK
        int opponent_team_id
        varchar opponent_team_name
        varchar opponent_team_code
        varchar opponent_team_country
        int opponent_team_founded_year
        varchar opponent_team_logo
    }

    dim_match {
        int match_sk PK
        int match_id
        varchar match_round_name
        varchar match_round_type
        int match_round_number
        varchar match_name
        varchar match_short_name
        varchar match_status
        varchar match_result
    }

    dim_league {
        int league_sk PK
        int league_id
        varchar league_name
        varchar league_type
        varchar league_country
        varchar league_country_code
        varchar league_logo
        varchar league_country_flag
    }

    dim_stadium {
        int stadium_sk PK
        int stadium_id
        varchar stadium_name
        varchar stadium_city
        varchar stadium_country
        varchar stadium_address
        varchar stadium_surface
        int stadium_capacity
    }

    dim_referee {
        int referee_sk PK
        varchar referee_name
        varchar referee_nationality
    }

    dim_team_side {
        int team_side_sk PK
        varchar team_side
    }

    dim_match_result {
        int match_result_sk PK
        varchar match_result
    }

    fct_match_results }o--|| dim_date : "date_sk"
    fct_match_results }o--|| dim_time : "time_sk"
    fct_match_results }o--|| dim_team : "team_sk"
    fct_match_results }o--|| dim_opponent_team : "opponent_team_sk"
    fct_match_results }o--|| dim_match : "match_sk"
    fct_match_results }o--|| dim_league : "league_sk"
    fct_match_results }o--|| dim_stadium : "stadium_sk"
    fct_match_results }o--|| dim_referee : "referee_sk"
    fct_match_results }o--|| dim_team_side : "team_side_sk"
    fct_match_results }o--|| dim_match_result : "match_result_sk"
```

All dimension surrogate keys are **stable across runs** — new records get new SKs, existing records keep theirs. Sentinel rows (`-1 Unknown`, `-2 Not Applicable`) handle missing lookups.

---

## Dashboard pages

| Page | Description |
|---|---|
| **Home** | Season KPIs, current leader, navigation |
| **Standings** | Championship, Relegation & Regular Season tables |
| **Match Results** | Full match history, scorelines, Goals vs xG by round |
| **Upcoming Fixtures** | Next fixtures with head-to-head history and last-5 form guide |
| **League Analytics** | Cross-team benchmarks, rankings and league-wide trends |
| **Team Analytics** | Deep-dive per-team KPIs, form, shooting, possession, discipline |
| **Referee Analytics** | Cards, fouls, team exposure and match logs by referee |
| **Glossary** | Definitions of all metrics and KPIs used across the dashboard |

---

## Project structure

```
.
├── ingestion/                  # Bronze: pull from api-football.com → MotherDuck
│   ├── run.py                  # Ingestion runner (incremental + full load)
│   ├── api.py                  # API client
│   ├── db.py                   # MotherDuck connection
│   ├── config.py               # Config and env vars
│   └── ingest_*.py             # Per-entity ingestion scripts
│
├── dbt/                        # Silver + Gold transformations (dbt-duckdb)
│   ├── models/
│   │   ├── silver/             # 18 models: bronze JSON → structured tables
│   │   └── gold/
│   │       ├── dims/           # 10 dim_* models (Kimball dims)
│   │       └── fct_match_results.sql
│   ├── macros/                 # fixture_filter(), season_filter(), generate_schema_name()
│   └── dbt_project.yml
│
├── dashboards/                 # Evidence.dev BI app
│   ├── pages/                  # One .md file per dashboard page
│   └── sources/superligaen/    # SQL sources queried at build time
│
├── scripts/
│   └── sync_dev_db.py          # Copies one season from superligaen → superligaen_dev
│
├── .github/workflows/
│   ├── master.yml              # Nightly: bronze → silver (dbt) → gold (dbt) → deploy
│   ├── ci.yml                  # PR validation: Python syntax + dbt compile
│   ├── ingest.yml              # Manual bronze-only run
│   ├── transform.yml           # Manual silver-only run (dbt)
│   ├── gold.yml                # Manual gold-only run (dbt)
│   ├── vercel.yml              # Manual Vercel deploy trigger
│   └── sync-dev-db.yml         # Manual prod → dev database sync
│
└── requirements.txt
```

---

## Environments

| Environment | MotherDuck database | dbt target | Triggered by |
|---|---|---|---|
| Dev | `superligaen_dev` | `dev` | Local / feature branches |
| Prod | `superligaen` | `prod` | GitHub Actions (`main`) |

---

## Local setup

```bash
# 1. Clone and create a feature branch
git clone https://github.com/SaUgKi1773/data-engineering-demo.git
git checkout -b dev/<your-feature>

# 2. Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Fill in MOTHERDUCK_TOKEN and API_FOOTBALL_KEY

# 4. Run layers against dev
python ingestion/run.py
cd dbt
dbt run --select silver.* --target dev
dbt run --select gold.* --target dev

# 5. Run the dashboard locally
cd ../dashboards
# Write the MotherDuck token for Evidence
echo "token: $(echo -n "$MOTHERDUCK_TOKEN" | base64)" > sources/superligaen/connection.options.yaml
npm install
npm run sources
npm run dev
# → http://localhost:3000
```

---

## GitHub Actions secrets

| Secret | Description |
|---|---|
| `MOTHERDUCK_TOKEN` | MotherDuck service token (read-write) |
| `MOTHERDUCK_TOKEN_READONLY` | MotherDuck read-only token (dashboard build) |
| `API_FOOTBALL_KEY` | api-football.com API key |
