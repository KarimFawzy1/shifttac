#!/usr/bin/env python3
"""Verify every club string in the legendary CSV resolves to clubs_allowlist.yaml."""

from __future__ import annotations

import csv
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
CLUBS_YAML = ROOT / "tool" / "etl" / "config" / "clubs_allowlist.yaml"
ALIASES_YAML = ROOT / "tool" / "etl" / "config" / "legendary_club_aliases.yaml"

# Same exception set as filter_allowed_attributes.py (display names kept in CSV).
EXCEPTION_CLUBS = {
    "River Plate",
    "Corinthians",
    "Fluminense",
    "Palmeiras",
    "Botafogo",
    "Rangers",
    "Celtic",
    "Southampton",
    "Leicester City",
    "Nottingham Forest",
    "Hamburger SV",
    "FC Köln",
    "VfL Wolfsburg",
    "Schalke 04",
    "Parma",
    "Genoa",
    "Udinese",
    "Torino",
    "Espanyol",
    "Deportivo La Coruña",
    "Celta Vigo",
    "Athletic Bilbao",
    "Real Sociedad",
    "FC Nantes",
    "Feyenoord",
    "Fenerbahçe",
    "Olympiacos",
    "Red Star Belgrade",
    "Dinamo Zagreb",
    "Sparta Prague",
    "FC Basel",
    "Club Brugge",
    "Anderlecht",
    "Los Angeles Galaxy",
    "Inter Miami",
    "Al-Nassr",
    "Al-Hilal",
    "Al-Ahli",
    "Al-Ittihad",
    "AlShabab",
    "Real Zaragoza",
    "Como",
    "Rayo Vallecano",
    "Real Valladolid",
    "Burnley",
    "Stoke City",
}


def parse_clubs(raw: str) -> list[str]:
    return [part.strip() for part in (raw or "").split(",") if part.strip()]


def load_aliases() -> dict[str, str]:
    if not ALIASES_YAML.is_file():
        return {}
    cfg = yaml.safe_load(ALIASES_YAML.read_text(encoding="utf-8"))
    return dict(cfg.get("aliases") or {})


def resolve_club_id(club_name: str, clubs: dict[str, str], aliases: dict[str, str]) -> str | None:
    canonical = aliases.get(club_name, club_name)
    if canonical in clubs:
        return str(clubs[canonical])
    if club_name in clubs:
        return str(clubs[club_name])
    return None


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"Missing {CSV_PATH}", file=sys.stderr)
        return 1
    if not CLUBS_YAML.is_file():
        print(f"Missing {CLUBS_YAML}", file=sys.stderr)
        return 1

    clubs_cfg = yaml.safe_load(CLUBS_YAML.read_text(encoding="utf-8"))
    clubs: dict[str, str] = clubs_cfg.get("clubs") or {}
    aliases = load_aliases()
    allowed_names = set(clubs.keys()) | EXCEPTION_CLUBS | set(aliases.keys())

    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
    unmapped: dict[str, list[str]] = {}

    for row in rows:
        player = row.get("Player Name", "")
        for club in parse_clubs(row.get("Senior Clubs Played For", "")):
            if club in allowed_names and resolve_club_id(club, clubs, aliases):
                continue
            unmapped.setdefault(club, []).append(player)

    if unmapped:
        print(f"Unmapped club strings: {len(unmapped)}", file=sys.stderr)
        for club, players in sorted(unmapped.items()):
            print(f"  {club!r} ({len(players)} players)", file=sys.stderr)
        return 1

    print(f"OK: all club strings in {CSV_PATH.name} resolve to club_id")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
