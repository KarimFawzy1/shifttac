#!/usr/bin/env python3
"""Validate Tiki-Taka attribute SVG coverage against the shipped DB and manifest.

Checks:
  - every club, nation, and league row in attributes has a manifest entry,
  - every manifest entry resolves to an existing bundled SVG file,
  - position attributes are excluded from the manifest.

Writes: tool/etl/reports/validate_attribute_assets_summary.json
Exit 0 on pass, 1 on failure.
"""

from __future__ import annotations

import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / "assets" / "db" / "tiki_taka.db"
MANIFEST_PATH = REPO_ROOT / "assets" / "tiki_taka" / "attrs" / "manifest.json"
REPORT_PATH = (
    REPO_ROOT / "tool" / "etl" / "reports" / "validate_attribute_assets_summary.json"
)

IMAGE_TYPES = ("club", "nation", "league")
POSITION_ICON_PREFIX = "pos_"


def fetch_image_attributes(db_path: Path) -> list[dict[str, str]]:
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(
            """
            SELECT id, type, display_name, icon_key
            FROM attributes
            WHERE type IN ('club', 'nation', 'league')
            ORDER BY type, display_name
            """
        ).fetchall()
    finally:
        conn.close()

    return [
        {
            "id": str(attribute_id),
            "type": str(attribute_type),
            "display_name": str(display_name),
            "icon_key": str(icon_key),
        }
        for attribute_id, attribute_type, display_name, icon_key in rows
    ]


def load_manifest(path: Path) -> dict[str, str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Manifest must be a JSON object: {path}")
    return {str(key): str(value) for key, value in payload.items()}


def validate_assets(
    db_path: Path = DB_PATH,
    manifest_path: Path = MANIFEST_PATH,
    repo_root: Path = REPO_ROOT,
) -> tuple[bool, dict[str, object]]:
    errors: list[str] = []
    missing_manifest_entries: list[dict[str, str]] = []
    missing_files: list[dict[str, str]] = []
    missing_file_keys: set[tuple[str, str]] = set()
    orphan_manifest_entries: list[str] = []
    unexpected_position_entries: list[str] = []

    if not db_path.is_file():
        errors.append(f"database not found: {db_path}")
    if not manifest_path.is_file():
        errors.append(f"manifest not found: {manifest_path}")

    attributes: list[dict[str, str]] = []
    manifest: dict[str, str] = {}
    if not errors:
        attributes = fetch_image_attributes(db_path)
        manifest = load_manifest(manifest_path)

        expected_icon_keys = {row["icon_key"] for row in attributes}
        manifest_icon_keys = set(manifest)

        for icon_key, asset_path in sorted(manifest.items()):
            if icon_key.startswith(POSITION_ICON_PREFIX):
                unexpected_position_entries.append(icon_key)
                continue
            if icon_key not in expected_icon_keys:
                orphan_manifest_entries.append(icon_key)
                continue

            disk_path = repo_root / asset_path
            if not disk_path.is_file():
                key = (icon_key, asset_path)
                if key not in missing_file_keys:
                    missing_file_keys.add(key)
                    missing_files.append(
                        {
                            "icon_key": icon_key,
                            "asset_path": asset_path,
                            "reason": "file_not_found",
                        }
                    )

        for row in attributes:
            icon_key = row["icon_key"]
            asset_path = manifest.get(icon_key)
            if asset_path is None:
                missing_manifest_entries.append(row)
                continue

            disk_path = repo_root / asset_path
            if not disk_path.is_file():
                key = (icon_key, asset_path)
                if key not in missing_file_keys:
                    missing_file_keys.add(key)
                    missing_files.append(
                        {
                            "icon_key": icon_key,
                            "asset_path": asset_path,
                            "attribute_id": row["id"],
                            "display_name": row["display_name"],
                            "reason": "file_not_found",
                        }
                    )

    if missing_manifest_entries:
        errors.append(
            f"{len(missing_manifest_entries)} attribute(s) missing manifest entries"
        )
    if missing_files:
        errors.append(f"{len(missing_files)} manifest path(s) missing bundled SVG files")
    if orphan_manifest_entries:
        errors.append(
            f"{len(orphan_manifest_entries)} manifest entry(ies) not present in DB"
        )
    if unexpected_position_entries:
        errors.append(
            f"{len(unexpected_position_entries)} position icon_key(s) found in manifest"
        )

    counts_by_type = Counter(row["type"] for row in attributes)
    passed = not errors

    report: dict[str, object] = {
        "status": "pass" if passed else "fail",
        "db_path": str(db_path.relative_to(repo_root)).replace("\\", "/"),
        "manifest_path": str(manifest_path.relative_to(repo_root)).replace("\\", "/"),
        "report_path": str(REPORT_PATH.relative_to(repo_root)).replace("\\", "/"),
        "expected_count": len(attributes),
        "manifest_count": len(manifest),
        "counts_by_type": dict(sorted(counts_by_type.items())),
        "excluded_types": ["position"],
        "missing_manifest_entries": missing_manifest_entries,
        "missing_files": missing_files,
        "orphan_manifest_entries": orphan_manifest_entries,
        "unexpected_position_manifest_entries": unexpected_position_entries,
        "errors": errors,
    }
    return passed, report


def write_report(report: dict[str, object]) -> None:
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    passed, report = validate_assets()
    write_report(report)

    if passed:
        print(
            "G3 asset validation OK: "
            f"{report['expected_count']} attributes, "
            f"{report['manifest_count']} manifest entries"
        )
        print(f"  report: {REPORT_PATH}")
        return 0

    print("G3 asset validation FAILED:", file=sys.stderr)
    for error in report["errors"]:
        print(f"  - {error}", file=sys.stderr)
    print(f"  report: {REPORT_PATH}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
