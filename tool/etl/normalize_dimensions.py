#!/usr/bin/env python3
"""Phase D2 — normalize dimension tables for downstream merges.

Reads D1 output from tool/etl/staging/, applies allowlists and canonical strings,
writes tool/etl/staging/normalized/ and reports:

  tool/etl/reports/normalize_summary.json
  tool/etl/reports/unmapped_nations.csv

Exit 1 when D1 staging is missing or allowlisted club/nation lookup fails.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import (  # noqa: E402
    NationResolver,
    REPORTS,
    STAGING_NORM,
    STAGING_RAW,
    collapse_whitespace,
    load_yaml,
    make_search_text,
    normalize_player_name,
)

D1_FILES = (
    "players.csv",
    "clubs.csv",
    "competitions.csv",
    "countries.csv",
    "transfers.csv",
    "appearances.csv",
    "national_teams.csv",
)

SUMMARY_PATH = REPORTS / "normalize_summary.json"
UNMAPPED_NATIONS_PATH = REPORTS / "unmapped_nations.csv"


def require_d1_staging() -> list[str]:
    return [name for name in D1_FILES if not (STAGING_RAW / name).is_file()]


def load_allowlisted_club_ids() -> dict[str, str]:
    cfg = load_yaml("clubs_allowlist.yaml")
    clubs = cfg.get("clubs") or {}
    return {str(club_id): display for display, club_id in clubs.items()}


def load_top5_competition_ids() -> set[str]:
    cfg = load_yaml("leagues_allowlist.yaml")
    leagues = cfg.get("leagues") or {}
    return {str(comp_id).upper() for comp_id in leagues.values()}


def normalize_clubs(allowlisted_ids: set[str]) -> tuple[int, list[str]]:
    source = STAGING_RAW / "clubs.csv"
    dest = STAGING_NORM / "clubs.csv"
    errors: list[str] = []
    rows_written = 0
    found_ids: set[str] = set()

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError("clubs.csv: missing header")
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            club_id = (row.get("club_id") or "").strip()
            if club_id not in allowlisted_ids:
                continue
            name = normalize_player_name(row.get("name") or "")
            out_row = dict(row)
            out_row["name"] = name
            writer.writerow(out_row)
            rows_written += 1
            found_ids.add(club_id)

    missing = sorted(allowlisted_ids - found_ids)
    for club_id in missing:
        errors.append(f"allowlisted club_id {club_id} not found in staging clubs.csv")

    return rows_written, errors


def normalize_competitions(top5_ids: set[str]) -> int:
    source = STAGING_RAW / "competitions.csv"
    dest = STAGING_NORM / "competitions.csv"
    rows_written = 0

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError("competitions.csv: missing header")
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            comp_id = (row.get("competition_id") or "").strip().upper()
            if comp_id not in top5_ids:
                continue
            out_row = dict(row)
            out_row["competition_id"] = comp_id
            if out_row.get("domestic_league_code"):
                out_row["domestic_league_code"] = out_row["domestic_league_code"].upper()
            writer.writerow(out_row)
            rows_written += 1

    return rows_written


def normalize_players(resolver: NationResolver) -> tuple[int, Counter[str]]:
    source = STAGING_RAW / "players.csv"
    dest = STAGING_NORM / "players.csv"
    unmapped = Counter()
    rows_written = 0

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError("players.csv: missing header")

        fieldnames = list(reader.fieldnames)
        for col in ("display_name", "search_text", "nation_slug"):
            if col not in fieldnames:
                fieldnames.append(col)

        writer = csv.DictWriter(out, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()

        for row in reader:
            display = normalize_player_name(row.get("name") or "")
            citizenship = row.get("country_of_citizenship") or ""
            nation_slug = resolver.resolve(citizenship)

            if collapse_whitespace(citizenship) and not nation_slug:
                unmapped[collapse_whitespace(citizenship)] += 1

            out_row = dict(row)
            out_row["name"] = display
            out_row["display_name"] = display
            out_row["search_text"] = make_search_text(display)
            out_row["nation_slug"] = nation_slug
            writer.writerow(out_row)
            rows_written += 1

    return rows_written, unmapped


def normalize_transfers(allowlisted_club_ids: set[str]) -> int:
    source = STAGING_RAW / "transfers.csv"
    dest = STAGING_NORM / "transfers.csv"
    rows_written = 0

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError("transfers.csv: missing header")
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            out_row = dict(row)
            for col in ("from_club_id", "to_club_id"):
                cid = (out_row.get(col) or "").strip()
                if cid and cid not in allowlisted_club_ids:
                    out_row[col] = ""
            writer.writerow(out_row)
            rows_written += 1

    return rows_written


def normalize_appearances(
    allowlisted_club_ids: set[str], top5_ids: set[str]
) -> tuple[int, int]:
    source = STAGING_RAW / "appearances.csv"
    dest = STAGING_NORM / "appearances.csv"
    rows_read = 0
    rows_written = 0

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError("appearances.csv: missing header")
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            rows_read += 1
            comp_id = (row.get("competition_id") or "").strip().upper()
            club_id = (row.get("player_club_id") or "").strip()
            in_top5 = comp_id in top5_ids
            in_allowlist = club_id in allowlisted_club_ids
            if not in_top5 and not in_allowlist:
                continue

            out_row = dict(row)
            out_row["competition_id"] = comp_id
            writer.writerow(out_row)
            rows_written += 1

    return rows_read, rows_written


def passthrough_copy(filename: str) -> int:
    source = STAGING_RAW / filename
    dest = STAGING_NORM / filename
    rows_written = 0
    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError(f"{filename}: missing header")
        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()
        for row in reader:
            writer.writerow(row)
            rows_written += 1
    return rows_written


def write_unmapped_nations(unmapped: Counter[str]) -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    with UNMAPPED_NATIONS_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["citizenship_raw", "player_count"])
        for citizenship, count in unmapped.most_common():
            writer.writerow([citizenship, count])
    return len(unmapped)


def validate_nation_allowlist(resolver: NationResolver) -> list[str]:
    nations_cfg = load_yaml("nations_allowlist.yaml").get("nations") or {}
    aliases_cfg = load_yaml("name_aliases.yaml").get("nations") or {}
    errors: list[str] = []

    for display, slug in nations_cfg.items():
        resolved = resolver.resolve(display)
        if resolved != slug:
            errors.append(
                f"nation allowlist '{display}' → expected {slug}, resolved {resolved!r}"
            )

    if resolver.resolve("Cote d'Ivoire") != "ivory_coast":
        errors.append("alias Cote d'Ivoire → ivory_coast failed")
    if resolver.resolve("USA") != "united_states":
        errors.append("alias USA → united_states failed")

    for raw, slug in aliases_cfg.items():
        if slug not in resolver.allowed_slugs:
            errors.append(f"alias target slug not in allowlist: {raw} → {slug}")

    return errors


def main() -> int:
    missing = require_d1_staging()
    if missing:
        print("D2 normalize FAILED: run D1 ingest first; missing:", file=sys.stderr)
        for name in missing:
            print(f"  - {STAGING_RAW / name}", file=sys.stderr)
        return 1

    STAGING_NORM.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)

    nations_cfg = load_yaml("nations_allowlist.yaml").get("nations") or {}
    aliases_cfg = load_yaml("name_aliases.yaml").get("nations") or {}
    resolver = NationResolver(nations_cfg, aliases_cfg)

    allowlisted_club_ids = set(load_allowlisted_club_ids())
    top5_ids = load_top5_competition_ids()

    errors = validate_nation_allowlist(resolver)

    club_rows, club_errors = normalize_clubs(allowlisted_club_ids)
    errors.extend(club_errors)

    comp_rows = normalize_competitions(top5_ids)
    player_rows, unmapped = normalize_players(resolver)
    transfer_rows = normalize_transfers(allowlisted_club_ids)
    app_read, app_written = normalize_appearances(allowlisted_club_ids, top5_ids)
    countries_rows = passthrough_copy("countries.csv")
    national_rows = passthrough_copy("national_teams.csv")

    unmapped_distinct = write_unmapped_nations(unmapped)

    if errors:
        print("D2 normalize FAILED: allowlist lookup errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    summary = {
        "phase": "D2",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "input_dir": str(STAGING_RAW),
        "output_dir": str(STAGING_NORM),
        "allowlisted_clubs": len(allowlisted_club_ids),
        "top5_competitions": sorted(top5_ids),
        "files": {
            "clubs.csv": {"rows_written": club_rows},
            "competitions.csv": {"rows_written": comp_rows},
            "players.csv": {
                "rows_written": player_rows,
                "unmapped_citizenship_distinct": unmapped_distinct,
                "unmapped_citizenship_rows": sum(unmapped.values()),
            },
            "transfers.csv": {"rows_written": transfer_rows},
            "appearances.csv": {
                "rows_read": app_read,
                "rows_written": app_written,
            },
            "countries.csv": {"rows_written": countries_rows},
            "national_teams.csv": {"rows_written": national_rows},
        },
    }

    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    print(
        "D2 normalize OK: "
        f"{club_rows} clubs, {comp_rows} competitions, {player_rows:,} players, "
        f"{app_written:,}/{app_read:,} appearances kept, "
        f"{unmapped_distinct} unmapped citizenship values"
    )
    print(f"  report: {SUMMARY_PATH}")
    print(f"  unmapped nations: {UNMAPPED_NATIONS_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
