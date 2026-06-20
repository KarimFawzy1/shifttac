#!/usr/bin/env python3
"""Strip non-allowlisted nationalities/clubs from legendary CSV, keeping explicit exceptions."""

from __future__ import annotations

import csv
import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
NATIONS_YAML = ROOT / "tool" / "etl" / "config" / "nations_allowlist.yaml"
CLUBS_YAML = ROOT / "tool" / "etl" / "config" / "clubs_allowlist.yaml"
REPORT_PATH = ROOT / "legendary-players" / "attribute_filter_report.json"

# Nations intentionally excluded from v1 boards — must NOT be added to EXCEPTION_NATIONS.
STRIPPED_NATIONS = frozenset(
    {
        "North Macedonia",
        "Iran",
        "Georgia",
        "Paraguay",
        "Zambia",
        "South Africa",
        "New Zealand",
    }
)

EXCEPTION_NATIONS = {
    "Hungary",
    "Saudi Arabia",
    "Sweden",
    "Chile",
    "Czech Republic",
    "Russia",
    "Serbia",
    "Wales",
    "Australia",
    "Bulgaria",
    "Ghana",
    "Montenegro",
    "Norway",
    "Peru",
    "Poland",
    "Scotland",
    "South Korea",
    "Finland",
    "Ireland",
    "Liberia",
    "Northern Ireland",
    "Romania",
    "Slovakia",
    "Ukraine",
    "Argentina / Spain",  # Di Stéfano dual-nationality
}

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

# CSV spellings that map to exception club names above.
CLUB_ALIASES = {
    "Nantes": "FC Nantes",
    "Basel": "FC Basel",
    "Al-Shabab": "AlShabab",
    "Koln": "FC Köln",
    "Paris Saint-Germain": "Paris Saint Germain",
    "Al-Nassr": "Al Nassr",
    "Al-Hilal": "Al Hilal",
    "Al-Ahli": "Al Ahli",
    "Al-Ittihad": "Al Ittihad",
}


def load_allowed_nations() -> set[str]:
    cfg = yaml.safe_load(NATIONS_YAML.read_text(encoding="utf-8"))
    return set(cfg.get("nations", {}).keys()) | EXCEPTION_NATIONS


def load_allowed_clubs() -> set[str]:
    cfg = yaml.safe_load(CLUBS_YAML.read_text(encoding="utf-8"))
    allowed = set(cfg.get("clubs", {}).keys()) | EXCEPTION_CLUBS
    for alias, canonical in CLUB_ALIASES.items():
        if canonical in allowed:
            allowed.add(alias)
    return allowed


def parse_clubs(raw: str) -> list[str]:
    return [part.strip() for part in (raw or "").split(",") if part.strip()]


def join_clubs(clubs: list[str]) -> str:
    return ", ".join(clubs)


def main() -> None:
    allowed_nations = load_allowed_nations()
    assert not STRIPPED_NATIONS & EXCEPTION_NATIONS, "STRIPPED_NATIONS must stay out of EXCEPTION_NATIONS"
    allowed_clubs = load_allowed_clubs()

    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
    fieldnames = list(rows[0].keys()) if rows else []

    removed_nationalities: list[dict[str, str]] = []
    removed_clubs: list[dict[str, str]] = []

    for row in rows:
        player = row.get("Player Name", "")
        nationality = (row.get("Nationality") or "").strip()
        if nationality and nationality not in allowed_nations:
            removed_nationalities.append({"player": player, "nationality": nationality})
            row["Nationality"] = ""

        clubs = parse_clubs(row.get("Senior Clubs Played For", ""))
        kept: list[str] = []
        for club in clubs:
            if club in allowed_clubs:
                kept.append(club)
            else:
                removed_clubs.append({"player": player, "club": club})

        row["Senior Clubs Played For"] = join_clubs(kept)

    with CSV_PATH.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    report = {
        "players_total": len(rows),
        "removed_nationality_count": len(removed_nationalities),
        "removed_club_count": len(removed_clubs),
        "removed_nationalities": removed_nationalities,
        "removed_clubs_by_name": {},
    }
    for item in removed_clubs:
        report["removed_clubs_by_name"].setdefault(item["club"], 0)
        report["removed_clubs_by_name"][item["club"]] += 1

    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Updated {CSV_PATH}")
    print(f"Removed {len(removed_nationalities)} nationality values")
    print(f"Removed {len(removed_clubs)} club entries")
    print(f"Report: {REPORT_PATH}")


if __name__ == "__main__":
    main()
