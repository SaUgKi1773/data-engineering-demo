#!/usr/bin/env python3
"""
Generate AI round discussions using Google Gemini.

Reads match data from the gold layer, generates persona-based commentary
for each match in the given season/round, and writes results to
superligaen.gold.llm_round_discussions.

Usage:
  python scripts/generate_round_discussions.py --season 2024/25 --round 26
  python scripts/generate_round_discussions.py --season 2024/25  # auto-detects latest round
  python scripts/generate_round_discussions.py --season 2024/25 --round 26 --db superligaen_dev
"""

import argparse
import json
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

PERSONAS = [
    {
        "name": "Lars",
        "icon": "📊",
        "sort_order": 1,
        "bio": (
            "Data analyst in his early 30s. Trusts only the numbers — shots, possession, "
            "big chances, pass accuracy, cards. Never calls a win 'lucky' when the stats "
            "back it up. Precise, occasionally smug, always grounded in the actual data."
        ),
    },
    {
        "name": "Bent",
        "icon": "⚽",
        "sort_order": 2,
        "bio": (
            "68-year-old lifelong Danish football fan. Watched the Superliga since it began. "
            "Distrusts statistics — thinks you learn everything by watching the game. Values "
            "hard work, direct play, and results. Blunt and opinionated, occasionally refers "
            "to 'the old days' but always grounds his point in what happened in this match."
        ),
    },
    {
        "name": "Magnus",
        "icon": "🔴",
        "sort_order": 3,
        "bio": (
            "Passionate FC Nordsjælland fan. Even when FCN aren't playing he relates the "
            "match back to FCN — comparing styles, youth development, what FCN would have "
            "done differently. Knowledgeable but openly biased. If FCN are in this match "
            "he is extremely emotionally invested — elated or devastated."
        ),
    },
    {
        "name": "Sofie",
        "icon": "🎙️",
        "sort_order": 4,
        "bio": (
            "Former professional player, now a TV pundit. Focuses on tactics: formations, "
            "pressing triggers, transitions, individual positioning. Calm but incisive. "
            "Pushes back on Lars when stats miss the tactical story, and on Bent when "
            "old-school thinking misses something structural about the game."
        ),
    },
]

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS {db}.gold.llm_round_discussions (
    season       VARCHAR,
    round_number INTEGER,
    match_name   VARCHAR,
    persona_name VARCHAR,
    persona_icon VARCHAR,
    sort_order   INTEGER,
    message      VARCHAR,
    generated_at TIMESTAMP
)
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
    m.match_name, m.match_result, m.match_round_type,
    d.date, d.day_name, m.kick_off_time, dt.period_of_day, m.match_round_name
ORDER BY m.match_name
"""


def build_match_context(row: dict) -> str:
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
        f"  Possession: {row['away_possession']}%  |  Corners: {row['away_corners']}  |  YC: {row['away_yc']}  |  RC: {row['away_rc']}"
    )


def build_prompt(match_context: str) -> str:
    persona_block = "\n".join(
        f"- {p['name']} ({p['icon']}): {p['bio']}" for p in PERSONAS
    )
    return (
        "You are moderating a fan forum thread where four people discuss a Danish Superliga match.\n"
        "Rules:\n"
        "- Use ONLY the stats provided. Do not invent numbers, player names, or facts not in the data.\n"
        "- No xG — it is not available. Do not mention it.\n"
        "- Each post must be 2-4 sentences, opinionated, and specific to this match.\n"
        "- They should reference each other to feel like a real conversation thread.\n"
        "- No generic football commentary — every sentence must be grounded in the match data.\n"
        "\n"
        f"PERSONAS:\n{persona_block}\n"
        "\n"
        f"MATCH DATA:\n{match_context}\n"
        "\n"
        "Write exactly 4 posts in order: Lars, Bent, Magnus, Sofie.\n"
        "Return ONLY a JSON array, no other text:\n"
        '[\n'
        '  {"persona": "Lars",   "message": "..."},\n'
        '  {"persona": "Bent",   "message": "..."},\n'
        '  {"persona": "Magnus", "message": "..."},\n'
        '  {"persona": "Sofie",  "message": "..."}\n'
        ']'
    )


def call_groq(client: Groq, match_context: str) -> list[dict]:
    prompt = build_prompt(match_context)
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    text = response.choices[0].message.content.strip()
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate AI round discussions via Gemini")
    parser.add_argument("--season", required=True, help="Season, e.g. 2024/25")
    parser.add_argument("--round",  type=int,      help="Round number (auto-detects latest if omitted)")
    parser.add_argument("--db",     default=DB_DEFAULT, help="MotherDuck database name")
    args = parser.parse_args()

    token = os.environ["MOTHERDUCK_TOKEN"]
    con = duckdb.connect(f"md:{args.db}?motherduck_token={token}")

    con.execute(CREATE_TABLE_SQL.format(db=args.db))

    round_number = args.round
    if round_number is None:
        result = con.execute(LATEST_ROUND_SQL.format(db=args.db), [args.season]).fetchone()
        round_number = result[0] if result else None
        if round_number is None:
            log.error(f"No completed rounds found for season {args.season}")
            return
        log.info(f"Auto-detected latest round: {round_number}")

    client = Groq(api_key=os.environ["GROQ_API_KEY"])

    rows = con.execute(MATCH_QUERY.format(db=args.db), [args.season, round_number]).fetchall()
    cols = [d[0] for d in con.description]

    if not rows:
        log.warning(f"No completed matches found for season={args.season} round={round_number}")
        return

    log.info(f"Found {len(rows)} matches — generating discussions")

    con.execute(
        f"DELETE FROM {args.db}.gold.llm_round_discussions WHERE season = ? AND round_number = ?",
        [args.season, round_number],
    )

    persona_map = {p["name"]: p for p in PERSONAS}
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    to_insert = []

    for match_row in rows:
        row = dict(zip(cols, match_row))
        context = build_match_context(row)
        log.info(f"  → {row['match_name']}")

        try:
            posts = call_groq(client, context)
            for post in posts:
                p = persona_map[post["persona"]]
                to_insert.append((
                    args.season,
                    round_number,
                    row["match_name"],
                    p["name"],
                    p["icon"],
                    p["sort_order"],
                    post["message"],
                    now,
                ))
        except Exception as exc:
            log.error(f"Failed for {row['match_name']}: {exc}")

        time.sleep(2)  # stay within free-tier rate limits

    if to_insert:
        con.executemany(
            f"""
            INSERT INTO {args.db}.gold.llm_round_discussions
                (season, round_number, match_name, persona_name, persona_icon,
                 sort_order, message, generated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            to_insert,
        )
        log.info(f"Inserted {len(to_insert)} discussion rows")

    con.close()


if __name__ == "__main__":
    main()
