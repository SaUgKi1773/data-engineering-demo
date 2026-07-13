# Data science handover — match outcome predictions

`predict_match_outcomes.py` plays the role of the group's data science team:
it fits a Poisson goals model per league from completed matches in the gold
layer and hands over win/draw/loss probabilities for every upcoming fixture.
The handover lands in `bronze.datascience__match_predictions`, which is the
contract downstream layers (dbt silver/gold, #399) rely on.

## Contract: `bronze.datascience__match_predictions`

One row per upcoming fixture, refreshed nightly until kickoff, frozen after.

| Column           | Type      | Meaning                                                        |
|------------------|-----------|----------------------------------------------------------------|
| `match_id`       | INTEGER   | Sportmonks fixture id — joins to `gold.dim_match.match_id`     |
| `league_id`      | INTEGER   | Sportmonks league id — joins to `gold.dim_league.league_id`    |
| `season`         | VARCHAR   | Season label, e.g. `2026/27`                                   |
| `round_number`   | INTEGER   | Round the fixture belongs to                                   |
| `match_name`     | VARCHAR   | `Home Team - Away Team` (debugging aid, not a join key)        |
| `kickoff_at`     | TIMESTAMP | Fixture date + kick-off time (league-local, naive)             |
| `home_win_prob`  | DOUBLE    | P(home win), 4 decimals                                        |
| `draw_prob`      | DOUBLE    | P(draw), 4 decimals                                            |
| `away_win_prob`  | DOUBLE    | P(away win), 4 decimals                                        |
| `home_goals_exp` | DOUBLE    | Expected home goals (Poisson λ)                                |
| `away_goals_exp` | DOUBLE    | Expected away goals (Poisson λ)                                |
| `model_version`  | VARCHAR   | Model that produced the row, e.g. `poisson-v1`                 |
| `predicted_at`   | TIMESTAMP | When the prediction was made (UTC, naive)                      |

Guarantees downstream can rely on:

- **At most one row per `match_id`.** Refreshes are delete + insert of the
  same fixture, never appends.
- **`home_win_prob + draw_prob + away_win_prob` ≈ 1** (±0.0002 rounding).
- **Rows are never created or changed after kickoff.** A fixture is only
  (re-)predicted while its kickoff is at least 3 hours in the future, so the
  last pre-match prediction is what history keeps. This is what makes the
  accuracy tracking in #400 honest.
- **All leagues in gold are covered** — fixtures are discovered from
  `gold.fct_team_matches` rows with `match_result = 'Pending'`, whatever the
  league. A league with no completed matches to train on is skipped.

## Model: `poisson-v1`

Per league, trained on completed matches from the last 730 days:

- League-average home and away goals give the baseline (this encodes home
  advantage).
- Each team gets an attack and defense strength relative to the league
  average, shrunk toward 1.0 with 6 pseudo-matches of league-average form —
  newly promoted teams start at the league average instead of exploding.
- Expected goals: `λ_home = μ_home × attack_home × defense_away` (and
  mirrored for away), clamped to [0.1, 6.0].
- W/D/L probabilities come from the 0–10 score grid of the two independent
  Poissons, normalised to sum to 1.

## Running

```bash
# refresh predictions for all upcoming fixtures (default db: superligaen)
python ingestion/datascience/predict_match_outcomes.py --db superligaen_dev

# fit and log without writing
python ingestion/datascience/predict_match_outcomes.py --db superligaen_dev --dry-run
```

Needs `MOTHERDUCK_TOKEN` (loaded from `.env` at the repo root). Runs
nightly as the `match_predictions` job in `master.yml`, parallel to the other
bronze ingestions, and on demand via the `predictions.yml` workflow. Every run
logs to `meta.ingestion_run_log` as pipeline `datascience`. No paid services
involved — pure SQL + Python on the existing free tiers.
