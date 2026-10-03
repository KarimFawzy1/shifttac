#!/usr/bin/env python3
"""Report clubs and nations in Egyptian player data missing from ETL allowlists."""

from __future__ import annotations

import csv
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

import yaml

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[0]
INPUT_CSV = BASE / "egyptian_players_combined.csv"
CLUBS_YAML = ROOT / "tool" / "etl" / "config" / "clubs_allowlist.yaml"
NATIONS_YAML = ROOT / "tool" / "etl" / "config" / "nations_allowlist.yaml"
EGYPTIAN_ALIASES_YAML = ROOT / "tool" / "etl" / "config" / "egyptian_club_aliases.yaml"
REPORT_DIR = BASE / "reports"

NATION_NORMALIZATION = {
    "morocca": "Morocco",
    "congolese": "DR Congo",
    "gabonese": "Gabon",
    "mauritanian": "Mauritania",
    "south african": "South Africa",
    "liberian": "Liberia",
    "cote d ivoire": "Ivory Coast",
    "côte d’ivoire": "Ivory Coast",
    "côte d'ivoire": "Ivory Coast",
}

# Inline global aliases mirrored from legendary filter script.
GLOBAL_CLUB_ALIASES = {
    "Nantes": "FC Nantes",
    "Basel": "FC Basel",
    "Al-Shabab": "Al Shabab",
    "Koln": "FC Köln",
    "Paris Saint-Germain": "Paris Saint Germain",
    "Al-Nassr": "Al Nassr",
    "Al-Hilal": "Al Hilal",
    "Al-Ahli": "Al Ahli",
    "Al-Ittihad": "Al Ittihad",
    "Ittihad": "Al Ittihad",
    "PSV": "PSV Eindhoven",
    "Köln": "FC Köln",
    "Wolfsburg": "VfL Wolfsburg",
    "Stuttgart": "VfB Stuttgart",
    "Deportivo La Coruna": "Deportivo La Coruña",
    "Mainz 05": "Mainz 05",
}


def normalize_text(value: str) -> str:
    value = (value or "").strip()
    value = value.replace("\u00a0", " ")
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = re.sub(r"[^a-zA-Z0-9\s'/&-]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def parse_clubs(raw: str) -> list[str]:
    return [part.strip() for part in re.split(r"[,;]", raw or "") if part.strip()]


def load_yaml_map(path: Path, key: str) -> dict[str, str]:
    cfg = yaml.safe_load(path.read_text(encoding="utf-8"))
    return {str(k): str(v) for k, v in (cfg.get(key) or {}).items()}


def load_club_aliases() -> dict[str, str]:
    aliases = dict(GLOBAL_CLUB_ALIASES)
    if EGYPTIAN_ALIASES_YAML.is_file():
        cfg = yaml.safe_load(EGYPTIAN_ALIASES_YAML.read_text(encoding="utf-8"))
        aliases.update({str(k): str(v) for k, v in (cfg.get("aliases") or {}).items()})
    return aliases


def resolve_club_name(name: str, allowed: set[str], aliases: dict[str, str]) -> str | None:
    if name in allowed:
        return name
    canonical = aliases.get(name, name)
    if canonical in allowed:
        return canonical
    return None


def normalize_nation(value: str) -> str:
    key = normalize_text(value).lower()
    return NATION_NORMALIZATION.get(key, normalize_text(value))


def main() -> None:
    if not INPUT_CSV.is_file():
        raise SystemExit(f"Run merge_egyptian_sources.py first — missing {INPUT_CSV}")

    allowed_clubs = set(load_yaml_map(CLUBS_YAML, "clubs").keys())
    allowed_nations = set(load_yaml_map(NATIONS_YAML, "nations").keys())
    aliases = load_club_aliases()

    club_mentions: Counter[str] = Counter()
    nation_players: Counter[str] = Counter()
    missing_clubs: Counter[str] = Counter()
    missing_nations: Counter[str] = Counter()
    matched_clubs: Counter[str] = Counter()

    with INPUT_CSV.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            nationality = normalize_nation(row.get("Nationality") or "")
            if nationality:
                nation_players[nationality] += 1
                if nationality not in allowed_nations:
                    missing_nations[nationality] += 1

            for club in parse_clubs(row.get("Senior Clubs Played For", "")):
                if club.lower() in {"egypt nt pool", "hussein hegazi"}:
                    continue
                club_mentions[club] += 1
                if resolve_club_name(club, allowed_clubs, aliases):
                    matched_clubs[club] += 1
                else:
                    missing_clubs[club] += 1

    missing_club_report = [
        {"club": club, "player_mentions": count}
        for club, count in missing_clubs.most_common()
    ]
    missing_nation_report = [
        {"nation": nation, "players": count}
        for nation, count in missing_nations.most_common()
    ]

    summary = {
        "players_analyzed": sum(1 for _ in open(INPUT_CSV, encoding="utf-8")) - 1,
        "unique_club_strings": len(club_mentions),
        "missing_club_strings": len(missing_clubs),
        "missing_club_mentions": sum(missing_clubs.values()),
        "matched_club_mentions": sum(matched_clubs.values()),
        "unique_nationalities": len(nation_players),
        "missing_nationalities": len(missing_nations),
        "already_allowed_nationalities": sorted(
            nation for nation in nation_players if nation in allowed_nations
        ),
    }

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / "gap_clubs.json").write_text(
        json.dumps(
            {"summary": summary, "missing_clubs": missing_club_report},
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (REPORT_DIR / "gap_nations.json").write_text(
        json.dumps(
            {"summary": summary, "missing_nations": missing_nation_report},
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Gap analysis complete ({summary['players_analyzed']} players)")
    print(f"  missing club strings: {summary['missing_club_strings']}")
    print(f"  missing nationalities: {summary['missing_nationalities']}")
    print(f"  reports: {REPORT_DIR}")


if __name__ == "__main__":
    main()
