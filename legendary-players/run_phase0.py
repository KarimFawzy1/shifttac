#!/usr/bin/env python3
"""Phase 0 orchestrator — filter CSV, write reports, verify club mapping, generate league map."""

from __future__ import annotations

import csv
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "legendary-players" / "reports"
CSV_PATH = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
FILTER_SCRIPT = ROOT / "legendary-players" / "filter_allowed_attributes.py"
VERIFY_SCRIPT = ROOT / "legendary-players" / "verify_club_mapping.py"
STRIPPED_NATIONS_DB = ROOT / "legendary-players" / "_check_stripped_nations_in_db.py"
GENERATE_LEAGUE = ROOT / "tool" / "etl" / "scripts" / "generate_club_top5_league.py"
SUPPLEMENTS_YAML = ROOT / "tool" / "etl" / "config" / "legendary_club_supplements.yaml"
QUAL_CHECK = ROOT / "legendary-players" / "_qual_check.json"
STRIPPED_NATIONS = ROOT / "legendary-players" / "reports" / "stripped_nations.json"
PHASE0_SUMMARY = ROOT / "legendary-players" / "reports" / "phase0_summary.json"

# Must NOT appear in filter_allowed_attributes.EXCEPTION_NATIONS (see plan §5).
INTENTIONALLY_STRIPPED_NATIONS: dict[str, str] = {
    "North Macedonia": "Darko Pančev",
    "Iran": "Ali Daei",
    "Georgia": "Kakha Kaladze",
    "Paraguay": "José Luis Chilavert (not in with_tm_id CSV — TM id unresolved)",
    "Zambia": "Kalusha Bwalya (not in with_tm_id CSV — TM id unresolved)",
    "South Africa": "Lucas Radebe (not in with_tm_id CSV — TM id unresolved)",
    "New Zealand": "Wynton Rufer (not in with_tm_id CSV — TM id unresolved)",
}


def parse_clubs(raw: str) -> list[str]:
    return [part.strip() for part in (raw or "").split(",") if part.strip()]


def run_script(path: Path, *extra: str) -> None:
    result = subprocess.run(
        [sys.executable, str(path), *extra],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.stdout:
        print(result.stdout.rstrip())
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.rstrip(), file=sys.stderr)
        raise SystemExit(result.returncode)


def write_qual_check(rows: list[dict[str, str]]) -> dict[str, object]:
    empty_nat = []
    empty_clubs = []
    for row in rows:
        if not (row.get("Nationality") or "").strip():
            empty_nat.append(
                {
                    "name": row["Player Name"],
                    "clubs": row.get("Senior Clubs Played For", ""),
                    "tm": row.get("transfermarkt_id", ""),
                }
            )
        if not parse_clubs(row.get("Senior Clubs Played For", "")):
            empty_clubs.append(
                {
                    "name": row["Player Name"],
                    "nat": row.get("Nationality", ""),
                    "tm": row.get("transfermarkt_id", ""),
                }
            )
    payload = {"empty_nat": empty_nat, "empty_clubs": empty_clubs}
    QUAL_CHECK.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


def write_stripped_nations(rows: list[dict[str, str]]) -> None:
    players_in_csv = []
    for row in rows:
        if not (row.get("Nationality") or "").strip():
            players_in_csv.append(
                {
                    "player_name": row["Player Name"],
                    "transfermarkt_id": row.get("transfermarkt_id", ""),
                    "clubs": parse_clubs(row.get("Senior Clubs Played For", "")),
                }
            )
    payload = {
        "intentionally_stripped_nations": list(INTENTIONALLY_STRIPPED_NATIONS.keys()),
        "policy": "Do not add these nations to nations_allowlist.yaml or EXCEPTION_NATIONS.",
        "players_in_csv_with_blank_nationality": players_in_csv,
        "reference_players_not_in_csv": {
            nation: note
            for nation, note in INTENTIONALLY_STRIPPED_NATIONS.items()
            if "not in with_tm_id CSV" in note
        },
    }
    STRIPPED_NATIONS.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def qualification_preview(rows: list[dict[str, str]]) -> dict[str, object]:
    included = []
    excluded = []
    for row in rows:
        attrs = 0
        if (row.get("Nationality") or "").strip():
            attrs += 1
        clubs = parse_clubs(row.get("Senior Clubs Played For", ""))
        attrs += len(clubs)
        if (row.get("Position") or "").strip():
            attrs += 1
        entry = {
            "player_name": row["Player Name"],
            "transfermarkt_id": row.get("transfermarkt_id", ""),
            "attribute_count_preview": attrs,
        }
        if attrs >= 2:
            included.append(entry)
        else:
            excluded.append(entry)
    return {
        "csv_rows": len(rows),
        "included_preview": len(included),
        "excluded_insufficient_attributes": len(excluded),
        "excluded_players": excluded,
    }


def write_phase0_summary(rows: list[dict[str, str]], qual: dict[str, object]) -> None:
    import yaml

    excluded_yaml = yaml.safe_load(SUPPLEMENTS_YAML.read_text(encoding="utf-8"))
    league_cfg = yaml.safe_load(
        (ROOT / "tool" / "etl" / "config" / "club_top5_league.yaml").read_text(encoding="utf-8")
    )
    no_club_players = excluded_yaml.get("players_without_allowlisted_clubs") or []
    payload = {
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "phase": "0",
        "csv_rows": len(rows),
        "empty_nationality_count": len(
            [r for r in rows if not (r.get("Nationality") or "").strip()]
        ),
        "empty_clubs_count": len(
            [r for r in rows if not parse_clubs(r.get("Senior Clubs Played For", ""))]
        ),
        "qualification_preview": qual,
        "players_without_allowlisted_clubs": no_club_players,
        "top5_club_mappings": len((league_cfg.get("mapping") or {})),
        "acceptance": {
            "stripped_nations_documented": STRIPPED_NATIONS.is_file(),
            "verify_club_mapping_passed": True,
            "stripped_nations_absent_from_db": True,
            "club_top5_league_generated": (
                ROOT / "tool" / "etl" / "config" / "club_top5_league.yaml"
            ).is_file(),
        },
    }
    PHASE0_SUMMARY.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)

    print("=== Phase 0.1: filter CSV ===")
    run_script(FILTER_SCRIPT)

    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
    qual_check = write_qual_check(rows)
    write_stripped_nations(rows)
    print(f"Wrote {QUAL_CHECK} (empty_nat={len(qual_check['empty_nat'])})")
    print(f"Wrote {STRIPPED_NATIONS}")

    print("\n=== Phase 0.3: verify club mapping ===")
    run_script(VERIFY_SCRIPT)

    print("\n=== Phase 0.1b: verify stripped nations absent from DB ===")
    run_script(STRIPPED_NATIONS_DB)

    print("\n=== Phase 0.4: generate club_top5_league.yaml ===")
    run_script(GENERATE_LEAGUE)
    run_script(GENERATE_LEAGUE, "--verify")

    qual = qualification_preview(rows)
    write_phase0_summary(rows, qual)
    print(f"\nWrote {PHASE0_SUMMARY}")
    print(
        f"Preview: {qual['included_preview']} included, "
        f"{qual['excluded_insufficient_attributes']} excluded (<2 attributes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
