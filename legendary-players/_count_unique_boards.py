#!/usr/bin/env python3
"""Count unique valid Tiki-Taka boards from attribute_pair_stats."""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from itertools import combinations, permutations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool" / "etl"))
from etl_common import load_yaml  # noqa: E402

STATS_PATH = ROOT / "tool" / "etl" / "staging" / "attribute_pair_stats.csv"
OUTPUT_PATH = Path(__file__).with_name("_unique_board_counts.json")

ORDER_FACTOR = 6 * 6  # 3! row permutations × 3! col permutations


def canonical_pair(a: str, b: str) -> tuple[str, str]:
    return (a, b) if a < b else (b, a)


def attr_type(attribute_id: str) -> str:
    prefix = attribute_id.split(":", 1)[0]
    return "position" if prefix == "pos" else prefix


class PairStats:
    def __init__(self, path: Path) -> None:
        self._counts: dict[tuple[str, str], int] = {}
        with path.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                self._counts[canonical_pair(row["attr_a"], row["attr_b"])] = int(
                    row["player_count"]
                )

    def ok(self, attr_a: str, attr_b: str, min_count: int) -> bool:
        if attr_a == attr_b:
            return False
        return self._counts.get(canonical_pair(attr_a, attr_b), 0) >= min_count

    def grid_ok(
        self, rows: tuple[str, ...], cols: tuple[str, ...], min_count: int
    ) -> bool:
        for row in rows:
            for col in cols:
                if not self.ok(row, col, min_count):
                    return False
        return True


def load_attributes() -> dict[str, list[str]]:
    attrs: dict[str, list[str]] = defaultdict(list)
    for club_id in (load_yaml("clubs_allowlist.yaml").get("clubs") or {}).values():
        attrs["club"].append(f"club:{club_id}")
    for slug in (load_yaml("nations_allowlist.yaml").get("nations") or {}).values():
        attrs["nation"].append(f"nation:{slug}")
    for comp_id in (load_yaml("leagues_allowlist.yaml").get("leagues") or {}).values():
        attrs["league"].append(f"league:{str(comp_id).upper()}")
    for bucket in ("GK", "DEF", "MID", "FWD"):
        attrs["position"].append(f"pos:{bucket}")
    for values in attrs.values():
        values.sort()
    return attrs


def type_prefix(type_name: str) -> str:
    return "pos:" if type_name == "position" else f"{type_name}:"


def build_partner_map(
    stats: PairStats,
    type_a: str,
    type_b: str,
    min_count: int,
) -> dict[str, set[str]]:
    partners: dict[str, set[str]] = defaultdict(set)
    prefix_a = type_prefix(type_a)
    prefix_b = type_prefix(type_b)
    for (attr_a, attr_b), count in stats._counts.items():
        if count < min_count:
            continue
        if attr_a.startswith(prefix_a) and attr_b.startswith(prefix_b):
            partners[attr_a].add(attr_b)
        elif attr_b.startswith(prefix_a) and attr_a.startswith(prefix_b):
            partners[attr_b].add(attr_a)
    return partners


def intersect_partner_sets(
    partner_map: dict[str, set[str]], items: tuple[str, ...]
) -> set[str]:
    result = partner_map[items[0]].copy()
    for item in items[1:]:
        result &= partner_map[item]
    return result


def add_board(
    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]],
    rows: tuple[str, ...],
    cols: tuple[str, ...],
) -> int:
    key = (tuple(sorted(rows)), tuple(sorted(cols)))
    if key in canonical:
        return 0
    canonical.add(key)
    return ORDER_FACTOR


