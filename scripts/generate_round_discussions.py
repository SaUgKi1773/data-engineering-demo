#!/usr/bin/env python3
"""
Generate AI round discussions using Groq (Llama).

Reads match data and persona definitions from the gold layer, calls Groq
once per match, and writes the raw API response to bronze.groq__llm_match_discussions.
dbt then parses and models the bronze data into silver + gold.

Usage:
  python scripts/generate_round_discussions.py --season 2024/25 --round 26
  python scripts/generate_round_discussions.py --season 2024/25  # auto-detects latest round
  python scripts/generate_round_discussions.py --season 2024/25 --round 26 --db superligaen_dev
"""

import argparse
import logging
import os
import time
from datetime import datetime, timezone

import duckdb
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

DB_DEFAULT = "superligaen"

BRONZE_CREATE_SQL = """
CREATE TABLE IF NOT EXISTS {db}.bronze.groq__llm_match_discussions (
    match_id     INTEGER,
    season       VARCHAR,
    round_number INTEGER,
    match_name   VARCHAR,
    raw_response VARCHAR,
    generated_at TIMESTAMP
)
"""

PLAYER_QUERY = """
SELECT
    ts.team_side,
    t.team_name,
    p.player_name,
    pa.goals_scored,
    pa.assists,
    pa.own_goals,
    pa.yellow_cards,
    pa.yellow_red_cards,
    pa.red_cards,
    pa.shots_total,
    pa.shots_on_target,
    pa.key_passes,
    pa.big_chances_created,
    pa.rating,
    pa.saves,
    pa.minutes_played
FROM {db}.gold.fct_player_appearances pa
JOIN {db}.gold.dim_match     m  ON m.match_sk      = pa.match_sk
JOIN {db}.gold.dim_player    p  ON p.player_sk     = pa.player_sk
JOIN {db}.gold.dim_team      t  ON t.team_sk       = pa.team_sk
JOIN {db}.gold.dim_team_side ts ON ts.team_side_sk = pa.team_side_sk
WHERE m.match_id = ?
  AND pa.minutes_played > 0
ORDER BY ts.team_side, pa.goals_scored DESC NULLS LAST, pa.rating DESC NULLS LAST
"""

ALL_ROUNDS_SQL = """
SELECT DISTINCT m.match_round_number::INTEGER
FROM {db}.gold.fct_team_matches f
JOIN {db}.gold.dim_match        m  ON m.match_sk         = f.match_sk
JOIN {db}.gold.dim_date         d  ON d.date_sk          = f.date_sk
JOIN {db}.gold.dim_match_result mr ON mr.match_result_sk = f.match_result_sk
WHERE d.season = ?
  AND mr.match_result IN ('Win', 'Draw', 'Loss')
ORDER BY 1
"""

LATEST_ROUND_SQL = """
SELECT MAX(m.match_round_number::INTEGER)
FROM {db}.gold.fct_team_matches f
JOIN {db}.gold.dim_match        m  ON m.match_sk         = f.match_sk
JOIN {db}.gold.dim_date         d  ON d.date_sk          = f.date_sk
JOIN {db}.gold.dim_match_result mr ON mr.match_result_sk = f.match_result_sk
WHERE d.season = ?
  AND mr.match_result IN ('Win', 'Draw', 'Loss')
"""

