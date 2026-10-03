#!/usr/bin/env python3
"""Sync clubs/nations allowlists, DB attributes, manifest, and gallery index from asset folders."""

from __future__ import annotations

import csv
import json
import re
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CLUBS_DIR = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "clubs"
NATIONS_DIR = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "nations"
DB_PATH = REPO_ROOT / "assets" / "db" / "tiki_taka.db"
CLUBS_CSV = REPO_ROOT / "tool" / "etl" / "staging" / "clubs.csv"
CLUBS_ALLOWLIST = REPO_ROOT / "tool" / "etl" / "config" / "clubs_allowlist.yaml"
NATIONS_ALLOWLIST = REPO_ROOT / "tool" / "etl" / "config" / "nations_allowlist.yaml"
ATTRIBUTES_NATION_CSV = REPO_ROOT / "tool" / "etl" / "staging" / "attributes_nation.csv"
GALLERY_INDEX = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "gallery_index.json"

CLUB_RENAMES = {
    "belgium_anderlecht_512x512.football-logos.cc.png": "Anderlecht.png",
    "belgium_club-brugge_512x512.football-logos.cc.png": "Club-Brugge.png",
    "croatia_dinamo-zagreb_512x512.football-logos.cc.png": "Dinamo-Zagreb.png",
    "czech-republic_sparta-praha_512x512.football-logos.cc.png": "Sparta-Prague.png",
    "england_leicester_512x512.football-logos.cc.png": "Leicester-City.png",
    "greece_olympiacos_512x512.football-logos.cc.png": "Olympiacos.png",
    "serbia_crvena-zvezda_512x512.football-logos.cc.png": "Red-Star-Belgrade.png",
    "switzerland_basel_512x512.football-logos.cc.png": "FC-Basel.png",
}

# Filename slug -> Transfermarkt display_name aliases for lookup in clubs.csv
CLUB_LOOKUP_ALIASES: dict[str, list[str]] = {
    "AC Milan": ["AC Milan", "Milan"],
    "Inter Milan": ["Inter Milan", "Inter"],
    "Bayern Munich": ["Bayern Munich", "Bayern München", "Bayern Munchen"],
    "PSV Eindhoven": ["PSV Eindhoven", "PSV"],
    "Sporting CP": ["Sporting CP", "Sporting Clube de Portugal"],
    "West Ham United": ["West Ham United", "West Ham"],
    "Tottenham Hotspur": ["Tottenham Hotspur", "Tottenham"],
    "Newcastle United": ["Newcastle United", "Newcastle"],
    "Manchester United": ["Manchester United"],
    "Manchester City": ["Manchester City"],
    "Leeds United": ["Leeds United", "Leeds"],
    "Crystal Palace": ["Crystal Palace"],
    "Union Berlin": ["Union Berlin", "1. FC Union Berlin"],
    "RB Leipzig": ["RB Leipzig", "RasenBallsport Leipzig"],
    "Bayer Leverkusen": ["Bayer Leverkusen", "Bayer 04 Leverkusen"],
    "Borussia Dortmund": ["Borussia Dortmund", "BVB"],
    "Eintracht Frankfurt": ["Eintracht Frankfurt"],
    "VfB Stuttgart": ["VfB Stuttgart"],
    "VfL Wolfsburg": ["VfL Wolfsburg", "Wolfsburg"],
    "Hamburger SV": ["Hamburger SV", "Hamburg"],
    "FC Köln": ["FC Köln", "1. FC Köln", "FC Koln", "Koln"],
    "Schalke 04": ["Schalke 04", "FC Schalke 04"],
    "Paris Saint-Germain": ["Paris Saint-Germain", "Paris SG"],
    "Monaco": ["Monaco", "AS Monaco"],
    "Inter Miami": ["Inter Miami", "Inter Miami CF"],
    "Los Angeles Galaxy": ["Los Angeles Galaxy", "LA Galaxy"],
    "FC Nantes": ["FC Nantes", "Nantes"],
    "Deportivo La Coruña": ["Deportivo La Coruña", "Deportivo La Coruna"],
    "Celta Vigo": ["Celta Vigo", "Celta de Vigo", "RC Celta"],
    "Athletic Bilbao": ["Athletic Bilbao", "Athletic Club"],
    "Real Sociedad": ["Real Sociedad"],
    "Real Zaragoza": ["Real Zaragoza", "Zaragoza"],
    "Real Valladolid": ["Real Valladolid", "Valladolid"],
    "Rayo Vallecano": ["Rayo Vallecano"],
    "Club Brugge": ["Club Brugge", "Club Brugge KV"],
    "Red Star Belgrade": ["Red Star Belgrade", "Crvena zvezda", "Roter Stern Belgrad"],
    "Dinamo Zagreb": ["Dinamo Zagreb", "GNK Dinamo Zagreb"],
    "Sparta Prague": ["Sparta Prague", "Sparta Praha", "AC Sparta Praha"],
    "FC Basel": ["FC Basel", "FC Basel 1893"],
    "Olympiacos": ["Olympiacos", "Olympiakos", "Olympiakos Piraeus"],
    "Anderlecht": ["Anderlecht", "RSC Anderlecht", "Royal Sporting Club Anderlecht"],
    "Al-Shabab": ["Al-Shabab", "Al Shabab"],
}

