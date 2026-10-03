#!/usr/bin/env python3
"""Resolve Transfermarkt + Wikidata IDs for Egyptian league roster players."""

from __future__ import annotations

import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
LEGENDARY_DIR = BASE.parent / "legendary-players"
sys.path.insert(0, str(LEGENDARY_DIR))

import resolve_transfermarkt_ids as resolver  # noqa: E402

resolver.BASE_DIR = BASE
resolver.INPUT_CSV = BASE / "egyptian_players_combined.csv"
resolver.OUTPUT_WITH_ID = BASE / "egyptian_players_with_tm_id.csv"
resolver.OUTPUT_MANUAL = BASE / "egyptian_players_manual_review.csv"
resolver.CACHE_PATH = BASE / ".wikidata_cache.json"
resolver.PROGRESS_PATH = BASE / ".resolve_progress.json"
resolver.AUDIT_LOG_PATH = BASE / "wikidata_lookup_audit.log"

if __name__ == "__main__":
    resolver.main()
