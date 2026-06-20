#!/usr/bin/env python3
"""Delete DB players whose display_name matches a legendary dataset name."""

from __future__ import annotations

import csv
import json
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGENDARY_CSV = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"
REPORT_PATH = ROOT / "legendary-players" / "legendary_name_deletions.json"


def normalize_name(value: str) -> str:
    text = (value or "").strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def load_legendary_names() -> dict[str, str]:
    rows = list(csv.DictReader(LEGENDARY_CSV.open(encoding="utf-8")))
    mapping: dict[str, str] = {}
    for row in rows:
        name = (row.get("Player Name") or "").strip()
        if not name:
            continue
        mapping[normalize_name(name)] = name
    return mapping


def find_matches(connection: sqlite3.Connection, legendary_names: dict[str, str]) -> list[dict[str, str]]:
    cursor = connection.cursor()
    cursor.execute("SELECT id, display_name FROM players")
    matches: list[dict[str, str]] = []
    for player_id, display_name in cursor.fetchall():
        key = normalize_name(display_name)
        if key in legendary_names:
            matches.append(
                {
                    "player_id": player_id,
                    "display_name": display_name,
                    "legendary_name": legendary_names[key],
                }
            )
    return sorted(matches, key=lambda item: normalize_name(item["display_name"]))


def delete_players(connection: sqlite3.Connection, player_ids: list[str]) -> dict[str, int]:
    if not player_ids:
        return {"player_attributes": 0, "player_aliases": 0, "players": 0}

    placeholders = ",".join("?" for _ in player_ids)
    cursor = connection.cursor()

    cursor.execute(
        f"DELETE FROM player_attributes WHERE player_id IN ({placeholders})",
        player_ids,
    )
    deleted_attributes = cursor.rowcount

    cursor.execute(
        f"DELETE FROM player_aliases WHERE player_id IN ({placeholders})",
        player_ids,
    )
    deleted_aliases = cursor.rowcount

    cursor.execute(
        f"DELETE FROM players WHERE id IN ({placeholders})",
        player_ids,
    )
    deleted_players = cursor.rowcount

    return {
        "player_attributes": deleted_attributes,
        "player_aliases": deleted_aliases,
        "players": deleted_players,
    }


def main() -> None:
    legendary_names = load_legendary_names()
    connection = sqlite3.connect(DB_PATH)
    connection.execute("PRAGMA foreign_keys = ON")

    cursor = connection.cursor()
    cursor.execute("SELECT COUNT(*) FROM players")
    players_before = cursor.fetchone()[0]

    matches = find_matches(connection, legendary_names)
    player_ids = [match["player_id"] for match in matches]

    deleted_counts = delete_players(connection, player_ids)
    connection.commit()

    cursor.execute("SELECT COUNT(*) FROM players")
    players_after = cursor.fetchone()[0]

    report = {
        "deleted_at": datetime.now(timezone.utc).isoformat(),
        "database": str(DB_PATH),
        "legendary_name_count": len(legendary_names),
        "matched_player_count": len(matches),
        "players_before": players_before,
        "players_after": players_after,
        "deleted_counts": deleted_counts,
        "deleted_players": matches,
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Legendary names: {len(legendary_names)}")
    print(f"Deleted players: {len(matches)}")
    print(f"Players before: {players_before}")
    print(f"Players after: {players_after}")
    print(f"Report: {REPORT_PATH}")

    connection.close()


if __name__ == "__main__":
    main()
