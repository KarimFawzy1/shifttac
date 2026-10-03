#!/usr/bin/env python3
"""Audit DB search_text against unified transliteration rules."""
from __future__ import annotations

import sqlite3
import sys
from collections import Counter
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_transliteration import make_search_text  # noqa: E402

ROOT = _ETL_DIR.parents[1]
DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"


def safe_print(text: str) -> None:
    sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))


def main() -> int:
    if not DB_PATH.is_file():
        safe_print(f"Missing DB: {DB_PATH}")
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

    safe_print(
        f"Players checked: {len(rows):,}; search_text mismatches: {len(mismatches):,}"
    )

    if not mismatches:
        safe_print("OK — all search_text values match make_search_text(display_name)")
        return 0

    special_chars = Counter()
    for _pid, display, _stored, _expected in mismatches:
        for ch in display:
            if ord(ch) > 127:
                special_chars[ch] += 1

    safe_print("Mismatching special characters:")
    for ch, count in special_chars.most_common(20):
        safe_print(f"  U+{ord(ch):04X}: {count}")

    for player_id, display, stored, expected in mismatches[:15]:
        safe_print(f"  {player_id} {display}")
        safe_print(f"    stored={stored!r} expected={expected!r}")

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
