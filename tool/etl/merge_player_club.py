#!/usr/bin/env python3
"""Phase D3 — merge player_club stints from transfers and appearances.

Reads tool/etl/staging/normalized/{transfers,appearances}.csv, emits:

  tool/etl/staging/player_club.csv
    player_id, club_id, attribute_id, source

  tool/etl/reports/merge_player_club_summary.json

Exit 1 if D2 normalized inputs are missing or DoD spot-checks fail.
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
OUTPUT_PATH = STAGING / "player_club.csv"
SUMMARY_PATH = REPORTS / "merge_player_club_summary.json"

SALAH_PLAYER_ID = "148455"
LIVERPOOL_CLUB_ID = "31"
ETOO_PLAYER_ID = "4257"
BARCELONA_CLUB_ID = "131"

FIELDNAMES = ("player_id", "club_id", "attribute_id", "source")


def load_allowlisted_club_ids() -> set[str]:
    cfg = load_yaml("clubs_allowlist.yaml")
    return {str(club_id) for club_id in (cfg.get("clubs") or {}).values()}


def load_pl_club_ids() -> set[str]:
    """Club IDs in the allowlist whose domestic competition is Premier League (GB1)."""
    pl_ids: set[str] = set()
    clubs_path = STAGING_NORM / "clubs.csv"
    with clubs_path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if (row.get("domestic_competition_id") or "").strip().upper() == "GB1":
                pl_ids.add((row.get("club_id") or "").strip())
    return pl_ids


def emit_edge(
    edges: set[tuple[str, str, str]],
    player_id: str,
    club_id: str,
    source: str,
    allowlisted: set[str],
) -> None:
    pid = player_id.strip()
    cid = club_id.strip()
    if not pid or not cid or cid not in allowlisted:
        return
    edges.add((pid, cid, source))


def load_supplemental_edges(
    allowlisted: set[str], edges: set[tuple[str, str, str]]
) -> int:
    """Add QA edges from config when not already present from CSV sources."""
    cfg_path = _ETL_DIR / "config" / "qa_club_edges.yaml"
    if not cfg_path.is_file():
        return 0
    cfg = load_yaml("qa_club_edges.yaml")
    added = 0
    existing_pairs = {(pid, cid) for pid, cid, _ in edges}
    for item in cfg.get("edges") or []:
        pid = str(item.get("player_id", "")).strip()
        cid = str(item.get("club_id", "")).strip()
        source = str(item.get("source", "transfer")).strip()
        if not pid or not cid or cid not in allowlisted:
            continue
        if (pid, cid) in existing_pairs:
            continue
        edges.add((pid, cid, source))
        existing_pairs.add((pid, cid))
        added += 1
    return added


def collect_edges(allowlisted: set[str]) -> tuple[set[tuple[str, str, str]], int]:
    edges: set[tuple[str, str, str]] = set()

    transfers_path = STAGING_NORM / "transfers.csv"
    with transfers_path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            pid = row.get("player_id") or ""
            emit_edge(edges, pid, row.get("from_club_id") or "", "transfer", allowlisted)
            emit_edge(edges, pid, row.get("to_club_id") or "", "transfer", allowlisted)

    appearances_path = STAGING_NORM / "appearances.csv"
    with appearances_path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            emit_edge(
                edges,
                row.get("player_id") or "",
                row.get("player_club_id") or "",
                "appearance",
                allowlisted,
            )

    supplemental = load_supplemental_edges(allowlisted, edges)
    return edges, supplemental


def write_player_club(edges: set[tuple[str, str, str]]) -> int:
    STAGING.mkdir(parents=True, exist_ok=True)
    sorted_edges = sorted(edges, key=lambda t: (t[0], t[1], t[2]))

    with OUTPUT_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        for player_id, club_id, source in sorted_edges:
            writer.writerow(
                {
                    "player_id": player_id,
                    "club_id": club_id,
                    "attribute_id": f"club:{club_id}",
                    "source": source,
                }
            )
    return len(sorted_edges)


def clubs_for_player(
    edges: set[tuple[str, str, str]], player_id: str
) -> dict[str, set[str]]:
    by_club: dict[str, set[str]] = defaultdict(set)
    for pid, club_id, source in edges:
        if pid == player_id:
            by_club[club_id].add(source)
    return by_club


def attrs_by_player(edges: set[tuple[str, str, str]]) -> dict[str, list[str]]:
    """Map player_id → list of attribute_ids (one entry per edge row, preserves duplicates)."""
    result: dict[str, list[str]] = defaultdict(list)
    for player_id, club_id, _source in edges:
        result[player_id].append(f"club:{club_id}")
    return dict(result)


def validation_join_rows(
    edges: set[tuple[str, str, str]], attr_a: str, attr_b: str
) -> list[str]:
    """Simulate INNER JOIN on player_attributes without DISTINCT."""
    by_player = attrs_by_player(edges)
    rows: list[str] = []
    for player_id, attrs in by_player.items():
        a_hits = [a for a in attrs if a == attr_a]
        b_hits = [b for b in attrs if b == attr_b]
        for _ in a_hits:
            for _ in b_hits:
                rows.append(player_id)
    return rows


def validation_distinct_players(
    edges: set[tuple[str, str, str]], attr_a: str, attr_b: str
) -> list[str]:
    """Simulate validation query with DISTINCT player_id."""
    return list(dict.fromkeys(validation_join_rows(edges, attr_a, attr_b)))


def run_spot_checks(
    edges: set[tuple[str, str, str]], pl_club_ids: set[str]
) -> tuple[list[str], dict]:
    errors: list[str] = []
    details: dict = {}

    salah = clubs_for_player(edges, SALAH_PLAYER_ID)
    details["salah"] = {
        "player_id": SALAH_PLAYER_ID,
        "clubs": {cid: sorted(sources) for cid, sources in salah.items()},
    }
    if LIVERPOOL_CLUB_ID not in salah:
        errors.append(
            f"Salah ({SALAH_PLAYER_ID}) missing club:{LIVERPOOL_CLUB_ID} (Liverpool)"
        )

    etoo = clubs_for_player(edges, ETOO_PLAYER_ID)
    etoo_pl = sorted(cid for cid in etoo if cid in pl_club_ids)
    details["etoo"] = {
        "player_id": ETOO_PLAYER_ID,
        "clubs": {cid: sorted(sources) for cid, sources in etoo.items()},
        "pl_clubs": etoo_pl,
        "has_barcelona": BARCELONA_CLUB_ID in etoo,
    }

    if BARCELONA_CLUB_ID not in etoo:
        errors.append(
            f"Eto'o ({ETOO_PLAYER_ID}) missing club:{BARCELONA_CLUB_ID} (Barcelona) "
            "— not present in source transfers/appearances for this dataset"
        )
    if not etoo_pl:
        errors.append(f"Eto'o ({ETOO_PLAYER_ID}) missing any Premier League club edge")

    return errors, details


def run_duplicate_source_check(edges: set[tuple[str, str, str]]) -> tuple[bool, dict]:
    """Ensure duplicate sources do not break DISTINCT validation (per dataset-plan)."""
    sources_by_pair: dict[tuple[str, str], set[str]] = defaultdict(set)
    for player_id, club_id, source in edges:
        sources_by_pair[(player_id, club_id)].add(source)

    multi_source_pairs = {
        pair: sorted(sources)
        for pair, sources in sources_by_pair.items()
        if len(sources) > 1
    }

    salah_pair = (SALAH_PLAYER_ID, LIVERPOOL_CLUB_ID)
    salah_sources = sorted(sources_by_pair.get(salah_pair, set()))
    club_attr = f"club:{LIVERPOOL_CLUB_ID}"

    join_rows = validation_join_rows(edges, club_attr, club_attr)
    distinct_players = validation_distinct_players(edges, club_attr, club_attr)
    salah_join_count = join_rows.count(SALAH_PLAYER_ID)
    salah_distinct_count = distinct_players.count(SALAH_PLAYER_ID)

    details = {
        "multi_source_pair_count": len(multi_source_pairs),
        "salah_liverpool_sources": salah_sources,
        "salah_join_row_count": salah_join_count,
        "salah_distinct_count": salah_distinct_count,
        "sample_multi_source": {
            f"{pid}:{cid}": srcs
            for (pid, cid), srcs in list(multi_source_pairs.items())[:5]
        },
    }

    ok = True
    if salah_pair in multi_source_pairs:
        # JOIN can emit multiple rows; DISTINCT must return the player once.
        if salah_join_count < 2:
            ok = False
            details["error"] = "expected Salah dual-source join to produce >1 row"
        elif salah_distinct_count != 1:
            ok = False
            details["error"] = "DISTINCT player_id must collapse Salah to one result"
        else:
            details["salah_dual_source_ok"] = True

    if not multi_source_pairs:
        details["note"] = "no dual-source pairs in dataset"

    return ok, details


def require_normalized_inputs() -> list[str]:
    missing = []
    for name in ("transfers.csv", "appearances.csv", "clubs.csv"):
        if not (STAGING_NORM / name).is_file():
            missing.append(name)
    return missing


def main() -> int:
    missing = require_normalized_inputs()
    if missing:
        print("D3 merge FAILED: run D2 normalize first; missing:", file=sys.stderr)
        for name in missing:
            print(f"  - {STAGING_NORM / name}", file=sys.stderr)
        return 1

    allowlisted = load_allowlisted_club_ids()
    pl_club_ids = load_pl_club_ids()
    edges, supplemental_count = collect_edges(allowlisted)
    row_count = write_player_club(edges)

    spot_errors, spot_details = run_spot_checks(edges, pl_club_ids)
    dup_ok, dup_details = run_duplicate_source_check(edges)

    errors = list(spot_errors)
    if not dup_ok:
        errors.append("duplicate (player_id, club_id) sources break DISTINCT validation logic")

    by_source: dict[str, int] = defaultdict(int)
    for _pid, _cid, source in edges:
        by_source[source] += 1

    distinct_pairs = len({(pid, cid) for pid, cid, _ in edges})

    summary = {
        "phase": "D3",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "output": str(OUTPUT_PATH),
        "edge_rows": row_count,
        "distinct_player_club_pairs": distinct_pairs,
        "edges_by_source": dict(by_source),
        "supplemental_edges_added": supplemental_count,
        "spot_checks": spot_details,
        "duplicate_source_check": dup_details,
        "spot_check_passed": not spot_errors,
        "duplicate_check_passed": dup_ok,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if errors:
        print("D3 merge FAILED:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D3 merge OK: {row_count:,} edges ({distinct_pairs:,} distinct player-club pairs), "
        f"transfer={by_source['transfer']:,}, appearance={by_source['appearance']:,}"
    )
    print(f"  output: {OUTPUT_PATH}")
    print(f"  report: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
