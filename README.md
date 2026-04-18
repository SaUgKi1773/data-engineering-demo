# Superligaen Data Engineering Demo

An end-to-end data engineering project for Danish premier football league (Superligaen) — from raw API ingestion to a live analytics dashboard. Built on a fully custom Python + SQL stack.

**Live dashboard →** [superligaen.pages.dev](https://superligaen.pages.dev)

---

## Architecture

```
api-football.com
       │
       ▼
  Bronze layer        Raw JSON stored in MotherDuck (one table per endpoint)
       │
       ▼
  Silver layer        Cleaned, typed, structured relational tables
       │
       ▼
  Gold layer          Kimball star schema  ─────────────────────────────┐
                      (dims + fct_match_results)                         │
                                                                         ▼
                                                              Evidence.dev dashboard
                                                              deployed on Cloudflare Pages
```

The nightly GitHub Actions pipeline runs all three layers sequentially, then triggers a Cloudflare Pages rebuild so the dashboard always reflects last night's data.

---

## Tech stack

| Layer | Tool |
|---|---|
| Data warehouse | MotherDuck (DuckDB cloud) |
| Ingestion | Python (`ingestion/`) |
| Transformations | Pure SQL + Python runners (`transformations/`) |
| Orchestration | GitHub Actions (nightly + manual triggers) |
| BI / Dashboard | Evidence.dev |
| Hosting | Cloudflare Pages |

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
        date full_date
        int year
        int month
        varchar month_name
        int quarter
        int week_number
        int day_of_week
        varchar day_name
        varchar is_weekend
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
        int season
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
| **Team Analytics** | Deep-dive per-team KPIs, form, shooting, possession, discipline |
| **Upcoming Fixtures** | Next fixtures with head-to-head history and last-5 form guide |

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
├── transformations/
│   ├── run_silver.py           # Silver runner
│   ├── run_gold.py             # Gold runner
│   ├── silver/                 # Silver SQL — one file per entity
│   └── gold/                   # Gold SQL — dims and fact table
│
├── dashboards/                 # Evidence.dev BI app
│   ├── pages/                  # One .md file per dashboard page
│   └── sources/superligaen/    # SQL sources compiled to parquet
│
├── .github/workflows/
│   ├── master.yml              # Nightly: bronze → silver → gold → deploy
│   ├── cloudflare.yml          # Manual deploy trigger
│   ├── ingest.yml              # Manual bronze-only run
│   ├── transform.yml           # Manual silver-only run
│   └── gold.yml                # Manual gold-only run
│
└── requirements.txt
```

---

## Environments

| Environment | MotherDuck database | Triggered by |
|---|---|---|
| Dev | `superligaen_dev` | Local / feature branches |
| Prod | `superligaen` | GitHub Actions (`main`) |

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
python transformations/run_silver.py
python transformations/run_gold.py

# 5. Run the dashboard locally
cd dashboards
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
| `MOTHERDUCK_TOKEN_READONLY` | MotherDuck read-only token (dashboard) |
| `API_FOOTBALL_KEY` | api-football.com API key |
| `CLOUDFLARE_DEPLOY_HOOK` | Cloudflare Pages deploy hook URL |