MATCH_QUERY = """
WITH player_stats AS (
    SELECT
        match_sk,
        team_sk,
        SUM(shots_total)         AS total_shots,
        SUM(shots_on_target)     AS shots_on_goal,
        SUM(big_chances_created) AS big_chances
    FROM {db}.gold.fct_player_appearances
    GROUP BY match_sk, team_sk
)
SELECT
    m.match_id,
    m.match_name,
    m.match_result                                                          AS score,
    m.match_round_type                                                      AS phase,
    d.date::VARCHAR                                                         AS match_date,
    d.day_name,
    m.kick_off_time,
    dt.period_of_day,
    m.match_round_name,
    MAX(CASE WHEN ts.team_side = 'Home' THEN t.team_name        END)        AS home_team,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_scored     END)        AS home_goals,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.goals_ht_scored  END)        AS home_ht_goals,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.ball_possession_pct END)     AS home_possession,
    MAX(CASE WHEN ts.team_side = 'Home' THEN ps.total_shots      END)       AS home_shots,
    MAX(CASE WHEN ts.team_side = 'Home' THEN ps.shots_on_goal    END)       AS home_sog,
    MAX(CASE WHEN ts.team_side = 'Home' THEN ps.big_chances      END)       AS home_big_chances,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.corner_kicks     END)        AS home_corners,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.yellow_cards     END)        AS home_yc,
    MAX(CASE WHEN ts.team_side = 'Home' THEN f.red_cards        END)        AS home_rc,
    MAX(CASE WHEN ts.team_side = 'Home' THEN df.formation       END)        AS home_formation,
    MAX(CASE WHEN ts.team_side = 'Home' THEN dc.coach_name      END)        AS home_coach,
    MAX(CASE WHEN ts.team_side = 'Away' THEN t.team_name        END)        AS away_team,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_scored     END)        AS away_goals,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.goals_ht_scored  END)        AS away_ht_goals,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.ball_possession_pct END)     AS away_possession,
    MAX(CASE WHEN ts.team_side = 'Away' THEN ps.total_shots      END)       AS away_shots,
    MAX(CASE WHEN ts.team_side = 'Away' THEN ps.shots_on_goal    END)       AS away_sog,
    MAX(CASE WHEN ts.team_side = 'Away' THEN ps.big_chances      END)       AS away_big_chances,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.corner_kicks     END)        AS away_corners,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.yellow_cards     END)        AS away_yc,
    MAX(CASE WHEN ts.team_side = 'Away' THEN f.red_cards        END)        AS away_rc,
    MAX(CASE WHEN ts.team_side = 'Away' THEN df.formation       END)        AS away_formation,
    MAX(CASE WHEN ts.team_side = 'Away' THEN dc.coach_name      END)        AS away_coach,
    MAX(ref.referee_common_name)                                            AS referee,
    MAX(st.stadium_name)                                                    AS stadium
FROM {db}.gold.fct_team_matches     f
JOIN {db}.gold.dim_match            m   ON m.match_sk         = f.match_sk
JOIN {db}.gold.dim_date             d   ON d.date_sk          = f.date_sk
JOIN {db}.gold.dim_team             t   ON t.team_sk          = f.team_sk
JOIN {db}.gold.dim_time             dt  ON dt.time_sk         = f.time_sk
JOIN {db}.gold.dim_team_side        ts  ON ts.team_side_sk    = f.team_side_sk
JOIN {db}.gold.dim_match_result     mr  ON mr.match_result_sk = f.match_result_sk
JOIN {db}.gold.dim_formation        df  ON df.formation_sk    = f.formation_sk
JOIN {db}.gold.dim_coach            dc  ON dc.coach_sk        = f.coach_sk
JOIN {db}.gold.dim_referee          ref ON ref.referee_sk     = f.referee_sk
JOIN {db}.gold.dim_stadium          st  ON st.stadium_sk      = f.stadium_sk
LEFT JOIN player_stats              ps  ON ps.match_sk        = f.match_sk
                                       AND ps.team_sk         = f.team_sk
WHERE d.season = ?
  AND m.match_round_number::INTEGER = ?
  AND mr.match_result IN ('Win', 'Draw', 'Loss')
GROUP BY
    m.match_id, m.match_name, m.match_result, m.match_round_type,
    d.date, d.day_name, m.kick_off_time, dt.period_of_day, m.match_round_name
ORDER BY m.match_name
"""


def load_personas(con, db: str) -> list[dict]:
    rows = con.execute(f"""
        SELECT persona_name, sort_order, bio
        FROM {db}.gold.dim_persona
        ORDER BY sort_order
    """).fetchall()
    return [
        {"name": r[0], "sort_order": r[1], "bio": r[2]}
        for r in rows
    ]