MANUAL_CLUB_IDS: dict[str, str] = {
    "Copenhagen": "190",
    "Inter Milan": "46",
    "Inter Miami": "69261",
}


def normalize_name(value: str) -> str:
    value = value.lower()
    value = value.replace("ä", "a").replace("ö", "o").replace("ü", "u")
    value = value.replace("é", "e").replace("è", "e").replace("á", "a")
    value = value.replace("í", "i").replace("ó", "o").replace("ú", "u")
    value = value.replace("ñ", "n").replace("ç", "c").replace("ß", "ss")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return " ".join(value.split())


def filename_to_display_name(filename: str) -> str:
    stem = Path(filename).stem
    return stem.replace("-", " ")


def filename_to_slug(filename: str) -> str:
    stem = Path(filename).stem
    return stem.lower().replace("-", "_")


def rename_club_assets() -> None:
    for old_name, new_name in CLUB_RENAMES.items():
        src = CLUBS_DIR / old_name
        dst = CLUBS_DIR / new_name
        if src.is_file():
            if dst.is_file() and src.resolve() != dst.resolve():
                src.unlink()
            else:
                src.rename(dst)


def filename_to_club_code(filename: str) -> str:
    stem = Path(filename).stem
    return normalize_name(stem).replace(" ", "-")


def load_clubs_csv() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with CLUBS_CSV.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            club_id = (row.get("club_id") or "").strip()
            name = (row.get("name") or "").strip()
            club_code = (row.get("club_code") or "").strip()
            if club_id and name:
                rows.append(
                    {
                        "club_id": club_id,
                        "name": name,
                        "club_code": club_code,
                        "normalized_name": normalize_name(name),
                    }
                )
    return rows


def resolve_club_id(display_name: str, clubs_csv: list[dict[str, str]], club_code: str) -> str | None:
    manual = MANUAL_CLUB_IDS.get(display_name)
    if manual:
        return manual

    aliases = CLUB_LOOKUP_ALIASES.get(display_name, [display_name])
    normalized_aliases = {normalize_name(alias) for alias in aliases}
    normalized_aliases.add(normalize_name(display_name))

    for row in clubs_csv:
        if row["normalized_name"] in normalized_aliases:
            return row["club_id"]

    code_candidates = {club_code}
    code_candidates.add(club_code.replace("-fc", ""))
    for row in clubs_csv:
        row_code = row["club_code"]
        if row_code in code_candidates:
            return row["club_id"]
        if row_code.endswith(club_code) or club_code.endswith(row_code):
            return row["club_id"]

    tokens = normalized_aliases
    best_id: str | None = None
    best_score = 0
    for row in clubs_csv:
        row_tokens = set(row["normalized_name"].split())
        for alias_tokens in tokens:
            alias_parts = set(alias_tokens.split())
            overlap = len(alias_parts & row_tokens)
            if overlap > best_score and overlap >= min(2, len(alias_parts)):
                best_score = overlap
                best_id = row["club_id"]

    return best_id


def write_yaml_mapping(path: Path, key: str, mapping: dict[str, str]) -> None:
    lines = [f"# Auto-synced from bundled assets in {path.parent.name}/", 'version: "1"', f"{key}:"]
    for display_name, value in sorted(mapping.items(), key=lambda item: item[0].lower()):
        lines.append(f'  {display_name}: "{value}"')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def sync_clubs_allowlist(clubs_csv: list[dict[str, str]]) -> dict[str, str]:
    allowlist: dict[str, str] = {}
    missing: list[str] = []

    for png in sorted(CLUBS_DIR.glob("*.png")):
        display_name = filename_to_display_name(png.name)
        club_code = filename_to_club_code(png.name)
        club_id = resolve_club_id(display_name, clubs_csv, club_code)
        if club_id is None:
            missing.append(display_name)
            continue
        if club_id in allowlist.values():
            print(
                f"WARNING: skipping duplicate club id {club_id} for {display_name}",
                file=sys.stderr,
            )
            continue
        allowlist[display_name] = club_id

    if missing:
        print("WARNING: no Transfermarkt id for club assets:", ", ".join(missing), file=sys.stderr)

    write_yaml_mapping(CLUBS_ALLOWLIST, "clubs", allowlist)
    return allowlist


