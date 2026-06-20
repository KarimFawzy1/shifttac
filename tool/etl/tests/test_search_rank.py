"""Unit tests for search_rank computation."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_rank import (  # noqa: E402
    apply_legendary_search_rank_floor,
    compute_search_rank,
    legendary_search_rank_floor,
    load_legendary_roster_ids,
    load_search_rank_boosts,
)


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

    def test_legendary_roster_includes_maldini_and_ginola(self) -> None:
        roster = load_legendary_roster_ids()
        self.assertIn("5803", roster)
        self.assertIn("104897", roster)

    def test_legendary_floor_raises_zero_rank_legends(self) -> None:
        paolo_floor = legendary_search_rank_floor("5803")
        ginola_floor = legendary_search_rank_floor("104897")
        self.assertIsNotNone(paolo_floor)
        self.assertIsNotNone(ginola_floor)
        self.assertEqual(apply_legendary_search_rank_floor("5803", 0), paolo_floor)
        self.assertEqual(apply_legendary_search_rank_floor("tm:104897", 0), ginola_floor)
        self.assertGreater(paolo_floor, ginola_floor)

    def test_legendary_floor_does_not_lower_high_rank(self) -> None:
        high_rank = 200_000_000
        self.assertEqual(
            apply_legendary_search_rank_floor("28003", high_rank),
            high_rank,
        )

    def test_non_legendary_player_unaffected(self) -> None:
        self.assertEqual(apply_legendary_search_rank_floor("999999", 5_000_000), 5_000_000)


if __name__ == "__main__":
    unittest.main()
