#!/usr/bin/env python3
"""Recompute search_text in staging CSVs after transliteration rule changes.

Updates:
  staging/normalized/players.csv
  staging/players_table.csv

Then rebuilds player_aliases.csv and tiki_taka.db via D8 + D11 scripts.
"""
from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_transliteration import make_search_text  # noqa: E402

STAGING = _ETL_DIR / "staging"
NORMALIZED_PLAYERS = STAGING / "normalized" / "players.csv"
PLAYERS_TABLE = STAGING / "players_table.csv"


def _refresh_csv(path: Path, id_field: str, display_field: str) -> int:
    if not path.is_file():
        raise FileNotFoundError(f"Missing {path}")

    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError(f"{path}: missing header")
        fieldnames = list(reader.fieldnames)
        rows = list(reader)

    updated = 0
    for row in rows:
        display = (row.get(display_field) or "").strip()
        if not display:
            continue
        new_search_text = make_search_text(display)
        if row.get("search_text") != new_search_text:
            row["search_text"] = new_search_text
            updated += 1

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"  {path.name}: refreshed {updated:,} / {len(rows):,} rows")
    return updated


def main() -> int:
    print("Refreshing search_text in staging CSVs...")
    _refresh_csv(NORMALIZED_PLAYERS, "player_id", "display_name")
    _refresh_csv(PLAYERS_TABLE, "id", "display_name")

    for script in ("build_player_aliases.py", "build_database.py"):
        script_path = _ETL_DIR / script
        print(f"Running {script}...")
        result = subprocess.run(
            [sys.executable, str(script_path)],
            cwd=str(_ETL_DIR),
            check=False,
        )
        if result.returncode != 0:
            print(f"FAILED: {script} exited {result.returncode}", file=sys.stderr)
            return result.returncode

    print("Search index refresh complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
