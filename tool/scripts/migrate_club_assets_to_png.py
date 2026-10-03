#!/usr/bin/env python3
"""Copy selected club PNGs from all-clubs into attrs/clubs with dash naming."""

from __future__ import annotations

import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ALL_CLUBS_DIR = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "all-clubs"
CLUBS_DIR = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "clubs"

# Target filename (Title-Case slug) -> source stem in all-clubs (before .football-logos.cc.png)
CLUB_SOURCES: dict[str, str] = {
    "Arsenal": "arsenal",
    "Aston-Villa": "aston-villa",
    "Brentford": "brentford",
    "Brighton": "brighton",
    "Chelsea": "chelsea",
    "Crystal-Palace": "crystal-palace",
    "Everton": "everton",
    "Fulham": "fulham",
    "Leeds-United": "leeds-united",
    "Liverpool": "liverpool",
    "Manchester-City": "manchester-city",
    "Manchester-United": "manchester-united",
    "Newcastle-United": "newcastle",
    "Tottenham-Hotspur": "tottenham",
    "West-Ham-United": "west-ham",
    "Wolverhampton": "wolves",
    "Atlético-Madrid": "atletico-madrid",
    "Barcelona": "barcelona",
    "Real-Madrid": "real-madrid",
    "Sevilla": "sevilla",
    "Valencia": "valencia",
    "Villarreal": "villarreal",
    "AC-Milan": "milan",
    "Atalanta": "atalanta",
    "Bologna": "bologna",
    "Fiorentina": "fiorentina",
    "Inter-Milan": "inter",
    "Juventus": "juventus",
    "Lazio": "lazio",
    "Napoli": "napoli",
    "Roma": "roma",
    "Bayern-Munich": "bayern-munchen",
    "Bayer-Leverkusen": "bayer-leverkusen",
    "Borussia-Dortmund": "borussia-dortmund",
    "Eintracht-Frankfurt": "eintracht-frankfurt",
    "RB-Leipzig": "rb-leipzig",
    "Union-Berlin": "union-berlin",
    "VfB-Stuttgart": "vfb-stuttgart",
    "Lille": "lille",
    "Lyon": "lyon",
    "Marseille": "marseille",
    "Monaco": "as-monaco",
    "Nice": "nice",
    "Paris-Saint-Germain": "paris-saint-germain",
    "Ajax": "ajax",
    "PSV-Eindhoven": "psv",
    "Benfica": "benfica",
    "Porto": "fc-porto",
    "Sporting-CP": "sporting-cp",
    "Galatasaray": "galatasaray",
    "Boca-Juniors": "boca-juniors",
    "Flamengo": "flamengo",
    "Santos": "santos",
    "River-Plate": "river-plate",
    "Corinthians": "corinthians",
    "Fluminense": "fluminense",
    "Palmeiras": "palmeiras",
    "Botafogo": "botafogo",
    "Rangers": "rangers",
    "Celtic": "celtic",
    "Southampton": "southampton",
    "Nottingham-Forest": "nottingham-forest",
    "Hamburger-SV": "hamburger-sv",
    "FC-Köln": "koln",
    "VfL-Wolfsburg": "wolfsburg",
    "Schalke-04": "schalke-04",
    "Parma": "parma",
    "Genoa": "genoa",
    "Udinese": "udinese",
    "Torino": "torino",
    "Espanyol": "espanyol",
    "Deportivo-La-Coruña": "deportivo-la-coruna",
    "Celta-Vigo": "celta",
    "Athletic-Bilbao": "athletic-club",
    "Real-Sociedad": "real-sociedad",
    "FC-Nantes": "nantes",
    "Feyenoord": "feyenoord",
    "Fenerbahçe": "fenerbahce",
    "Los-Angeles-Galaxy": "la-galaxy",
    "Inter-Miami": "inter-miami-cf",
    "Al-Nassr": "al-nassr",
    "Al-Hilal": "al-hilal",
    "Al-Ahli": "al-ahli",
    "Al-Ittihad": "al-ittihad",
    "Al-Shabab": "al-shabab",
    "Real-Zaragoza": "zaragoza",
    "Como": "como-1907",
    "Rayo-Vallecano": "rayo-vallecano",
    "Real-Valladolid": "valladolid",
    "Burnley": "burnley",
    "Stoke-City": "stoke-city",
}


def source_path(stem: str) -> Path:
    return ALL_CLUBS_DIR / f"{stem}.football-logos.cc.png"


def main() -> int:
    if not ALL_CLUBS_DIR.is_dir():
        raise SystemExit(f"Missing source directory: {ALL_CLUBS_DIR}")

    CLUBS_DIR.mkdir(parents=True, exist_ok=True)

    copied: list[str] = []
    missing: list[str] = []

    for target_name, source_stem in CLUB_SOURCES.items():
        src = source_path(source_stem)
        dst = CLUBS_DIR / f"{target_name}.png"
        if not src.is_file():
            missing.append(f"{target_name} <- {src.name}")
            continue
        shutil.copy2(src, dst)
        copied.append(dst.name)

    for svg in CLUBS_DIR.glob("*.svg"):
        svg.unlink()

    print(f"Copied {len(copied)} PNGs to {CLUBS_DIR}")
    if missing:
        print(f"Missing {len(missing)} source PNG(s):")
        for item in missing:
            print(f"  - {item}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
