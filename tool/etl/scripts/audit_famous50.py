#!/usr/bin/env python3
"""Audit famous-50 allowlisted club coverage in tiki_taka.db."""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from famous50_careers import FAMOUS_50_CAREERS  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
DB = REPO / "assets" / "db" / "tiki_taka.db"


def main() -> int:
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    missing_clubs: list[tuple[str, str, list[str], set[str]]] = []
    not_in_db: list[tuple[str, list[str]]] = []
    complete: list[str] = []

    for pid, clubs in FAMOUS_50_CAREERS.items():
        cur.execute("SELECT display_name FROM players WHERE id = ?", (f"tm:{pid}",))
        row = cur.fetchone()
        if not row:
            not_in_db.append((pid, clubs))
            continue
        name = row[0]
        cur.execute(
            """
            SELECT DISTINCT attribute_id
            FROM player_attributes
            WHERE player_id = ? AND attribute_id LIKE 'club:%'
            """,
            (f"tm:{pid}",),
        )
        have = {r[0].split(":", 1)[1] for r in cur.fetchall()}
        need = [c for c in clubs if c not in have]
        if need:
            missing_clubs.append((pid, name, need, have))
        else:
            complete.append(name)

    print(f"NOT IN DB ({len(not_in_db)}):")
    for pid, clubs in not_in_db:
        print(f"  tm:{pid} — {len(clubs)} allowlisted clubs expected")

    print(f"\nMISSING CLUBS ({len(missing_clubs)}):")
    for pid, name, need, have in missing_clubs:
        print(f"  {name} (tm:{pid})")
        print(f"    missing: {need}")
        print(f"    has:     {sorted(have)}")

    print(f"\nCOMPLETE ({len(complete)}):")
    for name in sorted(complete):
        print(f"  {name}")

    print("\nTM ID checks:")
    for zid in ("3455", "22138"):
        cur.execute("SELECT id, display_name FROM players WHERE id = ?", (f"tm:{zid}",))
        print(f"  tm:{zid} -> {cur.fetchone()}")

    conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
