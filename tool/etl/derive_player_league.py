#!/usr/bin/env python3
"""Phase D4 — derive player_league edges (Path A + Path B).

Path A (league_appearance): appearances.csv × top-5 competition_id
Path B (league_club): player_club.csv × clubs.domestic_competition_id (allowlisted, top-5)

Writes:
  tool/etl/staging/player_league.csv
  tool/etl/reports/derive_player_league_summary.json

Exit 1 if inputs missing or DoD spot-checks fail.
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

from etl_common import REPORTS, STAGING_NORM, load_yaml  # noqa: E402

STAGING = _ETL_DIR / "staging"
OUTPUT_PATH = STAGING / "player_league.csv"
SUMMARY_PATH = REPORTS / "derive_player_league_summary.json"
PLAYER_CLUB_PATH = STAGING / "player_club.csv"

# Player with only non-top-5 appearances (CLQ/ELQ/NL1) — Segunda-equivalent negative case
NON_TOP5_ONLY_PLAYER_ID = "38004"
# Liverpool squad via player_club without GB1 appearance in normalized data
PATH_B_SPOT_PLAYER_ID = "243591"
LIVERPOOL_CLUB_ID = "31"
LA_LIGA_ID = "ES1"
PREMIER_LEAGUE_ID = "GB1"

FIELDNAMES = ("player_id", "competition_id", "attribute_id", "source")


def load_top5_competition_ids() -> set[str]:
    cfg = load_yaml("leagues_allowlist.yaml")
    return {str(comp_id).upper() for comp_id in (cfg.get("leagues") or {}).values()}


def load_club_domestic_competition() -> dict[str, str]:
    """club_id → uppercased domestic_competition_id (allowlisted clubs only)."""
    mapping: dict[str, str] = {}
    with (STAGING_NORM / "clubs.csv").open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            club_id = (row.get("club_id") or "").strip()
            domestic = (row.get("domestic_competition_id") or "").strip().upper()
            if club_id and domestic:
                mapping[club_id] = domestic
    return mapping


def collect_path_a(top5: set[str]) -> set[tuple[str, str, str]]:
    edges: set[tuple[str, str, str]] = set()
    with (STAGING_NORM / "appearances.csv").open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            comp_id = (row.get("competition_id") or "").strip().upper()
            if not player_id or comp_id not in top5:
                continue
            edges.add((player_id, comp_id, "league_appearance"))
    return edges


def collect_path_b(top5: set[str], club_domestic: dict[str, str]) -> set[tuple[str, str, str]]:
    edges: set[tuple[str, str, str]] = set()
    with PLAYER_CLUB_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            club_id = (row.get("club_id") or "").strip()
            if not player_id or not club_id:
                continue
            domestic = club_domestic.get(club_id, "")
            if domestic not in top5:
                continue
            edges.add((player_id, domestic, "league_club"))
    return edges


def write_player_league(edges: set[tuple[str, str, str]]) -> int:
    STAGING.mkdir(parents=True, exist_ok=True)
    sorted_edges = sorted(edges, key=lambda t: (t[0], t[1], t[2]))
    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for player_id, comp_id, source in sorted_edges:
            writer.writerow(
                {
                    "player_id": player_id,
                    "competition_id": comp_id,
                    "attribute_id": f"league:{comp_id}",
                    "source": source,
                }
            )
    return len(sorted_edges)


def leagues_for_player(
    edges: set[tuple[str, str, str]], player_id: str
) -> dict[str, set[str]]:
    by_league: dict[str, set[str]] = defaultdict(set)
    for pid, comp_id, source in edges:
        if pid == player_id:
            by_league[comp_id].add(source)
    return dict(by_league)


def run_spot_checks(
    edges: set[tuple[str, str, str]], top5: set[str]
) -> tuple[list[str], dict]:
    errors: list[str] = []
    details: dict = {}

    non_top5 = leagues_for_player(edges, NON_TOP5_ONLY_PLAYER_ID)
    details["non_top5_only_player"] = {
        "player_id": NON_TOP5_ONLY_PLAYER_ID,
        "note": "Appearances only in CLQ/ELQ/NL1/NLP — Segunda-equivalent (no ES1 path A)",
        "leagues": {k: sorted(v) for k, v in non_top5.items()},
    }
    if LA_LIGA_ID in non_top5:
        errors.append(
            f"player {NON_TOP5_ONLY_PLAYER_ID} must not have {LA_LIGA_ID} without path A/B"
        )
    if non_top5.keys() & top5:
        errors.append(
            f"player {NON_TOP5_ONLY_PLAYER_ID} unexpectedly has top-5 leagues: "
            f"{sorted(non_top5.keys() & top5)}"
        )

    path_b_player = leagues_for_player(edges, PATH_B_SPOT_PLAYER_ID)
    details["path_b_pl_squad"] = {
        "player_id": PATH_B_SPOT_PLAYER_ID,
        "club_id": LIVERPOOL_CLUB_ID,
        "leagues": {k: sorted(v) for k, v in path_b_player.items()},
    }
    gb1_sources = path_b_player.get(PREMIER_LEAGUE_ID, set())
    if PREMIER_LEAGUE_ID not in path_b_player:
        errors.append(
            f"player {PATH_B_SPOT_PLAYER_ID} missing {PREMIER_LEAGUE_ID} via league_club (Path B)"
        )
    elif "league_club" not in gb1_sources:
        errors.append(
            f"player {PATH_B_SPOT_PLAYER_ID} must have {PREMIER_LEAGUE_ID} with source league_club"
        )

    return errors, details


def require_inputs() -> list[str]:
    missing = []
    for path in (
        STAGING_NORM / "appearances.csv",
        STAGING_NORM / "clubs.csv",
        PLAYER_CLUB_PATH,
    ):
        if not path.is_file():
            missing.append(path.name)
    return missing


def main() -> int:
    missing = require_inputs()
    if missing:
        print("D4 derive FAILED: missing inputs (run D2/D3 first):", file=sys.stderr)
        for name in missing:
            print(f"  - {name}", file=sys.stderr)
        return 1

    top5 = load_top5_competition_ids()
    club_domestic = load_club_domestic_competition()

    path_a = collect_path_a(top5)
    path_b = collect_path_b(top5, club_domestic)
    all_edges = path_a | path_b

    row_count = write_player_league(all_edges)
    spot_errors, spot_details = run_spot_checks(all_edges, top5)

    by_source: dict[str, int] = defaultdict(int)
    for _pid, _comp, source in all_edges:
        by_source[source] += 1

    distinct_pairs = len({(pid, comp) for pid, comp, _ in all_edges})

    summary = {
        "phase": "D4",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "output": str(OUTPUT_PATH),
        "top5_competition_ids": sorted(top5),
        "edge_rows": row_count,
        "distinct_player_league_pairs": distinct_pairs,
        "edges_by_source": dict(by_source),
        "path_a_edges": len(path_a),
        "path_b_edges": len(path_b),
        "spot_checks": spot_details,
        "spot_check_passed": not spot_errors,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if spot_errors:
        print("D4 derive FAILED:", file=sys.stderr)
        for err in spot_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D4 derive OK: {row_count:,} edges ({distinct_pairs:,} distinct player-league), "
        f"league_appearance={by_source['league_appearance']:,}, "
        f"league_club={by_source['league_club']:,}"
    )
    print(f"  output: {OUTPUT_PATH}")
    print(f"  report: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
