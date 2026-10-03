#!/usr/bin/env python3
"""Generate egyptian_search_rank_boost.yaml from combined CSV (requires transfermarkt_id)."""

from __future__ import annotations

import csv
from pathlib import Path

import yaml

BASE = Path(__file__).resolve().parent
INPUT_CSV = BASE / "egyptian_players_combined.csv"
OUTPUT_YAML = BASE.parent / "tool" / "etl" / "config" / "egyptian_search_rank_boost.yaml"

# Popularity score 43–100 → EUR-equivalent search rank boost (Salah/legends ≈ 120M).
SCORE_MULTIPLIER = 1_200_000


def main() -> None:
    if not INPUT_CSV.is_file():
        raise SystemExit(f"Missing {INPUT_CSV}")

    players: dict[str, int] = {}
    skipped = 0
    with INPUT_CSV.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            tm_id = (row.get("transfermarkt_id") or "").strip().removeprefix("tm:")
            score_raw = (row.get("Popularity Score") or "").strip()
            if not tm_id or not score_raw:
                skipped += 1
                continue
            try:
                boost = int(float(score_raw)) * SCORE_MULTIPLIER
            except ValueError:
                skipped += 1
                continue
            players[tm_id] = max(players.get(tm_id, 0), boost)

    OUTPUT_YAML.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": "1",
        "description": "Popularity-based search_rank boost for Egyptian league roster players.",
        "players": dict(sorted(players.items(), key=lambda item: -item[1])),
    }
    OUTPUT_YAML.write_text(
        yaml.safe_dump(payload, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    print(f"Wrote {OUTPUT_YAML} ({len(players)} boosts, skipped {skipped} rows without tm_id)")


if __name__ == "__main__":
    main()
