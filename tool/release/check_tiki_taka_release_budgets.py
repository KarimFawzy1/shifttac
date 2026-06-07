#!/usr/bin/env python3
"""Phase T12 release budget checks for bundled Tiki-Taka assets."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"
ATTRS_DIR = ROOT / "assets" / "tiki_taka" / "attrs"
REPORT_PATH = ROOT / "tool" / "release" / "reports" / "tiki_taka_release_budgets.json"

MAX_DB_BYTES = 20 * 1024 * 1024
MAX_SVG_BYTES = 8 * 1024 * 1024


def _dir_size_bytes(path: Path, pattern: str) -> tuple[int, int]:
    files = list(path.rglob(pattern))
    total = sum(file.stat().st_size for file in files)
    return len(files), total


def main() -> int:
    if not DB_PATH.is_file():
        print(f"Missing bundled database: {DB_PATH}", file=sys.stderr)
        return 1

    db_bytes = DB_PATH.stat().st_size
    svg_count, svg_bytes = _dir_size_bytes(ATTRS_DIR, "*.svg")

    manifest_path = ATTRS_DIR / "manifest.json"
    manifest_bytes = manifest_path.stat().st_size if manifest_path.is_file() else 0

    report = {
        "database": {
            "path": str(DB_PATH.relative_to(ROOT)).replace("\\", "/"),
            "bytes": db_bytes,
            "max_bytes": MAX_DB_BYTES,
            "within_budget": db_bytes <= MAX_DB_BYTES,
        },
        "attribute_svgs": {
            "count": svg_count,
            "bytes": svg_bytes,
            "max_bytes": MAX_SVG_BYTES,
            "within_budget": svg_bytes <= MAX_SVG_BYTES,
        },
        "manifest_json_bytes": manifest_bytes,
        "offline": True,
        "notes": [
            "Tiki-Taka v1 uses bundled SQLite and SVG assets only; no runtime network.",
            "SQLite runtime deps: sqflite, path, path_provider, shared_preferences.",
        ],
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(
        "Tiki-Taka release budgets: "
        f"db={db_bytes / (1024 * 1024):.2f} MB / {MAX_DB_BYTES / (1024 * 1024):.0f} MB, "
        f"svgs={svg_count} files {svg_bytes / (1024 * 1024):.2f} MB / "
        f"{MAX_SVG_BYTES / (1024 * 1024):.0f} MB"
    )
    print(f"  report: {REPORT_PATH}")

    if not report["database"]["within_budget"]:
        print("FAIL: bundled database exceeds size budget", file=sys.stderr)
        return 1
    if not report["attribute_svgs"]["within_budget"]:
        print("FAIL: attribute SVG bundle exceeds size budget", file=sys.stderr)
        return 1

    print("OK: all Tiki-Taka release budgets within limits")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
