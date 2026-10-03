#!/usr/bin/env python3
"""Phase D10 — generate and curate valid 3×3 Tiki-Taka boards.

Templates (v1):
  - club_nation: row = clubs, col = nations
  - league_club: row = leagues, col = clubs

Writes:
  tool/etl/staging/boards.csv
  tool/etl/staging/board_slots.csv
  tool/etl/reports/generate_boards_summary.json

Exit 1 if D9 stats missing, DoD validation fails, or targets not met.
"""
from __future__ import annotations

import csv
import json
import random
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS, load_yaml  # noqa: E402

STAGING = _ETL_DIR / "staging"
STATS_PATH = STAGING / "attribute_pair_stats.csv"
BOARDS_PATH = STAGING / "boards.csv"
BOARD_SLOTS_PATH = STAGING / "board_slots.csv"
SUMMARY_PATH = REPORTS / "generate_boards_summary.json"

BOARDS_FIELDS = ("id", "name", "min_intersection", "template", "featured")
SLOTS_FIELDS = ("board_id", "slot_kind", "slot_index", "attribute_id")


def canonical_pair(attr_a: str, attr_b: str) -> tuple[str, str]:
    return (attr_a, attr_b) if attr_a < attr_b else (attr_b, attr_a)


def attribute_type(attribute_id: str) -> str:
    return attribute_id.split(":", 1)[0] if ":" in attribute_id else ""