def sync_nations_allowlist() -> dict[str, str]:
    allowlist: dict[str, str] = {}
    for svg in sorted(NATIONS_DIR.glob("*.svg")):
        display_name = filename_to_display_name(svg.name)
        slug = filename_to_slug(svg.name)
        allowlist[display_name] = slug

    write_yaml_mapping(NATIONS_ALLOWLIST, "nations", allowlist)
    return allowlist


def write_attributes_nation_csv(nations_allowlist: dict[str, str]) -> None:
    slug_to_display: dict[str, str] = {}
    for display, slug in nations_allowlist.items():
        slug_to_display.setdefault(slug, display)

    rows: list[dict[str, str]] = []
    for slug in sorted(slug_to_display):
        display = slug_to_display[slug]
        rows.append(
            {
                "id": f"nation:{slug}",
                "type": "nation",
                "display_name": display,
                "slug": slug,
                "source_id": "",
                "icon_key": f"nation_{slug}",
            }
        )

    ATTRIBUTES_NATION_CSV.parent.mkdir(parents=True, exist_ok=True)
    with ATTRIBUTES_NATION_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["id", "type", "display_name", "slug", "source_id", "icon_key"],
        )
        writer.writeheader()
        writer.writerows(rows)


def patch_db_attributes(
    clubs_allowlist: dict[str, str],
    nations_allowlist: dict[str, str],
) -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("DELETE FROM attributes WHERE type IN ('club', 'nation')")

        club_rows = [
            (
                f"club:{club_id}",
                "club",
                display_name,
                f"club_{club_id}",
                club_id,
                f"club_{club_id}",
            )
            for display_name, club_id in clubs_allowlist.items()
        ]

        nation_rows = [
            (
                f"nation:{slug}",
                "nation",
                display_name,
                slug,
                "",
                f"nation_{slug}",
            )
            for display_name, slug in nations_allowlist.items()
        ]

        conn.executemany(
            """
            INSERT INTO attributes (id, type, display_name, slug, source_id, icon_key)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            club_rows + nation_rows,
        )
        conn.commit()
    finally:
        conn.close()


def write_gallery_index() -> None:
    entries: list[dict[str, str]] = []

    for png in sorted(CLUBS_DIR.glob("*.png")):
        path = f"assets/tiki_taka/attrs/clubs/{png.name}".replace("\\", "/")
        entries.append(
            {
                "kind": "club",
                "path": path,
                "label": filename_to_display_name(png.name),
            }
        )

    for svg in sorted(NATIONS_DIR.glob("*.svg")):
        path = f"assets/tiki_taka/attrs/nations/{svg.name}".replace("\\", "/")
        entries.append(
            {
                "kind": "nation",
                "path": path,
                "label": filename_to_display_name(svg.name),
            }
        )

    entries.sort(key=lambda item: (item["kind"], item["label"].lower()))
    GALLERY_INDEX.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    if not CLUBS_DIR.is_dir() or not NATIONS_DIR.is_dir():
        print("ERROR: clubs/ or nations/ asset folders missing", file=sys.stderr)
        return 1
    if not DB_PATH.is_file():
        print(f"ERROR: database not found: {DB_PATH}", file=sys.stderr)
        return 1
    if not CLUBS_CSV.is_file():
        print(f"ERROR: clubs.csv not found: {CLUBS_CSV}", file=sys.stderr)
        return 1

    rename_club_assets()
    clubs_csv = load_clubs_csv()
    clubs_allowlist = sync_clubs_allowlist(clubs_csv)
    nations_allowlist = sync_nations_allowlist()
    write_attributes_nation_csv(nations_allowlist)
    patch_db_attributes(clubs_allowlist, nations_allowlist)
    write_gallery_index()

    print(f"Synced {len(clubs_allowlist)} clubs and {len(nations_allowlist)} nations")
    print(f"Gallery index: {GALLERY_INDEX}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
