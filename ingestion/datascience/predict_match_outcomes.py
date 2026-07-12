#!/usr/bin/env python3
"""
Match outcome predictions — the "data science team" producer.

This script simulates a data science team publishing model output to the
warehouse: it reads finished matches from the gold layer, fits a Poisson
goals model per league (attack/defense strength vs league average, with
home advantage, time decay and shrinkage toward the mean for cold starts),
and appends win/draw/loss probabilities for every pending fixture to
bronze.ds__match_predictions.

The BI side treats this table as an external source governed by a data
contract (see issue #342): append-only, probabilities sum to 1, and
predictions are only ever produced for fixtures that have not been played —
so predicted_at is leakage-proof evidence for the accuracy tracker.

Usage:
  python ingestion/datascience/predict_match_outcomes.py                      # MotherDuck, default db
  python ingestion/datascience/predict_match_outcomes.py --db superligaen_dev
  python ingestion/datascience/predict_match_outcomes.py --db superligaen_dev.duckdb  # local file
  python ingestion/datascience/predict_match_outcomes.py --force              # re-predict today's runs
"""

import argparse
import logging
import math
import os
from datetime import datetime, timezone

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

DB_DEFAULT = "superligaen"
MODEL_VERSION = "poisson-v1"

# Model hyperparameters
DECAY_HALF_LIFE_DAYS = 240   # a match played 240 days ago carries half the weight of today's
PRIOR_WEIGHT = 10.0          # shrinkage: every team starts with ~10 league-average matches
MAX_GOALS = 10               # score-matrix grid size
LAMBDA_MIN, LAMBDA_MAX = 0.2, 4.5

# Leagues the model covers, with the dim_date season column each league uses
LEAGUES = {
    271: {"name": "Superliga",   "season_col": "season"},
    501: {"name": "Premiership", "season_col": "season_scotland"},
}

BRONZE_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS {bronze}.ds__match_predictions (
    match_id            INTEGER,
    league_id           INTEGER,
    season              VARCHAR,
    round_number        INTEGER,
    match_name          VARCHAR,
    model_version       VARCHAR,
    p_home_win          DOUBLE,
    p_draw              DOUBLE,
    p_away_win          DOUBLE,
    expected_home_goals DOUBLE,
    expected_away_goals DOUBLE,
    predicted_at        TIMESTAMP
)
"""

META_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS {meta}.ingestion_run_log (
    pipeline      VARCHAR,
    mode          VARCHAR,
    status        VARCHAR,
    started_at    TIMESTAMP,
    completed_at  TIMESTAMP,
    error_message VARCHAR
)
"""

FINISHED_MATCHES_SQL = """
SELECT
    m.match_id,
    d.date                                                          AS match_date,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_id      END)    AS home_team_id,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_id      END)    AS away_team_id,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_scored END)    AS home_goals,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_scored END)    AS away_goals
FROM {gold}.fct_team_matches     f
JOIN {gold}.dim_match            m  ON m.match_sk         = f.match_sk
JOIN {gold}.dim_date             d  ON d.date_sk          = f.date_sk
JOIN {gold}.dim_team             t  ON t.team_sk          = f.team_sk
JOIN {gold}.dim_team_side        ts ON ts.team_side_sk    = f.team_side_sk
JOIN {gold}.dim_match_result     mr ON mr.match_result_sk = f.match_result_sk
WHERE mr.match_result IN ('Win', 'Draw', 'Loss')
  AND f.league_sk = (SELECT league_sk FROM {gold}.dim_league WHERE league_id = ?)
GROUP BY m.match_id, d.date
HAVING home_goals IS NOT NULL AND away_goals IS NOT NULL
ORDER BY d.date
"""