class PairStats:
    def __init__(self, stats_path: Path) -> None:
        self._counts: dict[tuple[str, str], int] = {}
        if not stats_path.is_file():
            raise FileNotFoundError(f"Missing {stats_path} (run D9 first)")
        with stats_path.open(encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                key = canonical_pair(row["attr_a"], row["attr_b"])
                self._counts[key] = int(row["player_count"])

    def count(self, attr_a: str, attr_b: str) -> int:
        return self._counts.get(canonical_pair(attr_a, attr_b), 0)

    def grid_counts(self, rows: list[str], cols: list[str]) -> list[int]:
        return [self.count(r, c) for r in rows for c in cols]


class AttributeCatalog:
    def __init__(self) -> None:
        self.display_to_id: dict[str, str] = {}
        self.id_to_display: dict[str, str] = {}

        clubs = load_yaml("clubs_allowlist.yaml").get("clubs") or {}
        for display, club_id in clubs.items():
            self._add(display, f"club:{club_id}")

        nations = load_yaml("nations_allowlist.yaml").get("nations") or {}
        for display, slug in nations.items():
            self._add(display, f"nation:{slug}")

        leagues = load_yaml("leagues_allowlist.yaml").get("leagues") or {}
        for display, comp_id in leagues.items():
            self._add(display, f"league:{str(comp_id).upper()}")

    def _add(self, display: str, attribute_id: str) -> None:
        self.display_to_id[display] = attribute_id
        self.id_to_display[attribute_id] = display

    def resolve_list(self, names: list[str]) -> list[str]:
        ids: list[str] = []
        for name in names:
            attr_id = self.display_to_id.get(name)
            if not attr_id:
                raise KeyError(f"Unknown attribute display name: {name!r}")
            ids.append(attr_id)
        return ids

    def ids_by_type(self, type_name: str) -> list[str]:
        return sorted(
            attr_id
            for attr_id in self.id_to_display
            if attribute_type(attr_id) == type_name
        )


def build_partner_map(
    stats: PairStats, row_type: str, col_type: str, min_count: int
) -> dict[str, set[str]]:
    """row_attr -> set of col_attr with player_count >= min_count."""
    partners: dict[str, set[str]] = defaultdict(set)
    prefix_row = f"{row_type}:"
    prefix_col = f"{col_type}:"
    for (attr_a, attr_b), count in stats._counts.items():
        if count < min_count:
            continue
        if attr_a.startswith(prefix_row) and attr_b.startswith(prefix_col):
            partners[attr_a].add(attr_b)
        elif attr_b.startswith(prefix_row) and attr_a.startswith(prefix_col):
            partners[attr_b].add(attr_a)
    return partners


def find_valid_triplet(
    items: list[str], partner_map: dict[str, set[str]], min_shared: int = 3
) -> list[str] | None:
    """Three distinct items sharing at least min_shared partners."""
    for trio in combinations(items, 3):
        shared = partner_map[trio[0]].copy()
        shared &= partner_map[trio[1]]
        shared &= partner_map[trio[2]]
        if len(shared) >= min_shared:
            return list(trio)
    return None


def pick_cols_for_rows(
    rows: list[str],
    col_candidates: list[str],
    partner_map: dict[str, set[str]],
    stats: PairStats,
    min_count: int,
    rng: random.Random,
) -> list[str] | None:
    shared = partner_map[rows[0]].copy()
    for row in rows[1:]:
        shared &= partner_map[row]
    shared &= set(col_candidates)
    if len(shared) < 3:
        return None
    cols = list(shared)
    rng.shuffle(cols)
    for trio in combinations(cols, 3):
        if min(stats.grid_counts(rows, list(trio))) >= min_count:
            return list(trio)
    return None


@dataclass
class BoardRecord:
    board_id: str
    name: str
    template: str
    featured: bool
    rows: list[str]
    cols: list[str]
    min_intersection: int


def board_key(template: str, rows: list[str], cols: list[str]) -> tuple:
    return (template, tuple(sorted(rows)), tuple(sorted(cols)))


def make_board_name(
    template: str, rows: list[str], cols: list[str], catalog: AttributeCatalog
) -> str:
    row_names = [catalog.id_to_display[r] for r in rows]
    col_names = [catalog.id_to_display[c] for c in cols]
    if template == "club_nation":
        return f"{' · '.join(row_names[:2])}… × {' · '.join(col_names[:2])}…"
    return f"{' · '.join(row_names)} × {' · '.join(col_names[:2])}…"


def validate_board(
    rows: list[str], cols: list[str], stats: PairStats, min_count: int
) -> tuple[bool, int]:
    if len(set(rows)) < 3 or len(set(cols)) < 3:
        return False, 0
    counts = stats.grid_counts(rows, cols)
    if len(counts) != 9:
        return False, 0
    weakest = min(counts)
    return weakest >= min_count, weakest


def load_featured_boards(
    catalog: AttributeCatalog,
    stats: PairStats,
    min_count: int,
    seen: set[tuple],
) -> tuple[list[BoardRecord], list[str]]:
    cfg = load_yaml("featured_boards.yaml").get("boards") or []
    boards: list[BoardRecord] = []
    skipped: list[str] = []

    for item in cfg:
        board_id = str(item.get("id", "")).strip()
        template = str(item.get("template", "")).strip()
        name = str(item.get("name", board_id)).strip()
        row_names = item.get("rows") or []
        col_names = item.get("cols") or []

        try:
            rows = catalog.resolve_list([str(x) for x in row_names])
            cols = catalog.resolve_list([str(x) for x in col_names])
        except KeyError as exc:
            skipped.append(f"{board_id}: {exc}")
            continue

        key = board_key(template, rows, cols)
        if key in seen:
            skipped.append(f"{board_id}: duplicate layout")
            continue

        ok, weakest = validate_board(rows, cols, stats, min_count)
        if not ok:
            skipped.append(
                f"{board_id}: min intersection {weakest} < {min_count} (skipped)"
            )
            continue

        seen.add(key)
        boards.append(
            BoardRecord(
                board_id=board_id,
                name=name,
                template=template,
                featured=True,
                rows=rows,
                cols=cols,
                min_intersection=weakest,
            )
        )

    return boards, skipped


def discover_featured_boards(
    stats: PairStats,
    catalog: AttributeCatalog,
    config: dict,
    seen: set[tuple],
    needed: int,
    rng: random.Random,
) -> list[BoardRecord]:
    """Top up featured pool with highest min_intersection auto boards."""
    if needed <= 0:
        return []

    batch_target = max(needed * 30, 500)

    extra_seen = set(seen)
    auto = auto_generate_boards(
        stats,
        catalog,
        {**config, "min_auto_boards": batch_target},
        extra_seen,
        rng,
    )
    auto.sort(key=lambda b: b.min_intersection, reverse=True)

    featured: list[BoardRecord] = []
    for board in auto:
        key = board_key(board.template, board.rows, board.cols)
        if key in seen:
            continue
        seen.add(key)
        featured.append(
            BoardRecord(
                board_id=f"featured-auto-{len(featured) + 1:03d}",
                name=board.name,
                template=board.template,
                featured=True,
                rows=board.rows,
                cols=board.cols,
                min_intersection=board.min_intersection,
            )
        )
        if len(featured) >= needed:
            break
    return featured


def auto_generate_boards(
    stats: PairStats,
    catalog: AttributeCatalog,
    config: dict,
    seen: set[tuple],
    rng: random.Random,
) -> list[BoardRecord]:
    min_count = int(config.get("min_intersection", 3))
    target = int(config.get("min_auto_boards", 100))
    max_attempts = int(config.get("max_generation_attempts", 250000))
    templates = config.get("templates") or ["club_nation", "league_club"]

    auto_boards: list[BoardRecord] = []
    attempts = 0
    auto_index = 1

    template_specs = {
        "club_nation": ("club", "nation"),
        "league_club": ("league", "club"),
    }

    while len(auto_boards) < target and attempts < max_attempts:
        attempts += 1
        template = rng.choice(templates)
        row_type, col_type = template_specs[template]

        row_items = catalog.ids_by_type(row_type)
        col_items = catalog.ids_by_type(col_type)
        partner_map = build_partner_map(stats, row_type, col_type, min_count)

        viable_rows = [r for r in row_items if len(partner_map.get(r, set())) >= 3]
        if len(viable_rows) < 3:
            continue

        rng.shuffle(viable_rows)
        rows = find_valid_triplet(viable_rows, partner_map, min_shared=3)
        if not rows:
            continue

        cols = pick_cols_for_rows(rows, col_items, partner_map, stats, min_count, rng)
        if not cols:
            continue

        key = board_key(template, rows, cols)
        if key in seen:
            continue

        ok, weakest = validate_board(rows, cols, stats, min_count)
        if not ok:
            continue

        seen.add(key)
        board_id = f"auto-{template[:2]}-{auto_index:04d}"
        auto_index += 1
        auto_boards.append(
            BoardRecord(
                board_id=board_id,
                name=make_board_name(template, rows, cols, catalog),
                template=template,
                featured=False,
                rows=rows,
                cols=cols,
                min_intersection=weakest,
            )
        )

    return auto_boards


def write_outputs(boards: list[BoardRecord]) -> None:
    STAGING.mkdir(parents=True, exist_ok=True)
    with BOARDS_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=BOARDS_FIELDS)
        writer.writeheader()
        for board in boards:
            writer.writerow(
                {
                    "id": board.board_id,
                    "name": board.name,
                    "min_intersection": board.min_intersection,
                    "template": board.template,
                    "featured": "1" if board.featured else "0",
                }
            )

    with BOARD_SLOTS_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=SLOTS_FIELDS)
        writer.writeheader()
        for board in boards:
            for index, attr_id in enumerate(board.rows):
                writer.writerow(
                    {
                        "board_id": board.board_id,
                        "slot_kind": "row",
                        "slot_index": index,
                        "attribute_id": attr_id,
                    }
                )
            for index, attr_id in enumerate(board.cols):
                writer.writerow(
                    {
                        "board_id": board.board_id,
                        "slot_kind": "col",
                        "slot_index": index,
                        "attribute_id": attr_id,
                    }
                )


