#!/usr/bin/env python3
"""Phase D1 — raw CSV ingest and sanity checks.

Loads transfermarkt-datasets/*.csv, normalizes date fields to ISO dates,
drops rows with missing required IDs, flags future transfer dates, and writes:

  tool/etl/staging/<file>.csv   cleaned rows for downstream ETL
  tool/etl/reports/ingest_summary.json

Exit 1 if any required source CSV is missing.
"""
from __future__ import annotations

import csv
import json
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Iterable

ROOT = Path(__file__).resolve().parents[2]
DATASETS = ROOT / "transfermarkt-datasets"
STAGING = Path(__file__).resolve().parent / "staging"
REPORTS = Path(__file__).resolve().parent / "reports"
SUMMARY_PATH = REPORTS / "ingest_summary.json"

REQUIRED_FILES = (
    "players.csv",
    "clubs.csv",
    "competitions.csv",
    "countries.csv",
    "transfers.csv",
    "appearances.csv",
    "national_teams.csv",
)

FUTURE_DATE_GRACE_DAYS = 365


@dataclass
class FileStats:
    rows_read: int = 0
    rows_written: int = 0
    rows_dropped_null_id: int = 0
    date_anomalies: int = 0
    date_parse_failures: int = 0

    def to_dict(self) -> dict:
        return {
            "rows_read": self.rows_read,
            "rows_written": self.rows_written,
            "rows_dropped_null_id": self.rows_dropped_null_id,
            "date_anomalies": self.date_anomalies,
            "date_parse_failures": self.date_parse_failures,
        }


@dataclass
class IngestSpec:
    required_id_columns: list[str]
    date_columns: list[str] = field(default_factory=list)
    date_anomaly_columns: list[str] = field(default_factory=list)
    row_valid: Callable[[dict[str, str]], bool] | None = None


INGEST_SPECS: dict[str, IngestSpec] = {
    "players.csv": IngestSpec(
        required_id_columns=["player_id"],
        date_columns=["date_of_birth"],
    ),
    "clubs.csv": IngestSpec(
        required_id_columns=["club_id"],
    ),
    "competitions.csv": IngestSpec(
        required_id_columns=["competition_id"],
    ),
    "countries.csv": IngestSpec(
        required_id_columns=["country_id"],
    ),
    "transfers.csv": IngestSpec(
        required_id_columns=["player_id"],
        date_columns=["transfer_date"],
        date_anomaly_columns=["transfer_date"],
        row_valid=lambda row: bool(_clean(row.get("from_club_id")) or _clean(row.get("to_club_id"))),
    ),
    "appearances.csv": IngestSpec(
        required_id_columns=["player_id", "player_club_id"],
        date_columns=["date"],
    ),
    "national_teams.csv": IngestSpec(
        required_id_columns=["national_team_id"],
    ),
}


def _clean(value: str | None) -> str:
    return (value or "").strip()


def parse_iso_date(raw: str | None) -> tuple[str, date | None]:
    """Return (normalized ISO date string, parsed date) for CSV fields."""
    text = _clean(raw)
    if not text:
        return "", None
    token = text.split()[0]
    try:
        parsed = date.fromisoformat(token)
    except ValueError:
        return text, None
    return parsed.isoformat(), parsed


def missing_required_ids(row: dict[str, str], columns: Iterable[str]) -> bool:
    return any(not _clean(row.get(col)) for col in columns)


def process_file(
    filename: str,
    spec: IngestSpec,
    source: Path,
    dest: Path,
    anomaly_cutoff: date,
) -> FileStats:
    stats = FileStats()
    dest.parent.mkdir(parents=True, exist_ok=True)

    with source.open(encoding="utf-8", newline="") as src, dest.open(
        "w", encoding="utf-8", newline=""
    ) as out:
        reader = csv.DictReader(src)
        if reader.fieldnames is None:
            raise ValueError(f"{filename}: empty or headerless CSV")

        writer = csv.DictWriter(out, fieldnames=reader.fieldnames)
        writer.writeheader()

        for row in reader:
            stats.rows_read += 1
            out_row = dict(row)

            if missing_required_ids(row, spec.required_id_columns):
                stats.rows_dropped_null_id += 1
                continue

            if spec.row_valid is not None and not spec.row_valid(row):
                stats.rows_dropped_null_id += 1
                continue

            reject_row = False
            for col in spec.date_columns:
                if col not in row:
                    continue
                iso_value, parsed = parse_iso_date(row.get(col))
                if row.get(col) and parsed is None:
                    stats.date_parse_failures += 1
                out_row[col] = iso_value
                if col in spec.date_anomaly_columns and parsed is not None:
                    if parsed > anomaly_cutoff:
                        stats.date_anomalies += 1
                        reject_row = True
                        break

            if reject_row:
                continue

            writer.writerow(out_row)
            stats.rows_written += 1

    return stats


def check_required_files() -> list[str]:
    missing = []
    for name in REQUIRED_FILES:
        if not (DATASETS / name).is_file():
            missing.append(name)
    return missing


def main() -> int:
    missing = check_required_files()
    if missing:
        print("D1 ingest FAILED: missing required CSV(s):", file=sys.stderr)
        for name in missing:
            print(f"  - {DATASETS / name}", file=sys.stderr)
        return 1

    if not DATASETS.is_dir():
        print(f"D1 ingest FAILED: datasets directory not found: {DATASETS}", file=sys.stderr)
        return 1

    STAGING.mkdir(parents=True, exist_ok=True)
    REPORTS.mkdir(parents=True, exist_ok=True)

    built_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    anomaly_cutoff = date.today() + timedelta(days=FUTURE_DATE_GRACE_DAYS)

    file_stats: dict[str, dict] = {}
    totals = {
        "rows_read": 0,
        "rows_written": 0,
        "rows_dropped_null_id": 0,
        "date_anomalies": 0,
        "date_parse_failures": 0,
    }

    for filename in REQUIRED_FILES:
        spec = INGEST_SPECS[filename]
        stats = process_file(
            filename,
            spec,
            DATASETS / filename,
            STAGING / filename,
            anomaly_cutoff,
        )
        file_stats[filename] = stats.to_dict()
        for key in totals:
            totals[key] += getattr(stats, key)

    summary = {
        "phase": "D1",
        "built_at": built_at,
        "source_dir": str(DATASETS),
        "staging_dir": str(STAGING),
        "date_anomaly_cutoff": anomaly_cutoff.isoformat(),
        "files": file_stats,
        "totals": totals,
    }

    with SUMMARY_PATH.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    print(
        "D1 ingest OK: "
        f"{totals['rows_written']:,} rows written, "
        f"{totals['rows_dropped_null_id']:,} dropped (null id), "
        f"{totals['date_anomalies']:,} transfer date anomalies"
    )
    print(f"  report: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
