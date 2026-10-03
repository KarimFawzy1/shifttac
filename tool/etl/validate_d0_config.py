#!/usr/bin/env python3
"""Validate Phase D0 config against transfermarkt-datasets/*.csv.

Exit 0 when all DoD checks pass; non-zero otherwise.
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Install PyYAML: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[2]
CONFIG = Path(__file__).resolve().parent / "config"
DATASETS = ROOT / "transfermarkt-datasets"

EXPECTED_LEAGUES = {
    "Premier League": "GB1",
    "La Liga": "ES1",
    "Serie A": "IT1",
    "Bundesliga": "L1",
    "Ligue 1": "FR1",
}

REQUIRED_NATION_ALIASES = [
    ("Cote d'Ivoire", "ivory_coast"),
    ("Côte d'Ivoire", "ivory_coast"),
    ("USA", "united_states"),
    ("United States of America", "united_states"),
]


def load_yaml(name: str) -> dict:
    path = CONFIG / name
    if not path.is_file():
        raise FileNotFoundError(f"Missing config: {path}")
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def load_club_ids() -> set[str]:
    path = DATASETS / "clubs.csv"
    if not path.is_file():
        raise FileNotFoundError(f"Missing clubs.csv: {path}")
    ids: set[str] = set()
    with path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            ids.add(row["club_id"])
    return ids


def main() -> int:
    errors: list[str] = []

    clubs_cfg = load_yaml("clubs_allowlist.yaml")
    leagues_cfg = load_yaml("leagues_allowlist.yaml")
    nations_cfg = load_yaml("nations_allowlist.yaml")
    load_yaml("position_map.yaml")
    aliases_cfg = load_yaml("name_aliases.yaml")

    club_ids_csv = load_club_ids()
    clubs = clubs_cfg.get("clubs") or {}

    for display, club_id in clubs.items():
        cid = str(club_id)
        if cid not in club_ids_csv:
            errors.append(f"club '{display}' → club_id {cid} not in clubs.csv")

    if len(clubs) != len(set(str(v) for v in clubs.values())):
        dupes = [cid for cid in set(str(v) for v in clubs.values()) if sum(1 for v in clubs.values() if str(v) == cid) > 1]
        errors.append(f"duplicate club_id mappings: {dupes}")

    leagues = leagues_cfg.get("leagues") or {}
    for name, comp_id in EXPECTED_LEAGUES.items():
        if leagues.get(name) != comp_id:
            errors.append(f"league '{name}' expected {comp_id}, got {leagues.get(name)!r}")

    nation_aliases = aliases_cfg.get("nations") or {}
    for raw, slug in REQUIRED_NATION_ALIASES:
        if nation_aliases.get(raw) != slug:
            errors.append(f"nation alias '{raw}' → expected {slug}, got {nation_aliases.get(raw)!r}")

    nations = nations_cfg.get("nations") or {}
    if nations.get("Ivory Coast") != "ivory_coast":
        errors.append("nations_allowlist must map Ivory Coast → ivory_coast")
    if nations.get("United States") != "united_states":
        errors.append("nations_allowlist must map United States → united_states")

    if errors:
        print("D0 validation FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(
        f"D0 validation OK: {len(clubs)} clubs, {len(leagues)} leagues, "
        f"{len(nations)} nations, {len(nation_aliases)} nation aliases"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