def validate_all_boards(
    boards: list[BoardRecord], stats: PairStats, min_count: int
) -> list[str]:
    errors: list[str] = []
    for board in boards:
        counts = stats.grid_counts(board.rows, board.cols)
        weakest = min(counts) if counts else 0
        if weakest < min_count:
            errors.append(
                f"{board.board_id}: cell player_count {weakest} < {min_count}"
            )
        if board.min_intersection != weakest:
            errors.append(
                f"{board.board_id}: min_intersection mismatch "
                f"({board.min_intersection} vs {weakest})"
            )
    return errors


def main() -> int:
    config = load_yaml("board_generation.yaml")
    min_count = int(config.get("min_intersection", 3))
    min_featured = int(config.get("min_featured_boards", 20))
    min_total = min_featured + int(config.get("min_auto_boards", 100))

    stats = PairStats(STATS_PATH)
    catalog = AttributeCatalog()
    rng = random.Random(42)

    seen: set[tuple] = set()
    featured_boards, featured_skipped = load_featured_boards(
        catalog, stats, min_count, seen
    )

    if len(featured_boards) < min_featured:
        need = min_featured - len(featured_boards)
        featured_boards.extend(
            discover_featured_boards(stats, catalog, config, seen, need, rng)
        )

    auto_boards = auto_generate_boards(stats, catalog, config, seen, rng)
    all_boards = featured_boards + auto_boards

    validation_errors = validate_all_boards(all_boards, stats, min_count)
    if validation_errors:
        print("D10 generate FAILED: board validation errors:", file=sys.stderr)
        for err in validation_errors[:20]:
            print(f"  - {err}", file=sys.stderr)
        return 1

    if len(featured_boards) < min_featured:
        print(
            f"D10 generate FAILED: only {len(featured_boards)} featured boards "
            f"(need {min_featured})",
            file=sys.stderr,
        )
        return 1

    if len(all_boards) < 20:
        print(
            f"D10 generate FAILED: only {len(all_boards)} total boards (need >= 20)",
            file=sys.stderr,
        )
        return 1

    write_outputs(all_boards)

    summary = {
        "phase": "D10",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "min_intersection": min_count,
        "total_boards": len(all_boards),
        "featured_boards": len(featured_boards),
        "auto_boards": len(auto_boards),
        "featured_yaml_skipped": featured_skipped,
        "boards_output": str(BOARDS_PATH),
        "board_slots_output": str(BOARD_SLOTS_PATH),
        "weakest_cell_global": min(
            min(stats.grid_counts(b.rows, b.cols)) for b in all_boards
        ),
        "validation_passed": True,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    print(
        f"D10 generate OK: {len(all_boards)} boards "
        f"({len(featured_boards)} featured + {len(auto_boards)} auto), "
        f"min_intersection>={min_count}"
    )
    print(f"  boards: {BOARDS_PATH}")
    print(f"  slots: {BOARD_SLOTS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
