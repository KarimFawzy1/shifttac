#!/usr/bin/env python3
"""Verify Python make_search_text matches expected values for all DB players."""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
ROOT = _ETL_DIR.parents[1]
DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"

if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_transliteration import make_search_text  # noqa: E402


def main() -> int:
    if not DB_PATH.is_file():
        print(f"Missing DB: {DB_PATH}", file=sys.stderr)
        return 1

    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        "SELECT id, display_name, search_text FROM players"
    ).fetchall()
    conn.close()

    mismatches: list[tuple[str, str, str, str]] = []
    for player_id, display, stored in rows:
        expected = make_search_text(display)
        if stored != expected:
            mismatches.append((player_id, display, stored, expected))

    if mismatches:
        print(f"FAILED: {len(mismatches)} players with stale search_text")
        for player_id, display, stored, expected in mismatches[:20]:
            print(f"  {player_id} {display!r}")
            print(f"    stored={stored!r} expected={expected!r}")
        return 1

    print(f"OK: {len(rows):,} players — search_text matches make_search_text")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