PENDING_FIXTURES_SQL = """
SELECT
    m.match_id,
    d.{season_col}                                                  AS season,
    m.match_round_number::INTEGER                                   AS round_number,
    m.match_name,
    d.date                                                          AS match_date,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_id END)         AS home_team_id,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_id END)         AS away_team_id
FROM {gold}.fct_team_matches     f
JOIN {gold}.dim_match            m  ON m.match_sk         = f.match_sk
JOIN {gold}.dim_date             d  ON d.date_sk          = f.date_sk
JOIN {gold}.dim_team             t  ON t.team_sk          = f.team_sk
JOIN {gold}.dim_team_side        ts ON ts.team_side_sk    = f.team_side_sk
JOIN {gold}.dim_match_result     mr ON mr.match_result_sk = f.match_result_sk
WHERE mr.match_result = 'Pending'
  AND f.league_sk = (SELECT league_sk FROM {gold}.dim_league WHERE league_id = ?)
GROUP BY m.match_id, d.{season_col}, m.match_round_number, m.match_name, d.date
HAVING home_team_id IS NOT NULL AND away_team_id IS NOT NULL
ORDER BY d.date
"""


def poisson_pmf(lam: float, k: int) -> float:
    return math.exp(-lam) * lam**k / math.factorial(k)


def fit_league(matches: list[dict], as_of) -> dict:
    """Fit weighted attack/defense strengths and home advantage for one league."""
    team_gs: dict[int, float] = {}   # weighted goals scored
    team_gc: dict[int, float] = {}   # weighted goals conceded
    team_n: dict[int, float] = {}    # weighted match count
    sum_home_goals = sum_away_goals = sum_w = 0.0

    for m in matches:
        days_ago = max((as_of - m["match_date"]).days, 0)
        w = 0.5 ** (days_ago / DECAY_HALF_LIFE_DAYS)
        sum_home_goals += w * m["home_goals"]
        sum_away_goals += w * m["away_goals"]
        sum_w += w
        for team, gs, gc in (
            (m["home_team_id"], m["home_goals"], m["away_goals"]),
            (m["away_team_id"], m["away_goals"], m["home_goals"]),
        ):
            team_gs[team] = team_gs.get(team, 0.0) + w * gs
            team_gc[team] = team_gc.get(team, 0.0) + w * gc
            team_n[team] = team_n.get(team, 0.0) + w

    # league average goals per team per match, and home/away split factors
    mu = (sum_home_goals + sum_away_goals) / (2 * sum_w)
    home_factor = sum_home_goals / sum_w / mu
    away_factor = sum_away_goals / sum_w / mu

    attack, defense = {}, {}
    for team in team_n:
        n = team_n[team]
        # shrink toward league average so promoted/new teams start neutral
        attack[team] = (team_gs[team] + PRIOR_WEIGHT * mu) / ((n + PRIOR_WEIGHT) * mu)
        defense[team] = (team_gc[team] + PRIOR_WEIGHT * mu) / ((n + PRIOR_WEIGHT) * mu)

    return {
        "mu": mu, "home_factor": home_factor, "away_factor": away_factor,
        "attack": attack, "defense": defense,
    }


def predict(model: dict, home_team_id: int, away_team_id: int) -> dict:
    """W/D/L probabilities and expected goals for one fixture (unknown teams = neutral)."""
    lam_home = (
        model["mu"] * model["home_factor"]
        * model["attack"].get(home_team_id, 1.0)
        * model["defense"].get(away_team_id, 1.0)
    )
    lam_away = (
        model["mu"] * model["away_factor"]
        * model["attack"].get(away_team_id, 1.0)
        * model["defense"].get(home_team_id, 1.0)
    )
    lam_home = min(max(lam_home, LAMBDA_MIN), LAMBDA_MAX)
    lam_away = min(max(lam_away, LAMBDA_MIN), LAMBDA_MAX)

    p_home = p_draw = p_away = 0.0
    for i in range(MAX_GOALS + 1):
        pi = poisson_pmf(lam_home, i)
        for j in range(MAX_GOALS + 1):
            p = pi * poisson_pmf(lam_away, j)
            if i > j:
                p_home += p
            elif i == j:
                p_draw += p
            else:
                p_away += p

    total = p_home + p_draw + p_away  # grid truncation leaves ~1e-6 unassigned
    return {
        "p_home_win": p_home / total,
        "p_draw": p_draw / total,
        "p_away_win": p_away / total,
        "expected_home_goals": lam_home,
        "expected_away_goals": lam_away,
    }


