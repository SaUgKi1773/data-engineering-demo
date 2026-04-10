# Danish Football Data Engineering Demo

An end-to-end data engineering project for Danish football data, built with:

- **Python** — ingestion scripts (`ingestion/`)
- **MotherDuck (DuckDB cloud)** — cloud data warehouse
- **dbt Core** (`dbt/danish_football/`) — SQL transformations (staging → marts)
- **GitHub Actions** — daily orchestration and CI/CD
- **Evidence.dev** (`dashboards/`) — BI dashboards

## Project structure

```
.
├── ingestion/              # Python ingestion scripts
├── dbt/
│   └── danish_football/    # dbt project
│       ├── models/
│       │   ├── staging/    # Raw source views (dev_ prefix in dev)
│       │   └── marts/      # Business-logic tables
│       ├── profiles.yml    # Dev + prod MotherDuck targets
│       └── packages.yml
├── dashboards/             # Evidence.dev app
├── .github/
│   └── workflows/
│       ├── ci.yml          # Runs on PRs to main
│       └── deploy.yml      # Runs on merge to main
├── requirements.txt
└── .env.example
```

## Dev / prod workflow

| Environment | MotherDuck schema | Triggered by |
|-------------|-------------------|--------------|
| `dev`       | `dev_danish_football` | Local work / PRs |
| `prod`      | `danish_football`     | Merge to `main` |

**Rule**: never commit directly to `main`. Always work on a `dev/<feature>` branch, open a PR, let CI pass, then merge. The `deploy.yml` workflow promotes to prod automatically on merge.

## Local setup

```bash
# 1. Clone and create a feature branch
git checkout -b dev/<your-feature>

# 2. Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Fill in MOTHERDUCK_TOKEN and SOURCE_API_KEY

# 4. Run dbt against dev schema
cd dbt/danish_football
dbt deps --profiles-dir .
dbt run --target dev --profiles-dir .
dbt test --target dev --profiles-dir .
```

## GitHub Actions secrets required

| Secret | Description |
|--------|-------------|
| `MOTHERDUCK_TOKEN` | MotherDuck service token |
| `SOURCE_API_KEY` | Football data API key (if needed) |
