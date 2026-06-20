#!/usr/bin/env python3
"""Phase D9 — precompute attribute_pair_stats for board viability.

Cross-type and same-type (club×club, league×league) allowlisted pairs get
DISTINCT player intersection counts and sample player ids.

Writes:
  tool/etl/staging/attribute_pair_stats.csv
  tool/etl/reports/forbidden_pairs.json
  tool/etl/reports/build_attribute_pair_stats_summary.json

Exit 1 if D7 player_attributes missing or DoD validation fails.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS, STAGING_NORM, load_yaml  # noqa: E402

STAGING = _ETL_DIR / "staging"
STATS_PATH = STAGING / "attribute_pair_stats.csv"
FORBIDDEN_PATH = REPORTS / "forbidden_pairs.json"
SUMMARY_PATH = REPORTS / "build_attribute_pair_stats_summary.json"
PLAYER_ATTRIBUTES_PATH = STAGING / "player_attributes.csv"
BOARDS_PATH = STAGING / "boards.csv"
BOARD_SLOTS_PATH = STAGING / "board_slots.csv"

MIN_INTERSECTION_FOR_BOARDS = 3
SAMPLE_PLAYER_LIMIT = 5

STATS_FIELDS = ("attr_a", "attr_b", "player_count", "sample_player_ids")

# v1 curated board templates (D10): row/col type mixes
BOARD_TEMPLATE_TYPES = (
    ("club", "nation"),
    ("league", "club"),
)

# Runtime random boards: same-type pairs for club×club and league×league cells
SAME_TYPE_PAIR_TYPES = ("club", "league")

RUNTIME_TEMPLATE_TYPES = BOARD_TEMPLATE_TYPES + (
    ("club", "club"),
    ("league", "league"),
)


def attribute_type(attribute_id: str) -> str:
    return attribute_id.split(":", 1)[0] if ":" in attribute_id else ""


def canonical_pair(attr_a: str, attr_b: str) -> tuple[str, str]:
    return (attr_a, attr_b) if attr_a < attr_b else (attr_b, attr_a)


def tm_sample_id(raw_player_id: str) -> str:
    return raw_player_id if raw_player_id.startswith("tm:") else f"tm:{raw_player_id}"


def load_board_eligible_attributes() -> list[str]:
    attrs: list[str] = []

    clubs = load_yaml("clubs_allowlist.yaml").get("clubs") or {}
    for club_id in clubs.values():
        attrs.append(f"club:{club_id}")

    nations = load_yaml("nations_allowlist.yaml").get("nations") or {}
    for slug in nations.values():
        attrs.append(f"nation:{slug}")

    leagues = load_yaml("leagues_allowlist.yaml").get("leagues") or {}
    for comp_id in leagues.values():
        attrs.append(f"league:{str(comp_id).upper()}")

    for bucket in ("GK", "DEF", "MID", "FWD"):
        attrs.append(f"pos:{bucket}")

    return sorted(set(attrs))


def attributes_by_type(attributes: list[str]) -> dict[str, list[str]]:
    by_type: dict[str, list[str]] = defaultdict(list)
    for attr in attributes:
        by_type[attribute_type(attr)].append(attr)
    return by_type


def template_pairs_for_types(
    attributes: list[str], type_mixes: tuple[tuple[str, str], ...]
) -> set[tuple[str, str]]:
    """Pairs that match board row/col type mixes."""
    by_type = attributes_by_type(attributes)
    pairs: set[tuple[str, str]] = set()
    for type_a, type_b in type_mixes:
        for attr_a in by_type.get(type_a, []):
            for attr_b in by_type.get(type_b, []):
                pairs.add(canonical_pair(attr_a, attr_b))
    return pairs


def template_cross_type_pairs(attributes: list[str]) -> set[tuple[str, str]]:
    return template_pairs_for_types(attributes, BOARD_TEMPLATE_TYPES)


def template_runtime_pairs(attributes: list[str]) -> set[tuple[str, str]]:
    return template_pairs_for_types(attributes, RUNTIME_TEMPLATE_TYPES)


def same_type_pairs(
    attributes: list[str], types: tuple[str, ...] = SAME_TYPE_PAIR_TYPES
) -> set[tuple[str, str]]:
    by_type = attributes_by_type(attributes)
    pairs: set[tuple[str, str]] = set()
    for typ in types:
        for attr_a, attr_b in combinations(by_type.get(typ, []), 2):
            pairs.add(canonical_pair(attr_a, attr_b))
    return pairs


def all_cross_type_pairs(attributes: list[str]) -> set[tuple[str, str]]:
    pairs: set[tuple[str, str]] = set()
    for attr_a, attr_b in combinations(attributes, 2):
        if attribute_type(attr_a) != attribute_type(attr_b):
            pairs.add(canonical_pair(attr_a, attr_b))
    return pairs


def load_player_attribute_index() -> dict[str, set[str]]:
    if not PLAYER_ATTRIBUTES_PATH.is_file():
        raise FileNotFoundError(f"Missing {PLAYER_ATTRIBUTES_PATH} (run D7 first)")

    index: dict[str, set[str]] = defaultdict(set)
    with PLAYER_ATTRIBUTES_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            attribute_id = (row.get("attribute_id") or "").strip()
            if player_id and attribute_id:
                index[attribute_id].add(player_id)
    return index


def load_market_values() -> dict[str, int]:
    values: dict[str, int] = {}
    path = STAGING_NORM / "players.csv"
    if not path.is_file():
        return values
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            raw = (row.get("market_value_in_eur") or "").strip()
            try:
                values[player_id] = int(float(raw)) if raw else 0
            except ValueError:
                values[player_id] = 0
    return values


def sample_player_ids(
    players: set[str], market_values: dict[str, int], limit: int = SAMPLE_PLAYER_LIMIT
) -> str:
    ranked = sorted(players, key=lambda pid: market_values.get(pid, 0), reverse=True)
    samples = [tm_sample_id(pid) for pid in ranked[:limit]]
    return json.dumps(samples, ensure_ascii=False)


def compute_stats(
    pairs: set[tuple[str, str]], attr_index: dict[str, set[str]], market_values: dict[str, int]
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for attr_a, attr_b in sorted(pairs):
        players_a = attr_index.get(attr_a, set())
        players_b = attr_index.get(attr_b, set())
        intersection = players_a & players_b
        count = len(intersection)
        rows.append(
            {
                "attr_a": attr_a,
                "attr_b": attr_b,
                "player_count": count,
                "sample_player_ids": sample_player_ids(intersection, market_values)
                if intersection
                else "[]",
            }
        )
    return rows


def load_board_pairs_from_staging() -> set[tuple[str, str]]:
    """Return row×col pairs from boards.csv + board_slots.csv when present (D10)."""
    if not BOARDS_PATH.is_file() or not BOARD_SLOTS_PATH.is_file():
        return set()

    slots_by_board: dict[str, dict[str, list[str]]] = defaultdict(
        lambda: {"row": [], "col": []}
    )
    with BOARD_SLOTS_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            board_id = row.get("board_id") or ""
            kind = row.get("slot_kind") or ""
            attr = row.get("attribute_id") or ""
            if board_id and kind in ("row", "col") and attr:
                slots_by_board[board_id][kind].append(attr)

    pairs: set[tuple[str, str]] = set()
    for slots in slots_by_board.values():
        for row_attr in slots["row"]:
            for col_attr in slots["col"]:
                pairs.add(canonical_pair(row_attr, col_attr))
    return pairs


def validate_board_coverage(
    stats_by_pair: dict[tuple[str, str], int], board_pairs: set[tuple[str, str]]
) -> list[str]:
    errors: list[str] = []
    for pair in board_pairs:
        count = stats_by_pair.get(pair, -1)
        if count < 0:
            errors.append(f"board pair missing from stats: {pair[0]} × {pair[1]}")
        elif count < MIN_INTERSECTION_FOR_BOARDS:
            errors.append(
                f"board pair {pair[0]} × {pair[1]} has player_count={count} "
                f"(need >={MIN_INTERSECTION_FOR_BOARDS})"
            )
    return errors


def main() -> int:
    try:
        attributes = load_board_eligible_attributes()
        attr_index = load_player_attribute_index()
    except FileNotFoundError as exc:
        print(f"D9 build FAILED: {exc}", file=sys.stderr)
        return 1

    market_values = load_market_values()
    cross_type_pairs = all_cross_type_pairs(attributes)
    same_type = same_type_pairs(attributes)
    all_pairs = cross_type_pairs | same_type
    template_pairs = template_runtime_pairs(attributes)
    same_type_club_pairs = same_type_pairs(attributes, ("club",))
    same_type_league_pairs = same_type_pairs(attributes, ("league",))

    stat_rows = compute_stats(all_pairs, attr_index, market_values)
    stats_by_pair = {(r["attr_a"], r["attr_b"]): int(r["player_count"]) for r in stat_rows}

    forbidden = [
        {"attr_a": a, "attr_b": b, "player_count": 0}
        for a, b in sorted(template_pairs)
        if stats_by_pair.get((a, b), 0) == 0
    ]

    board_pairs = load_board_pairs_from_staging()
    board_errors: list[str] = []
    if board_pairs:
        board_errors = validate_board_coverage(stats_by_pair, board_pairs)

    STAGING.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)

    with STATS_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=STATS_FIELDS)
        writer.writeheader()
        writer.writerows(stat_rows)

    forbidden_report = {
        "phase": "D9",
        "forbidden_pair_count": len(forbidden),
        "note": (
            "Template pairs (club×nation, league×club, club×club, league×league) "
            "with zero players. Board generation must not use these cells."
        ),
        "pairs": forbidden,
    }
    with FORBIDDEN_PATH.open("w", encoding="utf-8") as f:
        json.dump(forbidden_report, f, indent=2)
        f.write("\n")

    ok_pairs = sum(1 for r in stat_rows if int(r["player_count"]) >= MIN_INTERSECTION_FOR_BOARDS)
    template_ok = sum(
        1 for p in template_pairs if stats_by_pair.get(p, 0) >= MIN_INTERSECTION_FOR_BOARDS
    )

    spot_salah = stats_by_pair.get(canonical_pair("nation:egypt", "club:31"), 0)
    spot_liverpool_chelsea = stats_by_pair.get(
        canonical_pair("club:31", "club:631"), 0
    )
    spot_gb1_it1 = stats_by_pair.get(canonical_pair("league:GB1", "league:IT1"), 0)

    summary = {
        "phase": "D9",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "output": str(STATS_PATH),
        "forbidden_pairs_report": str(FORBIDDEN_PATH),
        "total_pair_stats": len(stat_rows),
        "total_cross_type_pairs": len(cross_type_pairs),
        "same_type_club_pairs": len(same_type_club_pairs),
        "same_type_league_pairs": len(same_type_league_pairs),
        "template_runtime_pairs": len(template_pairs),
        "pairs_with_count_gte_3": ok_pairs,
        "template_pairs_with_count_gte_3": template_ok,
        "forbidden_template_pair_count": len(forbidden),
        "boards_staged": bool(board_pairs),
        "board_slot_pairs_checked": len(board_pairs),
        "board_coverage_errors": board_errors,
        "spot_check_salah_egypt_liverpool": spot_salah,
        "spot_check_liverpool_chelsea": spot_liverpool_chelsea,
        "spot_check_gb1_it1": spot_gb1_it1,
        "validation_passed": not board_errors,
    }

    with SUMMARY_PATH.open("w", encoding="utf-8", newline="") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if board_errors:
        print("D9 build FAILED: board coverage errors:", file=sys.stderr)
        for err in board_errors[:15]:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D9 build OK: {len(stat_rows):,} pair stats, "
        f"{template_ok}/{len(template_pairs)} template pairs with count>={MIN_INTERSECTION_FOR_BOARDS}, "
        f"{len(forbidden)} forbidden template pairs"
    )
    print(f"  stats: {STATS_PATH}")
    print(f"  forbidden: {FORBIDDEN_PATH} (count={len(forbidden)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