def build_player_context(players: list[dict]) -> str:
    home = [p for p in players if p["team_side"] == "Home"]
    away = [p for p in players if p["team_side"] == "Away"]
    home_name = home[0]["team_name"] if home else "Home"
    away_name = away[0]["team_name"] if away else "Away"

    def goal_events(side):
        parts = []
        for p in side:
            tags = []
            if p["goals_scored"]:
                tags.append(f"{p['goals_scored']}G")
            if p["assists"]:
                tags.append(f"{p['assists']}A")
            if p["own_goals"]:
                tags.append(f"{p['own_goals']} OG")
            if tags:
                parts.append(f"{p['player_name']} ({', '.join(tags)})")
        return ", ".join(parts) if parts else "—"

    def card_events(side):
        parts = []
        for p in side:
            tags = []
            if p["yellow_cards"]:
                tags.append("YC")
            if p["yellow_red_cards"]:
                tags.append("2YC/RC")
            if p["red_cards"]:
                tags.append("RC")
            if tags:
                parts.append(f"{p['player_name']} ({', '.join(tags)})")
        return ", ".join(parts) if parts else "—"

    def top_performer(side):
        outfield = [p for p in side if not p["saves"]]
        if not outfield:
            return "—"
        best = max(outfield, key=lambda p: p["rating"] or 0)
        stats = []
        if best["rating"]:
            stats.append(f"rating {best['rating']:.1f}")
        if best["goals_scored"]:
            stats.append(f"{best['goals_scored']} goal{'s' if best['goals_scored'] > 1 else ''}")
        if best["assists"]:
            stats.append(f"{best['assists']} assist{'s' if best['assists'] > 1 else ''}")
        if best["shots_on_target"]:
            stats.append(f"{best['shots_on_target']} shots on target")
        if best["key_passes"]:
            stats.append(f"{best['key_passes']} key passes")
        if best["big_chances_created"]:
            stats.append(f"{best['big_chances_created']} big chance{'s' if best['big_chances_created'] > 1 else ''} created")
        return f"{best['player_name']} — {', '.join(stats)}"

    def goalkeeper(side):
        gks = [p for p in side if p["saves"] is not None]
        if not gks:
            return "—"
        gk = gks[0]
        return f"{gk['player_name']} — {gk['saves']} saves"

    return (
        f"GOAL EVENTS:\n"
        f"  {home_name}: {goal_events(home)}\n"
        f"  {away_name}: {goal_events(away)}\n"
        f"\n"
        f"CARDS:\n"
        f"  {home_name}: {card_events(home)}\n"
        f"  {away_name}: {card_events(away)}\n"
        f"\n"
        f"STANDOUT PERFORMANCES:\n"
        f"  {home_name}: {top_performer(home)}\n"
        f"  {away_name}: {top_performer(away)}\n"
        f"\n"
        f"GOALKEEPERS:\n"
        f"  {home_name}: {goalkeeper(home)}\n"
        f"  {away_name}: {goalkeeper(away)}"
    )


def build_match_context(row: dict, player_context: str) -> str:
    return (
        f"MATCH: {row['match_name']}\n"
        f"Score: {row['score']}  (HT: {row['home_ht_goals']}-{row['away_ht_goals']})\n"
        f"Date: {row['match_date']} ({row['day_name']}, {row['kick_off_time']} — {row['period_of_day']})\n"
        f"Phase: {row['phase']}  |  Venue: {row['stadium']}  |  Referee: {row['referee']}\n"
        f"\n"
        f"HOME — {row['home_team']} [{row['home_formation']}] (Coach: {row['home_coach']})\n"
        f"  Goals: {row['home_goals']}  |  Shots: {row['home_shots']} (on target: {row['home_sog']})  |  Big chances: {row['home_big_chances']}\n"
        f"  Possession: {row['home_possession']}%  |  Corners: {row['home_corners']}  |  YC: {row['home_yc']}  |  RC: {row['home_rc']}\n"
        f"\n"
        f"AWAY — {row['away_team']} [{row['away_formation']}] (Coach: {row['away_coach']})\n"
        f"  Goals: {row['away_goals']}  |  Shots: {row['away_shots']} (on target: {row['away_sog']})  |  Big chances: {row['away_big_chances']}\n"
        f"  Possession: {row['away_possession']}%  |  Corners: {row['away_corners']}  |  YC: {row['away_yc']}  |  RC: {row['away_rc']}\n"
        f"\n"
        f"{player_context}"
    )


def build_prompt(match_context: str, personas: list[dict]) -> str:
    persona_block = "\n".join(
        f"- {p['name']}: {p['bio']}" for p in personas
    )
    persona_order = ", ".join(p["name"] for p in personas)
    return (
        "You are moderating a fan forum thread where four people discuss a Danish Superliga match.\n"
        "Rules:\n"
        "- Use ONLY the stats provided. Do not invent numbers, events, or facts not in the data.\n"
        "- Player names are provided — use them when making specific points.\n"
        "- No xG — it is not available. Do not mention it.\n"
        "- Each post must be 2-4 sentences, opinionated, and specific to this match.\n"
        "- They should reference each other to feel like a real conversation thread.\n"
        "- No generic football commentary — every sentence must be grounded in the match data.\n"
        f"- When referring to other fans by name, use ONLY these exact names: {persona_order}. Never invent or use any other name.\n"
        "\n"
        f"PERSONAS:\n{persona_block}\n"
        "\n"
        f"MATCH DATA:\n{match_context}\n"
        "\n"
        f"Write exactly {len(personas)} posts in order: {persona_order}.\n"
        "Return ONLY a JSON array, no other text:\n"
        "[\n"
        + ",\n".join(f'  {{"persona": "{p["name"]}", "message": "..."}}' for p in personas)
        + "\n]"
    )


