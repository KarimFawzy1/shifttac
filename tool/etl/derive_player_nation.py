#!/usr/bin/env python3
"""Phase D5 — derive player_nation edges from citizenship.

Reads normalized players.csv, maps citizenship via nation aliases + allowlist,
writes:

  tool/etl/staging/player_nation.csv
  tool/etl/staging/attributes_nation.csv
  tool/etl/reports/derive_player_nation_summary.json

v1 uses a single country_of_citizenship per player (no dual-citizenship edges).

Exit 1 if inputs missing or DoD spot-checks fail.
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

from etl_common import NationResolver, REPORTS, STAGING_NORM, load_yaml  # noqa: E402

STAGING = _ETL_DIR / "staging"
PLAYER_NATION_PATH = STAGING / "player_nation.csv"
ATTRIBUTES_NATION_PATH = STAGING / "attributes_nation.csv"
SUMMARY_PATH = REPORTS / "derive_player_nation_summary.json"
PLAYER_CLUB_PATH = STAGING / "player_club.csv"

DROGBA_PLAYER_ID = "3924"
IVORY_COAST_SLUG = "ivory_coast"

PLAYER_NATION_FIELDS = ("player_id", "nation_slug", "attribute_id", "source")
ATTRIBUTE_FIELDS = ("id", "type", "display_name", "slug", "source_id", "icon_key")

DUAL_CITIZENSHIP_NOTE = (
    "v1 emits one nation edge per player from country_of_citizenship only. "
    "Transfermarkt does not expose a second citizenship field in players.csv; "
    "dual citizenship would require an additional source in a future schema version."
)


def slug_to_display(nations_allowlist: dict[str, str]) -> dict[str, str]:
    """nation slug → UI display_name (first allowlist label for each slug)."""
    by_slug: dict[str, str] = {}
    for display, slug in nations_allowlist.items():
        by_slug.setdefault(slug, display)
    return by_slug


def build_resolver() -> NationResolver:
    nations_cfg = load_yaml("nations_allowlist.yaml").get("nations") or {}
    aliases_cfg = load_yaml("name_aliases.yaml").get("nations") or {}
    return NationResolver(nations_cfg, aliases_cfg)


def collect_player_nation_edges(
    resolver: NationResolver,
) -> tuple[list[dict[str, str]], int]:
    """Return edge rows and count of players with citizenship but no allowlisted mapping."""
    edges: list[dict[str, str]] = []
    unmapped_citizenship_rows = 0

    with (STAGING_NORM / "players.csv").open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            player_id = (row.get("player_id") or "").strip()
            if not player_id:
                continue

            slug = (row.get("nation_slug") or "").strip()
            if not slug:
                citizenship = (row.get("country_of_citizenship") or "").strip()
                slug = resolver.resolve(citizenship)
                if citizenship and not slug:
                    unmapped_citizenship_rows += 1

            if not slug or slug not in resolver.allowed_slugs:
                continue

            edges.append(
                {
                    "player_id": player_id,
                    "nation_slug": slug,
                    "attribute_id": f"nation:{slug}",
                    "source": "citizenship",
                }
            )

    return edges, unmapped_citizenship_rows


def write_player_nation(edges: list[dict[str, str]]) -> int:
    STAGING.mkdir(parents=True, exist_ok=True)
    sorted_edges = sorted(edges, key=lambda r: r["player_id"])
    with PLAYER_NATION_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=PLAYER_NATION_FIELDS)
        writer.writeheader()
        writer.writerows(sorted_edges)
    return len(sorted_edges)


def write_attributes_nation(nations_allowlist: dict[str, str]) -> int:
    """One attributes row per allowlisted nation (all 25), for SQLite import in D11."""
    display_by_slug = slug_to_display(nations_allowlist)
    rows: list[dict[str, str]] = []

    for display, slug in sorted(nations_allowlist.items(), key=lambda x: x[1]):
        rows.append(
            {
                "id": f"nation:{slug}",
                "type": "nation",
                "display_name": display_by_slug.get(slug, display),
                "slug": slug,
                "source_id": "",
                "icon_key": f"nation_{slug}",
            }
        )

    with ATTRIBUTES_NATION_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=ATTRIBUTE_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    return len(rows)


def clubs_for_player(player_id: str) -> list[str]:
    if not PLAYER_CLUB_PATH.is_file():
        return []
    clubs: list[str] = []
    with PLAYER_CLUB_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("player_id") == player_id:
                clubs.append(row.get("attribute_id") or f"club:{row.get('club_id')}")
    return sorted(set(clubs))


def nation_for_player(player_id: str, edges: list[dict[str, str]]) -> str | None:
    for row in edges:
        if row["player_id"] == player_id:
            return row["attribute_id"]
    return None


def run_spot_checks(edges: list[dict[str, str]]) -> tuple[list[str], dict]:
    errors: list[str] = []
    drogba_nation = nation_for_player(DROGBA_PLAYER_ID, edges)
    drogba_clubs = clubs_for_player(DROGBA_PLAYER_ID)

    details = {
        "drogba": {
            "player_id": DROGBA_PLAYER_ID,
            "nation_attribute": drogba_nation,
            "club_attributes": drogba_clubs,
        },
        "dual_citizenship": {
            "supported": False,
            "limitation": DUAL_CITIZENSHIP_NOTE,
        },
    }

    expected = f"nation:{IVORY_COAST_SLUG}"
    if drogba_nation != expected:
        errors.append(
            f"Drogba ({DROGBA_PLAYER_ID}) expected {expected}, got {drogba_nation!r}"
        )
    if not drogba_clubs:
        errors.append(f"Drogba ({DROGBA_PLAYER_ID}) missing club edges in player_club.csv")

    return errors, details


def main() -> int:
    players_path = STAGING_NORM / "players.csv"
    if not players_path.is_file():
        print(
            f"D5 derive FAILED: missing {players_path} (run D2 normalize first)",
            file=sys.stderr,
        )
        return 1

    nations_allowlist = load_yaml("nations_allowlist.yaml").get("nations") or {}
    resolver = build_resolver()
    edges, unmapped_rows = collect_player_nation_edges(resolver)
    nation_rows = write_player_nation(edges)
    used_slugs = {e["nation_slug"] for e in edges}
    attribute_rows = write_attributes_nation(nations_allowlist)

    spot_errors, spot_details = run_spot_checks(edges)

    summary = {
        "phase": "D5",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "player_nation_output": str(PLAYER_NATION_PATH),
        "attributes_nation_output": str(ATTRIBUTES_NATION_PATH),
        "player_nation_edges": nation_rows,
        "attributes_nation_rows": attribute_rows,
        "distinct_nation_slugs_with_players": len(used_slugs),
        "players_with_unmapped_citizenship": unmapped_rows,
        "spot_checks": spot_details,
        "spot_check_passed": not spot_errors,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if spot_errors:
        print("D5 derive FAILED:", file=sys.stderr)
        for err in spot_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D5 derive OK: {nation_rows:,} player_nation edges, "
        f"{attribute_rows} nation attributes ({len(used_slugs)} slugs with players)"
    )
    print(f"  output: {PLAYER_NATION_PATH}")
    print(f"  attributes: {ATTRIBUTES_NATION_PATH}")
    print(f"  report: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
