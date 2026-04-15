# Danish Football Data Engineering Demo

An end-to-end data engineering project for Danish football data, built on a fully custom Python + SQL stack — no dbt.

## Tech stack

| Layer | Tool |
|---|---|
| Data warehouse | MotherDuck (DuckDB cloud) |
| Ingestion | Python (`ingestion/`) |
| Transformations | Pure SQL + Python runners (`transformations/`) |
| Orchestration | GitHub Actions (nightly + manual) |
| BI | Evidence.dev (`dashboards/`) |

## Architecture

```
API (api-football.com)
        │
        ▼
   Bronze layer          Raw JSON stored in MotherDuck
        │
        ▼
   Silver layer          Cleaned, typed, structured tables
        │
        ▼
   Gold layer            Kimball dimensional model
                         (dims + fct_match_results)
```

## Project structure

```
.
├── ingestion/                  # Bronze: pull from API → MotherDuck
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
│   └── gold/                   # Gold SQL — dims and fact
│       ├── dim_date.sql
│       ├── dim_time.sql
│       ├── dim_team.sql
│       ├── dim_league.sql
│       ├── dim_stadium.sql
│       ├── dim_referee.sql
│       ├── dim_match.sql
│       ├── dim_team_side.sql
│       ├── dim_match_result.sql
│       └── fct_match_results.sql
│
├── dashboards/                 # Evidence.dev BI app
├── .github/workflows/
│   ├── master.yml              # Nightly pipeline: bronze → silver → gold
│   └── gold.yml                # Manual gold rebuild trigger
└── requirements.txt
```

## Data model

Gold layer follows Kimball dimensional modelling. Fact grain: **one row per team per match**.

```
fct_match_results
    date_sk         → dim_date
    time_sk         → dim_time
    team_sk         → dim_team
    opponent_sk     → dim_team
    league_sk       → dim_league
    stadium_sk      → dim_stadium
    referee_sk      → dim_referee
    match_sk        → dim_match   (round, season, status)
    team_side_sk    → dim_team_side
    match_result_sk → dim_match_result
```

All dimension surrogate keys are **stable across runs** — new records get new SKs, existing records keep theirs.

## Dev / prod environments

| Environment | MotherDuck database | Triggered by |
|---|---|---|
| `dev` | `superligaen_dev` | Local work |
| `prod` | `superligaen` | GitHub Actions |

**Rule**: never commit directly to `main`. Work on `dev/<feature>` branches, open a PR, then merge. The nightly workflow runs against prod automatically.

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
```

## GitHub Actions secrets required

| Secret | Description |
|---|---|
| `MOTHERDUCK_TOKEN` | MotherDuck service token |
| `API_FOOTBALL_KEY` | api-football.com API key |
