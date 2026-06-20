#!/usr/bin/env python3
"""Phase 2 — merge legendary staging supplements into TM edge/profile CSVs.

Runs after ingest_legendary_players.py and before build_players.py (D7).
"""
from __future__ import annotations

import csv
import json
import sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS, STAGING_NORM, collapse_whitespace  # noqa: E402

ROOT = _ETL_DIR.parents[1]
STAGING = _ETL_DIR / "staging"
LEGENDARY_DIR = STAGING / "legendary"
LEGENDARY_CSV = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
SUMMARY_PATH = REPORTS / "merge_legendary_summary.json"

EDGE_TARGETS: tuple[tuple[str, str], ...] = (
    ("player_club.csv", "legendary_player_club.csv"),
    ("player_nation.csv", "legendary_player_nation.csv"),
    ("player_league.csv", "legendary_player_league.csv"),
    ("player_position.csv", "legendary_player_position.csv"),
)


def load_csv_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.is_file():
        return [], []
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = list(reader.fieldnames or [])
        return fieldnames, list(reader)


def write_csv_rows(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def merge_edge_file(target_name: str, legendary_name: str) -> dict[str, int]:
    target_path = STAGING / target_name
    legendary_path = LEGENDARY_DIR / legendary_name
    target_fields, target_rows = load_csv_rows(target_path)
    legendary_fields, legendary_rows = load_csv_rows(legendary_path)

    if not target_fields:
        raise FileNotFoundError(f"Missing or empty edge file: {target_path}")
    if not legendary_fields:
        raise FileNotFoundError(f"Missing legendary edge file: {legendary_path}")

    merged = list(target_rows)
    seen = {
        ((row.get("player_id") or "").strip(), (row.get("attribute_id") or "").strip())
        for row in target_rows
    }
    added = 0
    skipped_duplicate = 0

    for row in legendary_rows:
        player_id = (row.get("player_id") or "").strip()
        attribute_id = (row.get("attribute_id") or "").strip()
        if not player_id or not attribute_id:
            continue
        key = (player_id, attribute_id)
        if key in seen:
            skipped_duplicate += 1
            continue
        merged_row = {field: "" for field in target_fields}
        for field in legendary_fields:
            if field in merged_row:
                merged_row[field] = (row.get(field) or "").strip()
        merged.append(merged_row)
        seen.add(key)
        added += 1

    merged.sort(key=lambda r: (r.get("player_id", ""), r.get("attribute_id", ""), r.get("source", "")))
    write_csv_rows(target_path, target_fields, merged)
    return {
        "existing_rows": len(target_rows),
        "legendary_rows": len(legendary_rows),
        "added_rows": added,
        "skipped_duplicate_attribute": skipped_duplicate,
        "total_rows": len(merged),
    }


def load_legendary_citizenship() -> dict[str, str]:
    if not LEGENDARY_CSV.is_file():
        return {}
    mapping: dict[str, str] = {}
    with LEGENDARY_CSV.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            tm_id = (row.get("transfermarkt_id") or "").strip()
            if tm_id:
                mapping[tm_id] = collapse_whitespace(row.get("Nationality") or "")
    return mapping


def merge_profiles() -> dict[str, int]:
    players_path = STAGING_NORM / "players.csv"
    profiles_path = LEGENDARY_DIR / "legendary_player_profiles.csv"
    if not players_path.is_file():
        raise FileNotFoundError(f"Missing {players_path}")
    if not profiles_path.is_file():
        raise FileNotFoundError(f"Missing {profiles_path}")

    fieldnames, rows = load_csv_rows(players_path)
    _, legendary_rows = load_csv_rows(profiles_path)
    citizenship_by_id = load_legendary_citizenship()

    if "wikidata_qid" not in fieldnames:
        fieldnames.append("wikidata_qid")

    existing_ids = {(row.get("player_id") or "").strip() for row in rows}
    added = 0

    for legend in legendary_rows:
        player_id = (legend.get("player_id") or "").strip()
        if not player_id or player_id in existing_ids:
            continue

        display_name = (legend.get("display_name") or "").strip()
        new_row = {field: "" for field in fieldnames}
        new_row.update(
            {
                "player_id": player_id,
                "name": display_name,
                "display_name": display_name,
                "search_text": (legend.get("search_text") or "").strip(),
                "country_of_citizenship": citizenship_by_id.get(player_id, ""),
                "nation_slug": (legend.get("nation_slug") or "").strip(),
                "wikidata_qid": (legend.get("wikidata_qid") or "").strip(),
            }
        )
        rows.append(new_row)
        existing_ids.add(player_id)
        added += 1

    rows.sort(key=lambda r: (len(r.get("player_id", "")), r.get("player_id", "")))
    write_csv_rows(players_path, fieldnames, rows)
    return {
        "existing_profiles": len(existing_ids) - added,
        "legendary_profiles": len(legendary_rows),
        "added_profiles": added,
        "total_profiles": len(rows),
    }


def merge_all() -> dict[str, object]:
    edge_stats: dict[str, dict[str, int]] = {}
    for target_name, legendary_name in EDGE_TARGETS:
        edge_stats[target_name] = merge_edge_file(target_name, legendary_name)

    profile_stats = merge_profiles()
    return {"profiles": profile_stats, "edges": edge_stats}


def main() -> int:
    missing = [str(LEGENDARY_DIR / name) for _, name in EDGE_TARGETS if not (LEGENDARY_DIR / name).is_file()]
    missing.extend(
        str(path)
        for path in (STAGING_NORM / "players.csv", STAGING / "player_club.csv")
        if not path.is_file()
    )
    if missing:
        print("Merge FAILED: missing inputs:", file=sys.stderr)
        for path in missing:
            print(f"  - {path}", file=sys.stderr)
        return 1

    try:
        stats = merge_all()
    except FileNotFoundError as exc:
        print(f"Merge FAILED: {exc}", file=sys.stderr)
        return 1

    summary = {
        "phase": "legendary_merge",
        "merged_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        **stats,
    }
    REPORTS.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("Legendary merge OK")
    print(f"  profiles added: {stats['profiles']['added_profiles']}")
    for target_name, edge in stats["edges"].items():
        print(
            f"  {target_name}: +{edge['added_rows']} rows "
            f"(skipped {edge['skipped_duplicate_attribute']} duplicate attributes)"
        )
    print(f"  summary: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