def process_league(con, bronze: str, gold: str, league_id: int, cfg: dict, force: bool, now) -> int:
    finished_rows = con.execute(FINISHED_MATCHES_SQL.format(gold=gold), [league_id]).fetchall()
    finished_cols = [d[0] for d in con.description]
    finished = [dict(zip(finished_cols, r)) for r in finished_rows]
    if not finished:
        log.warning(f"{cfg['name']}: no finished matches — skipping")
        return 0

    pending_rows = con.execute(
        PENDING_FIXTURES_SQL.format(gold=gold, season_col=cfg["season_col"]), [league_id]
    ).fetchall()
    pending_cols = [d[0] for d in con.description]
    pending = [dict(zip(pending_cols, r)) for r in pending_rows]
    if not pending:
        log.info(f"{cfg['name']}: no pending fixtures")
        return 0

    if force:
        con.execute(
            f"""DELETE FROM {bronze}.ds__match_predictions
                WHERE league_id = ? AND model_version = ? AND predicted_at::DATE = ?""",
            [league_id, MODEL_VERSION, now.date()],
        )
        already_done = set()
    else:
        # one prediction per fixture per day: later days re-predict with fresher strengths
        already_done = {
            r[0] for r in con.execute(
                f"""SELECT match_id FROM {bronze}.ds__match_predictions
                    WHERE league_id = ? AND model_version = ? AND predicted_at::DATE = ?""",
                [league_id, MODEL_VERSION, now.date()],
            ).fetchall()
        }

    model = fit_league(finished, now.date())
    log.info(
        f"{cfg['name']}: fitted on {len(finished)} matches "
        f"(mu={model['mu']:.2f}, home_factor={model['home_factor']:.2f}), "
        f"{len(pending)} pending fixtures"
    )

    to_insert = []
    for fx in pending:
        if fx["match_id"] in already_done:
            continue
        pred = predict(model, fx["home_team_id"], fx["away_team_id"])
        to_insert.append((
            fx["match_id"], league_id, fx["season"], fx["round_number"], fx["match_name"],
            MODEL_VERSION, pred["p_home_win"], pred["p_draw"], pred["p_away_win"],
            pred["expected_home_goals"], pred["expected_away_goals"], now,
        ))

    if to_insert:
        con.executemany(
            f"""
            INSERT INTO {bronze}.ds__match_predictions
                (match_id, league_id, season, round_number, match_name, model_version,
                 p_home_win, p_draw, p_away_win, expected_home_goals, expected_away_goals, predicted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            to_insert,
        )
    log.info(f"{cfg['name']}: inserted {len(to_insert)}, skipped {len(pending) - len(to_insert)} already predicted today")
    return len(to_insert)


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish match outcome predictions to bronze")
    parser.add_argument("--db",    default=DB_DEFAULT,  help="MotherDuck database name, or a local .duckdb file path")
    parser.add_argument("--force", action="store_true", help="Overwrite predictions already made today")
    args = parser.parse_args()

    if args.db.endswith(".duckdb"):
        con = duckdb.connect(args.db)
        bronze, gold, meta = "bronze", "gold", "meta"
    else:
        token = os.environ["MOTHERDUCK_TOKEN"]
        con = duckdb.connect(f"md:{args.db}?motherduck_token={token}")
        bronze, gold, meta = f"{args.db}.bronze", f"{args.db}.gold", f"{args.db}.meta"

    con.execute(f"CREATE SCHEMA IF NOT EXISTS {bronze}")
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {meta}")
    con.execute(BRONZE_CREATE_SQL.format(bronze=bronze))
    con.execute(META_CREATE_SQL.format(meta=meta))

    started_at = datetime.now(timezone.utc).replace(tzinfo=None)

    try:
        total = 0
        for league_id, cfg in LEAGUES.items():
            total += process_league(con, bronze, gold, league_id, cfg, args.force, started_at)
        log.info(f"Done: {total} predictions published ({MODEL_VERSION})")
        con.execute(
            f"INSERT INTO {meta}.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["datascience", "incremental", "success", started_at,
             datetime.now(timezone.utc).replace(tzinfo=None), None],
        )
    except Exception as exc:
        con.execute(
            f"INSERT INTO {meta}.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
            ["datascience", "incremental", "failure", started_at,
             datetime.now(timezone.utc).replace(tzinfo=None), str(exc)],
        )
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