def call_groq(client: Groq, match_context: str, personas: list[dict]) -> str:
    prompt = build_prompt(match_context, personas)
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    return response.choices[0].message.content.strip()


def process_round(
    con, client, personas: list[dict], db: str,
    season: str, round_number: int, force: bool, now,
) -> None:
    rows = con.execute(MATCH_QUERY.format(db=db), [season, round_number]).fetchall()
    cols = [d[0] for d in con.description]

    if not rows:
        log.warning(f"No completed matches found for season={season} round={round_number}")
        return

    if force:
        con.execute(
            f"DELETE FROM {db}.bronze.groq__llm_match_discussions WHERE season = ? AND round_number = ?",
            [season, round_number],
        )
        already_done = set()
    else:
        already_done = {
            r[0] for r in con.execute(
                f"SELECT match_id FROM {db}.bronze.groq__llm_match_discussions WHERE season = ? AND round_number = ?",
                [season, round_number],
            ).fetchall()
        }

    pending = [dict(zip(cols, r)) for r in rows if dict(zip(cols, r))["match_id"] not in already_done]
    skipped = len(rows) - len(pending)
    log.info(f"  Round {round_number}: {len(pending)} to generate, {skipped} skipped")

    to_insert = []
    player_cols = None

    for row in pending:
        log.info(f"    → {row['match_name']}")

        player_rows_raw = con.execute(PLAYER_QUERY.format(db=db), [row["match_id"]]).fetchall()
        if player_cols is None:
            player_cols = [d[0] for d in con.description]
        players = [dict(zip(player_cols, r)) for r in player_rows_raw]
        context = build_match_context(row, build_player_context(players))

        try:
            raw = call_groq(client, context, personas)
            to_insert.append((row["match_id"], season, round_number, row["match_name"], raw, now))
        except Exception as exc:
            log.error(f"    Failed for {row['match_name']}: {exc}")

        time.sleep(2)  # stay within free-tier rate limits

    if to_insert:
        con.executemany(
            f"""
            INSERT INTO {db}.bronze.groq__llm_match_discussions
                (match_id, season, round_number, match_name, raw_response, generated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            to_insert,
        )
        log.info(f"  Inserted {len(to_insert)} bronze rows")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate AI round discussions via Groq")
    parser.add_argument("--season",     required=True,       help="Season, e.g. 2024/25")
    parser.add_argument("--round",      type=int,            help="Round number (default: latest completed)")
    parser.add_argument("--db",         default=DB_DEFAULT,  help="MotherDuck database name")
    parser.add_argument("--force",      action="store_true", help="Overwrite existing discussions")
    parser.add_argument("--all-rounds", action="store_true", help="Generate for all completed rounds in the season")
    args = parser.parse_args()

    token = os.environ["MOTHERDUCK_TOKEN"]
    con = duckdb.connect(f"md:{args.db}?motherduck_token={token}")

    con.execute(BRONZE_CREATE_SQL.format(db=args.db))

    personas = load_personas(con, args.db)
    if not personas:
        log.error("No personas found in gold.dim_persona — run 'dbt seed' first")
        return
    log.info(f"Loaded {len(personas)} personas: {[p['name'] for p in personas]}")

    client = Groq(api_key=os.environ["GROQ_API_KEY"])
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    if args.all_rounds:
        if args.force:
            con.execute(
                f"DELETE FROM {args.db}.bronze.groq__llm_match_discussions WHERE season = ?",
                [args.season],
            )
            log.info(f"--force: deleted all bronze rows for season {args.season}")

        rounds = [
            r[0] for r in con.execute(ALL_ROUNDS_SQL.format(db=args.db), [args.season]).fetchall()
        ]
        if not rounds:
            log.error(f"No completed rounds found for season {args.season}")
            return
        log.info(f"Processing {len(rounds)} rounds for season {args.season}")
        for round_number in rounds:
            process_round(con, client, personas, args.db, args.season, round_number, False, now)

    else:
        round_number = args.round
        if round_number is None:
            result = con.execute(LATEST_ROUND_SQL.format(db=args.db), [args.season]).fetchone()
            round_number = result[0] if result else None
            if round_number is None:
                log.error(f"No completed rounds found for season {args.season}")
                return
            log.info(f"Auto-detected latest round: {round_number}")

        process_round(con, client, personas, args.db, args.season, round_number, args.force, now)

    con.close()


if __name__ == "__main__":
    main()
