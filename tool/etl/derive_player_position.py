#!/usr/bin/env python3
"""Phase D6 — derive player_position bucket edges from player profile.

Maps position + sub_position via position_map.yaml (sub_position preferred).
Writes:

  tool/etl/staging/player_position.csv
  tool/etl/staging/attributes_position.csv
  tool/etl/reports/derive_player_position_summary.json
  tool/etl/reports/unmapped_positions.csv

Exit 1 if inputs missing or DoD checks fail.
"""
from __future__ import annotations

import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import PositionMapper, REPORTS, STAGING_NORM, load_yaml  # noqa: E402

STAGING = _ETL_DIR / "staging"
PLAYER_POSITION_PATH = STAGING / "player_position.csv"
ATTRIBUTES_POSITION_PATH = STAGING / "attributes_position.csv"
SUMMARY_PATH = REPORTS / "derive_player_position_summary.json"
UNMAPPED_PATH = REPORTS / "unmapped_positions.csv"

POSITION_BUCKETS = (
    ("GK", "Goalkeeper", "pos:GK"),
    ("DEF", "Defender", "pos:DEF"),
    ("MID", "Midfielder", "pos:MID"),
    ("FWD", "Forward", "pos:FWD"),
)

PLAYER_POSITION_FIELDS = ("player_id", "position_bucket", "attribute_id", "source")
ATTRIBUTE_FIELDS = ("id", "type", "display_name", "slug", "source_id", "icon_key")


def build_mapper() -> PositionMapper:
    cfg = load_yaml("position_map.yaml")
    return PositionMapper(
        cfg.get("coarse_position") or {},
        cfg.get("sub_position") or {},
    )


def collect_edges(
    mapper: PositionMapper,
) -> tuple[list[dict[str, str]], list[dict[str, str]], int]:
    """Return (edge rows, per-player TM fields for DoD checks, omitted Missing count)."""
    edges: list[dict[str, str]] = []
    player_meta: list[dict[str, str]] = []
    omitted_missing = 0

    with (STAGING_NORM / "players.csv").open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            if not player_id:
                continue

            position = row.get("position") or ""
            sub_position = row.get("sub_position") or ""
            bucket = mapper.resolve(position, sub_position)

            if bucket is None:
                if (position or "").strip() == "Missing" or (
                    not (sub_position or "").strip() and not (position or "").strip()
                ):
                    omitted_missing += 1
                continue

            edges.append(
                {
                    "player_id": player_id,
                    "position_bucket": bucket,
                    "attribute_id": f"pos:{bucket}",
                    "source": "profile",
                }
            )
            player_meta.append(
                {
                    "player_id": player_id,
                    "position": position,
                    "sub_position": sub_position,
                    "bucket": bucket,
                }
            )

    return edges, player_meta, omitted_missing


def write_player_position(edges: list[dict[str, str]]) -> int:
    STAGING.mkdir(parents=True, exist_ok=True)
    sorted_edges = sorted(edges, key=lambda r: r["player_id"])
    with PLAYER_POSITION_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=PLAYER_POSITION_FIELDS)
        writer.writeheader()
        writer.writerows(sorted_edges)
    return len(sorted_edges)


def write_attributes_position() -> int:
    rows = [
        {
            "id": attr_id,
            "type": "position",
            "display_name": display,
            "slug": bucket.lower(),
            "source_id": "",
            "icon_key": f"pos_{bucket.lower()}",
        }
        for bucket, display, attr_id in POSITION_BUCKETS
    ]
    with ATTRIBUTES_POSITION_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=ATTRIBUTE_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def write_unmapped_positions(mapper: PositionMapper) -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    with UNMAPPED_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["position_token", "player_count"])
        for token, count in mapper.unmapped.most_common():
            writer.writerow([token, count])
    return len(mapper.unmapped)


def run_spot_checks(
    edges: list[dict[str, str]], player_meta: list[dict[str, str]]
) -> tuple[list[str], dict]:
    errors: list[str] = []
    edge_by_player = {e["player_id"]: e for e in edges}

    goalkeepers_tagged_fwd: list[str] = []
    for meta in player_meta:
        pid = meta["player_id"]
        tm_gk = meta["position"] == "Goalkeeper" or meta["sub_position"] == "Goalkeeper"
        edge = edge_by_player.get(pid)
        if tm_gk and edge and edge["position_bucket"] == "FWD":
            goalkeepers_tagged_fwd.append(pid)
        if tm_gk and edge and edge["position_bucket"] != "GK":
            errors.append(
                f"goalkeeper {pid} tagged pos:{edge['position_bucket']} (expected GK)"
            )

    if goalkeepers_tagged_fwd:
        errors.append(
            f"{len(goalkeepers_tagged_fwd)} goalkeeper(s) tagged pos:FWD: "
            f"{goalkeepers_tagged_fwd[:5]}"
        )

    gk_count = sum(1 for e in edges if e["position_bucket"] == "GK")
    fwd_count = sum(1 for e in edges if e["position_bucket"] == "FWD")

    details = {
        "goalkeepers_tagged_fwd_count": len(goalkeepers_tagged_fwd),
        "edges_by_bucket": {
            bucket: sum(1 for e in edges if e["position_bucket"] == bucket)
            for bucket in ("GK", "DEF", "MID", "FWD")
        },
        "goalkeeper_edges": gk_count,
        "forward_edges": fwd_count,
    }
    return errors, details


def main() -> int:
    players_path = STAGING_NORM / "players.csv"
    if not players_path.is_file():
        print(
            f"D6 derive FAILED: missing {players_path} (run D2 normalize first)",
            file=sys.stderr,
        )
        return 1

    mapper = build_mapper()
    edges, player_meta, omitted_missing = collect_edges(mapper)
    row_count = write_player_position(edges)
    attribute_rows = write_attributes_position()
    unmapped_distinct = write_unmapped_positions(mapper)

    spot_errors, spot_details = run_spot_checks(edges, player_meta)

    summary = {
        "phase": "D6",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "player_position_output": str(PLAYER_POSITION_PATH),
        "attributes_position_output": str(ATTRIBUTES_POSITION_PATH),
        "player_position_edges": row_count,
        "attributes_position_rows": attribute_rows,
        "players_omitted_missing_position": omitted_missing,
        "unmapped_position_strings_distinct": unmapped_distinct,
        "unmapped_position_strings_total": sum(mapper.unmapped.values()),
        "unmapped_positions_report": str(UNMAPPED_PATH),
        "spot_checks": spot_details,
        "spot_check_passed": not spot_errors,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if spot_errors:
        print("D6 derive FAILED:", file=sys.stderr)
        for err in spot_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D6 derive OK: {row_count:,} player_position edges, "
        f"{unmapped_distinct} unmapped position strings, "
        f"{omitted_missing} omitted (Missing)"
    )
    print(f"  output: {PLAYER_POSITION_PATH}")
    print(f"  report: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
