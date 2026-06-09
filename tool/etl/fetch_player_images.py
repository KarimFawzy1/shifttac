#!/usr/bin/env python3
"""Phase D7b — resolve player image URLs from Wikidata (P2446 → P18 → Commons).

Stub in Phase P1; full implementation in Phase P2.
See docs/player-image-plan.md.

Inputs:
  tool/etl/staging/players_table.csv

Outputs (P2+):
  tool/etl/staging/player_images.csv
  tool/etl/reports/fetch_player_images_summary.json

Usage (P2+):
  python tool/etl/fetch_player_images.py
  python tool/etl/fetch_player_images.py --only-missing
  python tool/etl/fetch_player_images.py --limit 100
  python tool/etl/fetch_player_images.py --verify-urls
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
STAGING = _ETL_DIR / "staging"
PLAYERS_TABLE_PATH = STAGING / "players_table.csv"
PLAYER_IMAGES_PATH = STAGING / "player_images.csv"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve Wikidata P2446/P18 Commons thumbnail URLs for Tiki-Taka players."
        ),
    )
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="Resolve only players not already present in player_images.csv.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help="Dev: process only the first N players from players_table.csv.",
    )
    parser.add_argument(
        "--verify-urls",
        action="store_true",
        help="HEAD/GET each Commons URL and skip 404 / non-image responses.",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Re-fetch URLs (full pass unless combined with --only-missing).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _ = args  # used in Phase P2

    print(
        "fetch_player_images.py is not implemented yet (Phase P2).\n"
        f"  expected input:  {PLAYERS_TABLE_PATH}\n"
        f"  expected output: {PLAYER_IMAGES_PATH}\n"
        "  see docs/player-image-plan.md",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
