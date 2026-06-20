"""Unit tests for search_rank computation."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_rank import compute_search_rank, load_search_rank_boosts  # noqa: E402


class SearchRankTests(unittest.TestCase):
    def test_uses_peak_market_value(self) -> None:
        rank = compute_search_rank("15000000", "180000000")
        self.assertEqual(rank, 180000000)

    def test_manual_boost_adds_on_top(self) -> None:
        rank = compute_search_rank("0", "0", manual_boost=80_000_000)
        self.assertEqual(rank, 80_000_000)

    def test_famous_players_from_tm_snapshot(self) -> None:
        messi = compute_search_rank("15000000", "180000000")
        ronaldo = compute_search_rank("12000000", "120000000")
        vinicius = compute_search_rank("150000000", "200000000")
        self.assertGreater(vinicius, messi)
        self.assertGreater(messi, ronaldo)

    def test_legendary_boosts_loaded(self) -> None:
        boosts = load_search_rank_boosts()
        self.assertGreaterEqual(boosts.get("17121", 0), 120_000_000)
        self.assertGreaterEqual(boosts.get("8024", 0), 120_000_000)


if __name__ == "__main__":
    unittest.main()