def count_cross_type(
    stats: PairStats,
    attrs: dict[str, list[str]],
    row_type: str,
    col_type: str,
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_map = build_partner_map(stats, row_type, col_type, min_count)
    row_items = [item for item in attrs[row_type] if len(partner_map.get(item, ())) >= 3]
    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for rows in combinations(row_items, 3):
        shared = intersect_partner_sets(partner_map, rows)
        if len(shared) < 3:
            continue
        for cols in combinations(tuple(sorted(shared)), 3):
            if not stats.grid_ok(rows, cols, min_count):
                continue
            ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_clubs_x_clubs(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    return count_cross_type(stats, attrs, "club", "club", min_count)


def count_clubs_x_mixed_col(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_nation = build_partner_map(stats, "club", "nation", min_count)
    partner_league = build_partner_map(stats, "club", "league", min_count)
    partner_position = build_partner_map(stats, "club", "position", min_count)

    club_items = [
        item
        for item in attrs["club"]
        if len(partner_nation.get(item, ())) > 0
        and len(partner_league.get(item, ())) > 0
        and len(partner_position.get(item, ())) > 0
    ]

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for rows in combinations(club_items, 3):
        nations = intersect_partner_sets(partner_nation, rows)
        leagues = intersect_partner_sets(partner_league, rows)
        positions = intersect_partner_sets(partner_position, rows)
        if not nations or not leagues or not positions:
            continue
        for nation in nations:
            for league in leagues:
                for position in positions:
                    cols = (nation, league, position)
                    if not stats.grid_ok(rows, cols, min_count):
                        continue
                    ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_mixed_row_x_clubs(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_nation = build_partner_map(stats, "nation", "club", min_count)
    partner_league = build_partner_map(stats, "league", "club", min_count)
    partner_position = build_partner_map(stats, "position", "club", min_count)

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for nation in attrs["nation"]:
        for league in attrs["league"]:
            for position in attrs["position"]:
                rows = (nation, league, position)
                shared = (
                    partner_nation[nation]
                    & partner_league[league]
                    & partner_position[position]
                )
                if len(shared) < 3:
                    continue
                for cols in combinations(tuple(sorted(shared)), 3):
                    if not stats.grid_ok(rows, cols, min_count):
                        continue
                    ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_mixed_both_axes(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_club = build_partner_map(stats, "club", "club", min_count)
    partner_club_league = build_partner_map(stats, "club", "league", min_count)
    partner_league_league = build_partner_map(stats, "league", "league", min_count)

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for row_league in attrs["league"]:
        for row_clubs in combinations(attrs["club"], 2):
            col_club_pool = intersect_partner_sets(partner_club, row_clubs) - set(row_clubs)
            if len(col_club_pool) < 2:
                continue
            for col_clubs in combinations(tuple(sorted(col_club_pool)), 2):
                for col_league in attrs["league"]:
                    if col_league == row_league:
                        continue
                    rows = (*row_clubs, row_league)
                    cols = (*col_clubs, col_league)
                    if not stats.grid_ok(rows, cols, min_count):
                        continue
                    ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_two_clubs_nation_x_three_clubs(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_club = build_partner_map(stats, "club", "club", min_count)
    partner_nation_club = build_partner_map(stats, "nation", "club", min_count)

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for nation in attrs["nation"]:
        nation_clubs = partner_nation_club.get(nation, set())
        if len(nation_clubs) < 5:
            continue
        for row_clubs in combinations(attrs["club"], 2):
            if not all(stats.ok(club, nation, min_count) for club in row_clubs):
                continue
            col_pool = intersect_partner_sets(partner_club, row_clubs) - set(row_clubs)
            col_pool &= nation_clubs
            if len(col_pool) < 3:
                continue
            rows = (*row_clubs, nation)
            for cols in combinations(tuple(sorted(col_pool)), 3):
                if not stats.grid_ok(rows, cols, min_count):
                    continue
                ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_three_clubs_x_two_clubs_nation(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_club = build_partner_map(stats, "club", "club", min_count)
    partner_nation_club = build_partner_map(stats, "nation", "club", min_count)
    partner_club_nation = build_partner_map(stats, "club", "nation", min_count)

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for rows in combinations(attrs["club"], 3):
        nation_pool = intersect_partner_sets(partner_club_nation, rows)
        if not nation_pool:
            continue
        for nation in nation_pool:
            col_club_pool = intersect_partner_sets(partner_club, rows) - set(rows)
            col_club_pool &= partner_nation_club.get(nation, set())
            if len(col_club_pool) < 2:
                continue
            for col_clubs in combinations(tuple(sorted(col_club_pool)), 2):
                cols = (*col_clubs, nation)
                if not stats.grid_ok(rows, cols, min_count):
                    continue
                ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


def count_three_clubs_x_two_clubs_league(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> tuple[int, int, set[tuple[tuple[str, ...], tuple[str, ...]]]]:
    partner_club = build_partner_map(stats, "club", "club", min_count)
    partner_league_club = build_partner_map(stats, "league", "club", min_count)
    partner_club_league = build_partner_map(stats, "club", "league", min_count)

    canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()
    ordered = 0

    for rows in combinations(attrs["club"], 3):
        league_pool = intersect_partner_sets(partner_club_league, rows)
        if not league_pool:
            continue
        for league in league_pool:
            col_club_pool = intersect_partner_sets(partner_club, rows) - set(rows)
            col_club_pool &= partner_league_club.get(league, set())
            if len(col_club_pool) < 2:
                continue
            for col_clubs in combinations(tuple(sorted(col_club_pool)), 2):
                cols = (*col_clubs, league)
                if not stats.grid_ok(rows, cols, min_count):
                    continue
                ordered += add_board(canonical, rows, cols)

    return len(canonical), ordered, canonical


RUNTIME_COUNTERS = {
    "rt-1-club-club": count_clubs_x_clubs,
    "rt-2-club-mixed-col": count_clubs_x_mixed_col,
    "rt-3-mixed-row-club": count_mixed_row_x_clubs,
    "rt-4-mixed-both": count_mixed_both_axes,
    "rt-5-club-nation-club": count_two_clubs_nation_x_three_clubs,
    "rt-6-club-club-nation": count_three_clubs_x_two_clubs_nation,
    "rt-7-club-club-league": count_three_clubs_x_two_clubs_league,
}

ETL_TEMPLATES = [
    ("club_nation", "club", "nation"),
    ("league_club", "league", "club"),
]


def count_for_threshold(
    stats: PairStats,
    attrs: dict[str, list[str]],
    min_count: int,
) -> dict[str, object]:
    etl_breakdown: dict[str, dict[str, int]] = {}
    runtime_breakdown: dict[str, dict[str, int]] = {}
    union_canonical: set[tuple[tuple[str, ...], tuple[str, ...]]] = set()

    etl_canonical = 0
    etl_ordered = 0
    for template_id, row_type, col_type in ETL_TEMPLATES:
        canonical_count, ordered_count, keys = count_cross_type(
            stats, attrs, row_type, col_type, min_count
        )
        etl_breakdown[template_id] = {
            "canonical_boards": canonical_count,
            "ordered_boards": ordered_count,
        }
        etl_canonical += canonical_count
        etl_ordered += ordered_count
        union_canonical |= keys
        print(f"  etl {template_id}: {canonical_count:,}")

    runtime_canonical = 0
    runtime_ordered = 0
    for template_id, counter in RUNTIME_COUNTERS.items():
        canonical_count, ordered_count, keys = counter(stats, attrs, min_count)
        runtime_breakdown[template_id] = {
            "canonical_boards": canonical_count,
            "ordered_boards": ordered_count,
        }
        runtime_canonical += canonical_count
        runtime_ordered += ordered_count
        union_canonical |= keys
        print(f"  runtime {template_id}: {canonical_count:,}")

    return {
        "etl_templates": etl_breakdown,
        "etl_total_canonical": etl_canonical,
        "etl_total_ordered": etl_ordered,
        "runtime_templates": runtime_breakdown,
        "runtime_total_canonical": runtime_canonical,
        "runtime_total_ordered": runtime_ordered,
        "union_unique_canonical_boards": len(union_canonical),
        "note": (
            "Canonical board = unique set of 6 header attribute IDs (3 rows + 3 cols), "
            "ignoring slot order. Ordered board = canonical × 36 (3! row orders × 3! col orders). "
            "Union deduplicates layouts that qualify under multiple template buckets."
        ),
    }


def main() -> None:
    attrs = load_attributes()
    stats = PairStats(STATS_PATH)

    results: dict[str, object] = {
        "database": str(STATS_PATH),
        "attribute_counts": {key: len(values) for key, values in attrs.items()},
        "thresholds": {},
    }

    for min_count, label in ((3, "medium"), (5, "easy"), (1, "hard")):
        print(f"Counting min_intersection={min_count} ({label})...")
        results["thresholds"][f"min_intersection_{min_count}"] = count_for_threshold(
            stats, attrs, min_count
        )

    OUTPUT_PATH.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    primary = results["thresholds"]["min_intersection_3"]
    print("\n=== min_intersection=3 summary ===")
    print(f"ETL canonical total:      {primary['etl_total_canonical']:,}")
    print(f"Runtime canonical total:  {primary['runtime_total_canonical']:,}")
    print(f"Union unique canonical:   {primary['union_unique_canonical_boards']:,}")
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
