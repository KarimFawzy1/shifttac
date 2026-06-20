#!/usr/bin/env python3
"""Count legendary players per famous club and list other high-count clubs."""

from __future__ import annotations

import csv
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
OUT_PATH = ROOT / "legendary-players" / "club_player_counts.md"

FAMOUS_BY_REGION: dict[str, list[str]] = {
    "Argentina": [
        "River Plate", "Newell's Old Boys", "Independiente", "Racing Club",
        "Estudiantes", "Vélez Sarsfield", "San Lorenzo", "Argentinos Juniors",
    ],
    "Brazil": [
        "Corinthians", "São Paulo", "Fluminense", "Cruzeiro", "Palmeiras",
        "Grêmio", "Vasco da Gama", "Botafogo", "Internacional",
        "Atlético Mineiro", "Bahia",
    ],
    "Colombia": ["Atlético Nacional", "Millonarios", "América"],
    "England / Scotland": [
        "Celtic", "Rangers", "Southampton", "Nottingham Forest", "Leicester City",
    ],
    "Germany": [
        "Borussia Mönchengladbach", "Hamburger SV", "Werder Bremen", "FC Köln",
        "Schalke 04", "VfL Wolfsburg", "1860 Munich",
    ],
    "Italy": ["Sampdoria", "Parma", "Genoa", "Torino", "Udinese"],
    "Spain": [
        "Espanyol", "Deportivo La Coruña", "Athletic Bilbao", "Real Sociedad",
        "Celta Vigo",
    ],
    "France": ["Bordeaux", "Saint-Étienne", "Nantes"],
    "Netherlands": ["Feyenoord"],
    "Portugal": ["Braga"],
    "Turkey / Greece": [
        "Fenerbahçe", "Beşiktaş", "Olympiacos", "Panathinaikos", "AEK Athens",
        "Trabzonspor",
    ],
    "Eastern Europe": [
        "Red Star Belgrade", "Dinamo Zagreb", "Dynamo Kyiv", "Sparta Prague",
    ],
    "Switzerland / Belgium": ["Basel", "Anderlecht", "Club Brugge"],
    "USA / MLS": [
        "New York Cosmos", "New York Red Bulls", "Los Angeles Galaxy",
        "Los Angeles FC", "Los Angeles Aztecs", "D.C. United", "Chicago Fire",
        "Inter Miami", "MetroStars", "Seattle Sounders", "New York City FC",
    ],
    "Middle East": ["Al-Hilal", "Al-Nassr", "Al-Sadd", "Al-Ahli", "Al-Ittihad"],
    "Japan": ["Vissel Kobe", "Kashima Antlers"],
    "Scandinavia": ["Malmö FF"],
}

FAMOUS_SET = {club for clubs in FAMOUS_BY_REGION.values() for club in clubs}


def load_rows() -> list[dict[str, str]]:
    return list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))


def club_player_map(rows: list[dict[str, str]]) -> dict[str, list[str]]:
    mapping: dict[str, list[str]] = defaultdict(list)
    for row in rows:
        name = (row.get("Player Name") or "").strip()
        for club in (row.get("Senior Clubs Played For") or "").split(","):
            club = club.strip()
            if club:
                mapping[club].append(name)
    return mapping


def main() -> None:
    rows = load_rows()
    mapping = club_player_map(rows)
    all_club_counts = {club: len(players) for club, players in mapping.items()}

    lines: list[str] = []
    lines.append("# Legendary players per famous club\n")
    lines.append(f"Source: `legendary_players_with_tm_id.csv` ({len(rows)} players)\n")

    for region, clubs in FAMOUS_BY_REGION.items():
        lines.append(f"## {region}\n")
        lines.append("| Club | Players |")
        lines.append("| --- | ---: |")
        for club in clubs:
            count = all_club_counts.get(club, 0)
            lines.append(f"| {club} | {count} |")
        lines.append("")

    lines.append("## Other clubs with 3+ legendary players (not in famous list)\n")
    lines.append("| Club | Players |")
    lines.append("| --- | ---: |")
    others = sorted(
        ((club, count) for club, count in all_club_counts.items() if club not in FAMOUS_SET and count > 2),
        key=lambda item: (-item[1], item[0]),
    )
    for club, count in others:
        lines.append(f"| {club} | {count} |")
    lines.append(f"\nTotal: **{len(others)}** clubs\n")

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(OUT_PATH)


if __name__ == "__main__":
    main()
