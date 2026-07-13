#!/usr/bin/env python3
"""
Predict match outcomes for upcoming fixtures (the "data science team").

Fits a Poisson attack/defense goals model per league from completed matches
in the gold layer, and writes win/draw/loss probabilities for every upcoming
fixture to bronze.datascience__match_predictions. dbt then models the bronze
data into silver + gold.

Predictions are refreshed on every run for fixtures that have not kicked off
yet (delete + insert, one row per fixture). Rows for fixtures at or past
kickoff are never touched, so the final pre-match prediction is frozen.

Usage:
  python ingestion/datascience/predict_match_outcomes.py
  python ingestion/datascience/predict_match_outcomes.py --db superligaen_dev
  python ingestion/datascience/predict_match_outcomes.py --dry-run
"""

import argparse
import logging
import math
import os
from datetime import datetime, timedelta, timezone

import duckdb
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

DB_DEFAULT = "superligaen"
MODEL_VERSION = "poisson-v1"

# Model parameters
TRAINING_WINDOW_DAYS = 730   # fit on the last two years of completed matches
PRIOR_MATCHES = 6            # pseudo-matches of league-average form (shrinks small samples / promoted teams)
MAX_GOALS = 10               # score grid is 0..MAX_GOALS per team
LAMBDA_MIN, LAMBDA_MAX = 0.1, 6.0

# A fixture only qualifies for (re-)prediction while its kickoff is safely in
# the future. Kick-off times in gold are league-local and the runner is UTC;
# the margin absorbs any timezone offset so a match in progress is never touched.
KICKOFF_SAFETY_MARGIN = timedelta(hours=3)

BRONZE_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS {db}.bronze.datascience__match_predictions (
    match_id       INTEGER,
    league_id      INTEGER,
    season         VARCHAR,
    round_number   INTEGER,
    match_name     VARCHAR,
    kickoff_at     TIMESTAMP,
    home_win_prob  DOUBLE,
    draw_prob      DOUBLE,
    away_win_prob  DOUBLE,
    home_goals_exp DOUBLE,
    away_goals_exp DOUBLE,
    model_version  VARCHAR,
    predicted_at   TIMESTAMP
)
"""

META_CREATE_SQL = """
CREATE SCHEMA IF NOT EXISTS {db}.meta;
CREATE TABLE IF NOT EXISTS {db}.meta.ingestion_run_log (
    pipeline      VARCHAR,
    mode          VARCHAR,
    status        VARCHAR,
    started_at    TIMESTAMP,
    completed_at  TIMESTAMP,
    error_message VARCHAR
)
"""

# One row per completed match in the training window, pivoted to home/away.
TRAINING_QUERY = """
SELECT
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.team_sk      END) AS home_team_sk,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.team_sk      END) AS away_team_sk,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_scored END) AS home_goals,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_scored END) AS away_goals
FROM {db}.gold.fct_team_matches     f
JOIN {db}.gold.dim_match            m  ON m.match_sk         = f.match_sk
JOIN {db}.gold.dim_date             d  ON d.date_sk          = f.date_sk
JOIN {db}.gold.dim_team_side        ts ON ts.team_side_sk    = f.team_side_sk
JOIN {db}.gold.dim_match_result     mr ON mr.match_result_sk = f.match_result_sk
WHERE mr.match_result IN ('Win', 'Draw', 'Loss')
  AND d.date >= current_date - INTERVAL {window_days} DAY
  AND f.league_sk = ?
GROUP BY m.match_sk
HAVING home_goals IS NOT NULL AND away_goals IS NOT NULL
"""

# All upcoming fixtures, one row per match, across every league in gold.
UPCOMING_QUERY = """
SELECT
    f.league_sk,
    MAX(l.league_id)                                              AS league_id,
    MAX(l.league_name)                                            AS league_name,
    m.match_id,
    MAX(m.match_name)                                             AS match_name,
    MAX(d.season)                                                 AS season,
    MAX(m.match_round_number::INTEGER)                            AS round_number,
    MAX(d.date)                                                   AS match_date,
    MAX(m.kick_off_time)                                          AS kick_off_time,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.team_sk END)       AS home_team_sk,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.team_sk END)       AS away_team_sk
