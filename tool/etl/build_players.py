#!/usr/bin/env python3
"""Phase D7 — build filtered players table and merged player_attributes.

Includes a player when:
  - distinct attribute_id count >= 2, and
  - at least one edge type is club, nation, league, or position.

Writes:
  tool/etl/staging/players_table.csv
  tool/etl/staging/player_attributes.csv
  tool/etl/staging/manifest_preview.json   # player_count for D11 manifest
  tool/etl/reports/build_players_summary.json

Exit 1 if upstream staging is missing or DoD validation fails.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS, STAGING_NORM  # noqa: E402
from search_rank import compute_search_rank, load_search_rank_boosts  # noqa: E402

STAGING = _ETL_DIR / "staging"
PLAYERS_TABLE_PATH = STAGING / "players_table.csv"
PLAYER_ATTRIBUTES_PATH = STAGING / "player_attributes.csv"
MANIFEST_PREVIEW_PATH = STAGING / "manifest_preview.json"
SUMMARY_PATH = REPORTS / "build_players_summary.json"

EDGE_FILES = (
    "player_club.csv",
    "player_nation.csv",
    "player_league.csv",
    "player_position.csv",
)

QUALIFYING_PREFIXES = ("club:", "nation:", "league:", "pos:")
MIN_DISTINCT_ATTRIBUTES = 2

PLAYERS_FIELDS = (
    "id",
    "display_name",
    "search_text",
    "position",
    "nation",
    "search_rank",
)
ATTRIBUTE_FIELDS = ("player_id", "attribute_id", "source")


def tm_id(player_id: str) -> str:
    return f"tm:{player_id}"


def attribute_kind(attribute_id: str) -> str:
    return attribute_id.split(":", 1)[0] if ":" in attribute_id else ""


def load_all_edges() -> tuple[list[dict[str, str]], dict[str, set[str]], dict[str, set[str]]]:
    """Load edge rows and per-player distinct attributes / qualifying kinds."""
    rows: list[dict[str, str]] = []
    distinct_attrs: dict[str, set[str]] = defaultdict(set)
    kinds: dict[str, set[str]] = defaultdict(set)

    for filename in EDGE_FILES:
        path = STAGING / filename
        if not path.is_file():
            raise FileNotFoundError(f"Missing {path} (run D3–D6 first)")

        with path.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                player_id = (row.get("player_id") or "").strip()
                attribute_id = (row.get("attribute_id") or "").strip()
                source = (row.get("source") or "").strip()
                if not player_id or not attribute_id or not source:
                    continue
                rows.append(
                    {
                        "player_id": player_id,
                        "attribute_id": attribute_id,
                        "source": source,
                    }
                )
                distinct_attrs[player_id].add(attribute_id)
                kind = attribute_kind(attribute_id)
                if kind:
                    kinds[player_id].add(kind)

    return rows, distinct_attrs, kinds


def qualifying_player_ids(
    distinct_attrs: dict[str, set[str]], kinds: dict[str, set[str]]
) -> set[str]:
    qualified: set[str] = set()
    for player_id, attrs in distinct_attrs.items():
        if len(attrs) < MIN_DISTINCT_ATTRIBUTES:
            continue
        player_kinds = kinds.get(player_id, set())
        if not player_kinds & {"club", "nation", "league", "pos"}:
            continue
        qualified.add(player_id)
    return qualified


def load_player_profiles() -> dict[str, dict[str, str]]:
    profiles: dict[str, dict[str, str]] = {}
    path = STAGING_NORM / "players.csv"
    if not path.is_file():
        raise FileNotFoundError(f"Missing {path} (run D2 normalize first)")

    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            if not player_id:
                continue
            profiles[player_id] = {
                "display_name": (row.get("display_name") or row.get("name") or "").strip(),
                "search_text": (row.get("search_text") or "").strip(),
                "nation": (row.get("nation_slug") or "").strip(),
                "market_value_in_eur": (row.get("market_value_in_eur") or "").strip(),
                "highest_market_value_in_eur": (
                    row.get("highest_market_value_in_eur") or ""
                ).strip(),
            }

    legendary_path = STAGING / "legendary" / "legendary_player_profiles.csv"
    if legendary_path.is_file():
        with legendary_path.open(encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                player_id = (row.get("player_id") or "").strip()
                if not player_id or player_id in profiles:
                    continue
                profiles[player_id] = {
                    "display_name": (row.get("display_name") or "").strip(),
                    "search_text": (row.get("search_text") or "").strip(),
                    "nation": (row.get("nation_slug") or "").strip(),
                    "market_value_in_eur": "",
                    "highest_market_value_in_eur": "",
                }
    return profiles


def load_position_cache() -> dict[str, str]:
    cache: dict[str, str] = {}
    path = STAGING / "player_position.csv"
    if not path.is_file():
        return cache
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            bucket = (row.get("position_bucket") or "").strip()
            if player_id and bucket:
                cache[player_id] = bucket
    return cache


def write_players_table(
    qualified: set[str],
    profiles: dict[str, dict[str, str]],
    positions: dict[str, str],
    rank_boosts: dict[str, int],
) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    missing_profile = 0

    for player_id in sorted(qualified, key=lambda pid: (len(pid), pid)):
        profile = profiles.get(player_id)
        if not profile:
            missing_profile += 1
            continue
        search_rank = compute_search_rank(
            profile.get("market_value_in_eur"),
            profile.get("highest_market_value_in_eur"),
            manual_boost=rank_boosts.get(player_id, 0),
        )
        rows.append(
            {
                "id": tm_id(player_id),
                "display_name": profile["display_name"],
                "search_text": profile["search_text"],
                "position": positions.get(player_id, ""),
                "nation": profile["nation"],
                "search_rank": str(search_rank),
            }
        )

    if missing_profile:
        raise ValueError(f"{missing_profile} qualified players missing from normalized players.csv")

    STAGING.mkdir(parents=True, exist_ok=True)
    with PLAYERS_TABLE_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=PLAYERS_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    return rows


def write_player_attributes(
    all_edges: list[dict[str, str]], qualified: set[str]
) -> list[dict[str, str]]:
    rows = [e for e in all_edges if e["player_id"] in qualified]
    rows.sort(key=lambda r: (r["player_id"], r["attribute_id"], r["source"]))

    with PLAYER_ATTRIBUTES_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=ATTRIBUTE_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    return rows


def validate_output(
    player_rows: list[dict[str, str]], attribute_rows: list[dict[str, str]]
) -> list[str]:
    errors: list[str] = []
    attrs_by_player: dict[str, set[str]] = defaultdict(set)

    for row in attribute_rows:
        attrs_by_player[row["player_id"]].add(row["attribute_id"])

    for row in player_rows:
        raw_id = row["id"].removeprefix("tm:")
        count = len(attrs_by_player.get(raw_id, set()))
        if count < MIN_DISTINCT_ATTRIBUTES:
            errors.append(f"player {row['id']} has only {count} distinct attribute(s)")

    table_ids = {row["id"].removeprefix("tm:") for row in player_rows}
    attr_ids = set(attrs_by_player)
    if table_ids != attr_ids:
        extra = attr_ids - table_ids
        missing = table_ids - attr_ids
        if extra or missing:
            errors.append(
                f"players_table vs player_attributes mismatch "
                f"(extra={len(extra)}, missing={len(missing)})"
            )

    return errors


def main() -> int:
    try:
        all_edges, distinct_attrs, kinds = load_all_edges()
        profiles = load_player_profiles()
        positions = load_position_cache()
    except FileNotFoundError as exc:
        print(f"D7 build FAILED: {exc}", file=sys.stderr)
        return 1

    qualified = qualifying_player_ids(distinct_attrs, kinds)
    rank_boosts = load_search_rank_boosts()
    player_rows = write_players_table(qualified, profiles, positions, rank_boosts)
    attribute_rows = write_player_attributes(all_edges, qualified)

    validation_errors = validate_output(player_rows, attribute_rows)
    if validation_errors:
        print("D7 build FAILED: validation errors:", file=sys.stderr)
        for err in validation_errors[:20]:
            print(f"  - {err}", file=sys.stderr)
        return 1

    total_tm_players = len(profiles)
    player_count = len(player_rows)
    edge_rows = len(attribute_rows)

    manifest_preview = {
        "player_count": player_count,
        "attribute_edge_rows": edge_rows,
        "note": "Merged into tiki_taka.db manifest at D11",
    }
    with MANIFEST_PREVIEW_PATH.open("w", encoding="utf-8") as f:
        json.dump(manifest_preview, f, indent=2)
        f.write("\n")

    summary = {
        "phase": "D7",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "players_table_output": str(PLAYERS_TABLE_PATH),
        "player_attributes_output": str(PLAYER_ATTRIBUTES_PATH),
        "manifest_preview": str(MANIFEST_PREVIEW_PATH),
        "player_count": player_count,
        "manifest_player_count": player_count,
        "attribute_edge_rows": edge_rows,
        "total_tm_players_in_normalized_csv": total_tm_players,
        "players_with_any_attribute_edge": len(distinct_attrs),
        "players_excluded_by_filter": total_tm_players - player_count,
        "filter_note": (
            f"Included {player_count:,} of {total_tm_players:,} TM players "
            f"(≥{MIN_DISTINCT_ATTRIBUTES} distinct attributes incl. club/nation/league/position)"
        ),
        "validation_passed": True,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    print(
        f"D7 build OK: {player_count:,} players (of {total_tm_players:,} TM rows), "
        f"{edge_rows:,} attribute edges"
    )
    print(f"  players: {PLAYERS_TABLE_PATH}")
    print(f"  attributes: {PLAYER_ATTRIBUTES_PATH}")
    print(f"  manifest preview: {MANIFEST_PREVIEW_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
