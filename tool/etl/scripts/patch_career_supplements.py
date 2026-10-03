#!/usr/bin/env python3
"""Apply famous-50 allowlisted club supplements to tiki_taka.db.

Reads expected careers from famous50_careers.py, adds only missing club and
top-5 league_club edges, updates attribute_pair_stats, and syncs qa_club_edges.yaml.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent
_ETL = _SCRIPTS.parent
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from famous50_careers import (  # noqa: E402
    CLUB_NAMES,
    CLUB_TOP5_LEAGUE,
    FAMOUS_50_CAREERS,
    PLAYER_NAMES,
)

REPO = _SCRIPTS.parents[2]
ASSET_DB = REPO / "assets" / "db" / "tiki_taka.db"
OUTPUT_DB = REPO / "tool" / "etl" / "output" / "tiki_taka.db"
QA_EDGES_PATH = _ETL / "config" / "qa_club_edges.yaml"


def tm_id(raw: str) -> str:
    return raw if raw.startswith("tm:") else f"tm:{raw}"


def collect_missing(conn: sqlite3.Connection) -> list[tuple[str, str, str]]:
    """Return (player_id, club_id, player_name) for clubs not yet linked."""
    cur = conn.cursor()
    missing: list[tuple[str, str, str]] = []

    for raw_pid, clubs in FAMOUS_50_CAREERS.items():
        player_id = tm_id(raw_pid)
        cur.execute("SELECT 1 FROM players WHERE id = ?", (player_id,))
        if not cur.fetchone():
            continue

        cur.execute(
            """
            SELECT DISTINCT attribute_id
            FROM player_attributes
            WHERE player_id = ? AND attribute_id LIKE 'club:%'
            """,
            (player_id,),
        )
        have = {row[0].split(":", 1)[1] for row in cur.fetchall()}
        name = PLAYER_NAMES.get(raw_pid, raw_pid)

        for club_id in clubs:
            if club_id not in have:
                missing.append((raw_pid, club_id, name))

    return missing


def player_has_attribute(
    cur: sqlite3.Cursor, player_id: str, attribute_id: str
) -> bool:
    cur.execute(
        """
        SELECT 1 FROM player_attributes
        WHERE player_id = ? AND attribute_id = ?
        LIMIT 1
        """,
        (player_id, attribute_id),
    )
    return cur.fetchone() is not None


def insert_edge(
    cur: sqlite3.Cursor, player_id: str, attribute_id: str, source: str
) -> bool:
    if player_has_attribute(cur, player_id, attribute_id):
        return False
    cur.execute(
        """
        INSERT INTO player_attributes (player_id, attribute_id, source)
        VALUES (?, ?, ?)
        """,
        (player_id, attribute_id, source),
    )
    return True


def recompute_pair_stats_for_players(
    conn: sqlite3.Connection, player_ids: set[str]
) -> int:
    cur = conn.cursor()
    cur.execute(
        f"""
        SELECT DISTINCT attribute_id
        FROM player_attributes
        WHERE player_id IN ({",".join("?" for _ in player_ids)})
        """,
        list(player_ids),
    )
    touched_attrs = {row[0] for row in cur.fetchall()}
    if not touched_attrs:
        return 0

    cur.execute("SELECT player_id, attribute_id FROM player_attributes")
    by_player: dict[str, set[str]] = defaultdict(set)
    for pid, attr in cur.fetchall():
        by_player[pid].add(attr)

    pair_players: dict[tuple[str, str], set[str]] = defaultdict(set)
    for pid, attrs in by_player.items():
        attr_list = sorted(attrs)
        for i, a in enumerate(attr_list):
            for b in attr_list[i + 1 :]:
                if a in touched_attrs or b in touched_attrs:
                    pair_players[(a, b)].add(pid)

    updated = 0
    for (attr_a, attr_b), pids in pair_players.items():
        sample = json.dumps(sorted(pids)[:10])
        count = len(pids)
        for a, b in ((attr_a, attr_b), (attr_b, attr_a)):
            cur.execute(
                """
                INSERT INTO attribute_pair_stats (attr_a, attr_b, player_count, sample_player_ids)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(attr_a, attr_b) DO UPDATE SET
                  player_count = excluded.player_count,
                  sample_player_ids = excluded.sample_player_ids
                """,
                (a, b, count, sample),
            )
            updated += 1
    return updated


def patch_database(db_path: Path) -> dict[str, int]:
    if not db_path.is_file():
        return {"skipped": 1}

    conn = sqlite3.connect(db_path)
    missing = collect_missing(conn)
    cur = conn.cursor()
    added_clubs = 0
    added_leagues = 0
    skipped = 0
    patched_players: set[str] = set()

    for raw_pid, club_id, _name in missing:
        player_id = tm_id(raw_pid)
        club_attr = f"club:{club_id}"

        if insert_edge(cur, player_id, club_attr, "transfer"):
            added_clubs += 1
            patched_players.add(player_id)
        else:
            skipped += 1

        league_id = CLUB_TOP5_LEAGUE.get(club_id)
        if league_id:
            league_attr = f"league:{league_id}"
            if insert_edge(cur, player_id, league_attr, "league_club"):
                added_leagues += 1
            else:
                skipped += 1

    pairs_updated = 0
    if patched_players:
        pairs_updated = recompute_pair_stats_for_players(conn, patched_players)

    conn.commit()
    conn.close()

    return {
        "added_clubs": added_clubs,
        "added_leagues": added_leagues,
        "skipped_existing": skipped,
        "pairs_updated": pairs_updated,
        "missing_before": len(missing),
    }


def write_qa_club_edges_yaml(missing: list[tuple[str, str, str]]) -> None:
    """Sync qa_club_edges.yaml with all supplements that were applied or needed."""
    lines = [
        "# Supplemental player→club edges when scraped transfers/appearances omit known stints.",
        "# Used only when the edge is not already emitted by D3 merge (see merge_player_club.py).",
        "# Auto-synced from famous50_careers.py via patch_career_supplements.py",
        'version: "1"',
        "edges:",
    ]
    for raw_pid, club_id, name in sorted(missing, key=lambda t: (t[2], t[1])):
        club_name = CLUB_NAMES.get(club_id, club_id)
        lines.extend(
            [
                f'  - player_id: "{raw_pid}"',
                f'    club_id: "{club_id}"',
                "    source: transfer",
                f'    reason: "{name} — {club_name}; pre-2012 or missing from scrape"',
            ]
        )
    QA_EDGES_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    if not ASSET_DB.is_file():
        print(f"Database not found: {ASSET_DB}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(ASSET_DB)
    missing = collect_missing(conn)
    conn.close()

    print(f"Missing allowlisted club edges before patch: {len(missing)}")
    for raw_pid, club_id, name in missing:
        club_name = CLUB_NAMES.get(club_id, club_id)
        print(f"  {name} (tm:{raw_pid}) -> {club_name}")

    if missing:
        write_qa_club_edges_yaml(missing)

    results: dict[str, dict[str, int]] = {}
    for db_path in (ASSET_DB, OUTPUT_DB):
        stats = patch_database(db_path)
        if "skipped" not in stats:
            results[str(db_path)] = stats
            print(
                f"\nPatched {db_path.name}: "
                f"+{stats['added_clubs']} clubs, +{stats['added_leagues']} leagues, "
                f"{stats['pairs_updated']} pair-stat rows updated"
            )
        else:
            print(f"\nSkipped missing DB: {db_path}")

    if not missing:
        print("\nAll famous-50 allowlisted clubs already present — no changes.")
        return 0

    # Verify
    conn = sqlite3.connect(ASSET_DB)
    still_missing = collect_missing(conn)
    conn.close()
    if still_missing:
        print(f"\nWARNING: {len(still_missing)} edges still missing after patch", file=sys.stderr)
        return 1

    print(f"\nVerified: 0 missing edges across famous-50 careers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
