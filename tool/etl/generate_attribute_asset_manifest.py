#!/usr/bin/env python3
"""Generate assets/tiki_taka/attrs/manifest.json from the shipped SQLite DB.

Manifest format (flat JSON object):
  { "<icon_key>": "<flutter asset path>", ... }

Mapping strategy (preferred):
  1. Read club/nation/league rows from attributes (position rows are excluded).
  2. Derive SVG filename from display_name: spaces -> hyphens, append .svg.
  3. Resolve under assets/tiki_taka/attrs/{clubs|nations|leagues}/.
  4. Apply optional overrides from tool/etl/config/attribute_asset_overrides.yaml.

Runtime must resolve icons by icon_key via this manifest — not by display_name.
"""

from __future__ import annotations

import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DB_PATH = REPO_ROOT / "assets" / "db" / "tiki_taka.db"
ATTRS_ROOT = REPO_ROOT / "assets" / "tiki_taka" / "attrs"
MANIFEST_PATH = ATTRS_ROOT / "manifest.json"
OVERRIDES_PATH = (
    REPO_ROOT / "tool" / "etl" / "config" / "attribute_asset_overrides.yaml"
)
REPORT_PATH = (
    REPO_ROOT / "tool" / "etl" / "reports" / "generate_attribute_asset_manifest_summary.json"
)

TYPE_SUBDIRS = {
    "club": "clubs",
    "nation": "nations",
    "league": "leagues",
}

IMAGE_TYPES = frozenset(TYPE_SUBDIRS)


def _load_overrides(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    overrides: dict[str, str] = {}
    in_overrides = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line == "overrides:":
            in_overrides = True
            continue
        if not in_overrides or ":" not in line:
            continue

        key, value = line.split(":", 1)
        key = key.strip().strip("'\"")
        value = value.strip().strip("'\"")
        if key and value:
            overrides[key] = value
    return overrides


def display_name_to_filename(display_name: str) -> str:
    return f"{display_name.replace(' ', '-')}.svg"


def default_asset_path(attribute_type: str, display_name: str) -> str:
    subdir = TYPE_SUBDIRS[attribute_type]
    filename = display_name_to_filename(display_name)
    return f"assets/tiki_taka/attrs/{subdir}/{filename}"


def fetch_image_attributes(db_path: Path) -> list[tuple[str, str, str]]:
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(
            """
            SELECT type, display_name, icon_key
            FROM attributes
            WHERE type IN ('club', 'nation', 'league')
            ORDER BY type, display_name
            """
        ).fetchall()
    finally:
        conn.close()
    return [(str(t), str(d), str(k)) for t, d, k in rows]


def build_manifest(
    attributes: list[tuple[str, str, str]],
    overrides: dict[str, str],
) -> dict[str, str]:
    manifest: dict[str, str] = {}
    for attribute_type, display_name, icon_key in attributes:
        if icon_key in overrides:
            asset_path = overrides[icon_key]
        else:
            asset_path = default_asset_path(attribute_type, display_name)

        if icon_key in manifest:
            raise ValueError(f"Duplicate icon_key in DB: {icon_key}")

        disk_path = REPO_ROOT / asset_path
        if not disk_path.is_file():
            raise FileNotFoundError(
                f"Missing SVG for {icon_key} ({display_name}): {asset_path}"
            )

        manifest[icon_key] = asset_path.replace("\\", "/")

    path_counts = Counter(manifest.values())
    duplicates = [path for path, count in path_counts.items() if count > 1]
    if duplicates:
        raise ValueError(f"Multiple icon_keys map to the same asset: {duplicates}")

    return dict(sorted(manifest.items()))


def write_manifest(manifest: dict[str, str], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    path.write_text(payload, encoding="utf-8")


def write_report(
    manifest: dict[str, str],
    attributes: list[tuple[str, str, str]],
    overrides: dict[str, str],
) -> None:
    by_type = Counter(attribute_type for attribute_type, _, _ in attributes)
    report = {
        "manifest_path": str(MANIFEST_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
        "db_path": str(DB_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
        "entry_count": len(manifest),
        "counts_by_type": dict(sorted(by_type.items())),
        "override_count": len(overrides),
        "excluded_types": ["position"],
        "strategy": "display_name slug + optional icon_key overrides",
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    if not DB_PATH.is_file():
        print(f"ERROR: database not found: {DB_PATH}", file=sys.stderr)
        return 1

    overrides = _load_overrides(OVERRIDES_PATH)
    attributes = fetch_image_attributes(DB_PATH)
    manifest = build_manifest(attributes, overrides)
    write_manifest(manifest, MANIFEST_PATH)
    write_report(manifest, attributes, overrides)

    print(f"Wrote {len(manifest)} entries to {MANIFEST_PATH}")
    print(f"Report: {REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
