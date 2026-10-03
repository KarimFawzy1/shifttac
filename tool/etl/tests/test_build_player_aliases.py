"""Unit tests for player alias n-gram generation."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from build_player_aliases import (  # noqa: E402
    build_alias_rows,
    contiguous_ngrams,
    prefix_search,
    tokenize,
)


class ContiguousNgramsTests(unittest.TestCase):
    def test_three_token_name(self) -> None:
        tokens = tokenize("randal kolo muani")
        self.assertEqual(
            contiguous_ngrams(tokens),
            [
                "randal",
                "randal kolo",
                "randal kolo muani",
                "kolo",
                "kolo muani",
                "muani",
            ],
        )

    def test_two_token_particle_surname(self) -> None:
        tokens = tokenize("virgil van dijk")
        self.assertIn("van dijk", contiguous_ngrams(tokens))

    def test_drops_single_character_tokens(self) -> None:
        self.assertEqual(tokenize("a de jong"), ["de", "jong"])
        self.assertEqual(contiguous_ngrams(["de", "jong"]), ["de", "de jong", "jong"])


class BuildAliasRowsTests(unittest.TestCase):
    def test_phrase_ngrams_enable_mid_name_prefix_search(self) -> None:
        players = [
            {
                "id": "tm:139208",
                "display_name": "Virgil van Dijk",
                "search_text": "virgil van dijk",
            },
            {
                "id": "tm:487969",
                "display_name": "Randal Kolo Muani",
                "search_text": "randal kolo muani",
            },
        ]
        alias_rows, stats = build_alias_rows(players)

        self.assertGreater(stats["phrase_ngram_aliases"], 0)
        aliases = {(row["player_id"], row["alias"]) for row in alias_rows}
        self.assertIn(("tm:139208", "van dijk"), aliases)
        self.assertIn(("tm:487969", "kolo muani"), aliases)

        van_dijk_hits = prefix_search(players, alias_rows, "van dijk")
        self.assertEqual({player["id"] for player in van_dijk_hits}, {"tm:139208"})

    def test_yaml_alias_supports_east_asian_name_order(self) -> None:
        players = [
            {
                "id": "tm:503482",
                "display_name": "Min-jae Kim",
                "search_text": "min-jae kim",
            },
        ]
        alias_rows, _stats = build_alias_rows(players)
        aliases = {row["alias"] for row in alias_rows if row["player_id"] == "tm:503482"}

        self.assertIn("kim min-jae", aliases)

        hits = prefix_search(players, alias_rows, "kim min-jae")
        self.assertEqual({player["id"] for player in hits}, {"tm:503482"})


if __name__ == "__main__":
    unittest.main()