FROM {db}.gold.fct_team_matches     f
JOIN {db}.gold.dim_league           l  ON l.league_sk        = f.league_sk
JOIN {db}.gold.dim_match            m  ON m.match_sk         = f.match_sk
JOIN {db}.gold.dim_date             d  ON d.date_sk          = f.date_sk
JOIN {db}.gold.dim_team_side        ts ON ts.team_side_sk    = f.team_side_sk
JOIN {db}.gold.dim_match_result     mr ON mr.match_result_sk = f.match_result_sk
WHERE mr.match_result = 'Pending'
GROUP BY f.league_sk, m.match_id
ORDER BY f.league_sk, match_date, kick_off_time
"""


def poisson_pmf(lam: float, k: int) -> float:
    return math.exp(-lam) * lam**k / math.factorial(k)


def outcome_probabilities(lambda_home: float, lambda_away: float) -> tuple[float, float, float]:
    """W/D/L probabilities from a truncated score grid, normalised to sum to 1."""
    home_pmf = [poisson_pmf(lambda_home, k) for k in range(MAX_GOALS + 1)]
    away_pmf = [poisson_pmf(lambda_away, k) for k in range(MAX_GOALS + 1)]

    home_win = draw = away_win = 0.0
    for i, ph in enumerate(home_pmf):
        for j, pa in enumerate(away_pmf):
            p = ph * pa
            if i > j:
                home_win += p
            elif i == j:
                draw += p
            else:
                away_win += p

    total = home_win + draw + away_win
    return home_win / total, draw / total, away_win / total


def fit_league_model(matches: list[dict]) -> dict:
    """
    Poisson attack/defense strengths per team, shrunk toward league average.

    attack  = goals scored per match relative to the league mean
    defense = goals conceded per match relative to the league mean
    Teams with little or no history (e.g. newly promoted) converge to 1.0.
    """
    total_home = sum(m["home_goals"] for m in matches)
    total_away = sum(m["away_goals"] for m in matches)
    n = len(matches)
    mu_home = total_home / n
    mu_away = total_away / n
    mu = (mu_home + mu_away) / 2

    scored: dict[int, float] = {}
    conceded: dict[int, float] = {}
    played: dict[int, int] = {}
    for m in matches:
        for team_sk, gf, ga in (
            (m["home_team_sk"], m["home_goals"], m["away_goals"]),
            (m["away_team_sk"], m["away_goals"], m["home_goals"]),
        ):
            scored[team_sk] = scored.get(team_sk, 0) + gf
            conceded[team_sk] = conceded.get(team_sk, 0) + ga
            played[team_sk] = played.get(team_sk, 0) + 1

    strengths = {}
    for team_sk, n_played in played.items():
        denom = (n_played + PRIOR_MATCHES) * mu
        strengths[team_sk] = {
            "attack":  (scored[team_sk]   + PRIOR_MATCHES * mu) / denom,
            "defense": (conceded[team_sk] + PRIOR_MATCHES * mu) / denom,
        }

    return {"mu_home": mu_home, "mu_away": mu_away, "strengths": strengths}


def predict_fixture(model: dict, home_team_sk: int, away_team_sk: int) -> dict:
    neutral = {"attack": 1.0, "defense": 1.0}
    home = model["strengths"].get(home_team_sk, neutral)
    away = model["strengths"].get(away_team_sk, neutral)

    lambda_home = model["mu_home"] * home["attack"] * away["defense"]
    lambda_away = model["mu_away"] * away["attack"] * home["defense"]
    lambda_home = min(max(lambda_home, LAMBDA_MIN), LAMBDA_MAX)
    lambda_away = min(max(lambda_away, LAMBDA_MIN), LAMBDA_MAX)

    home_win, draw, away_win = outcome_probabilities(lambda_home, lambda_away)
    return {
        "home_win_prob":  round(home_win, 4),
        "draw_prob":      round(draw, 4),
        "away_win_prob":  round(away_win, 4),
        "home_goals_exp": round(lambda_home, 3),
        "away_goals_exp": round(lambda_away, 3),
    }


def parse_kickoff(match_date, kick_off_time: str | None) -> datetime:
    """Combine gold's date + 'HH:MM' kick-off into a naive league-local timestamp."""
    base = datetime(match_date.year, match_date.month, match_date.day)
    try:
        hour, minute = map(int, (kick_off_time or "").split(":"))
        return base.replace(hour=hour, minute=minute)
    except ValueError:
        return base  # unknown kick-off time: midnight, i.e. the most conservative cutoff


def run(con, db: str, dry_run: bool) -> None:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    cutoff = now + KICKOFF_SAFETY_MARGIN

    rows = con.execute(UPCOMING_QUERY.format(db=db)).fetchall()
    cols = [d[0] for d in con.description]
    fixtures = [dict(zip(cols, r)) for r in rows]
    log.info(f"Found {len(fixtures)} pending fixtures in gold")

    predictable = [f for f in fixtures if parse_kickoff(f["match_date"], f["kick_off_time"]) > cutoff]
    skipped = len(fixtures) - len(predictable)
    if skipped:
        log.info(f"Skipping {skipped} fixtures at or near kickoff (frozen)")
    if not predictable:
        log.info("Nothing to predict")
        return

    to_insert = []
    for league_sk in sorted({f["league_sk"] for f in predictable}):
        league_fixtures = [f for f in predictable if f["league_sk"] == league_sk]
        league_name = league_fixtures[0]["league_name"]

        training_rows = con.execute(
            TRAINING_QUERY.format(db=db, window_days=TRAINING_WINDOW_DAYS), [league_sk]
        ).fetchall()
        training_cols = [d[0] for d in con.description]
        matches = [dict(zip(training_cols, r)) for r in training_rows]
        if not matches:
            log.warning(f"{league_name}: no completed matches to train on — skipping {len(league_fixtures)} fixtures")
            continue

        model = fit_league_model(matches)
        log.info(
            f"{league_name}: fitted on {len(matches)} matches "
            f"(league avg {model['mu_home']:.2f}-{model['mu_away']:.2f}), "
            f"predicting {len(league_fixtures)} fixtures"
        )

        for f in league_fixtures:
            p = predict_fixture(model, f["home_team_sk"], f["away_team_sk"])
            log.info(
                f"  {f['match_name']}: "
                f"{p['home_win_prob']:.0%}/{p['draw_prob']:.0%}/{p['away_win_prob']:.0%} "
                f"(xG {p['home_goals_exp']}-{p['away_goals_exp']})"
            )
            to_insert.append((
                f["match_id"], f["league_id"], f["season"], f["round_number"],
                f["match_name"], parse_kickoff(f["match_date"], f["kick_off_time"]),
                p["home_win_prob"], p["draw_prob"], p["away_win_prob"],
                p["home_goals_exp"], p["away_goals_exp"],
                MODEL_VERSION, now,
            ))

    if dry_run:
        log.info(f"--dry-run: would refresh {len(to_insert)} predictions")
        return
    if not to_insert:
        log.info("No predictions produced")
        return

    # Refresh exactly the fixtures predicted this run; every other row —
    # in particular anything at or past kickoff — is left untouched.
    match_ids = [r[0] for r in to_insert]
    con.execute("BEGIN TRANSACTION")
    con.execute(
        f"DELETE FROM {db}.bronze.datascience__match_predictions WHERE match_id IN "
        f"({','.join('?' * len(match_ids))})",
        match_ids,
    )
    con.executemany(
        f"""
        INSERT INTO {db}.bronze.datascience__match_predictions
            (match_id, league_id, season, round_number, match_name, kickoff_at,
             home_win_prob, draw_prob, away_win_prob, home_goals_exp, away_goals_exp,
             model_version, predicted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        to_insert,
    )
    con.execute("COMMIT")
    log.info(f"Refreshed {len(to_insert)} predictions in bronze")


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict upcoming match outcomes (Poisson)")
    parser.add_argument("--db",      default=DB_DEFAULT,  help="MotherDuck database name")
    parser.add_argument("--dry-run", action="store_true", help="Fit and log predictions without writing to bronze")
    args = parser.parse_args()

    token = os.environ["MOTHERDUCK_TOKEN"]
    con = duckdb.connect(f"md:{args.db}?motherduck_token={token}")

    con.execute(BRONZE_CREATE_SQL.format(db=args.db))
    for stmt in META_CREATE_SQL.format(db=args.db).strip().split(";"):
        if stmt.strip():
            con.execute(stmt)

    started_at = datetime.now(timezone.utc).replace(tzinfo=None)
    try:
        run(con, args.db, args.dry_run)
        if not args.dry_run:
            con.execute(
                f"INSERT INTO {args.db}.meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
                ["datascience", "incremental", "success", started_at,
                 datetime.now(timezone.utc).replace(tzinfo=None), None],
            )
    except Exception as exc:
        if not args.dry_run:
            con.execute(
                f"INSERT INTO {args.db}.meta.ingestion_run_log VALUES (?, ?, ?, ?, ?, ?)",
                ["datascience", "incremental", "failure", started_at,
                 datetime.now(timezone.utc).replace(tzinfo=None), str(exc)],
            )
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
