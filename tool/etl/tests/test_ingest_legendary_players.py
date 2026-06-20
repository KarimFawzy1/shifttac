"""Unit tests for ingest_legendary_players.py."""
from __future__ import annotations

import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

import ingest_legendary_players as ingest  # noqa: E402


class IngestLegendaryPlayersTests(unittest.TestCase):
    def setUp(self) -> None:
        self.clubs = {
            "Inter Milan": "46",
            "Red Star Belgrade": "159",
            "Bayern Munich": "27",
            "Al Shabab": "9840",
            "Leicester City": "1003",
            "Real Madrid": "418",
            "River Plate": "209",
            "Espanyol": "714",
        }
        self.aliases = {
            "Al-Shabab": "Al Shabab",
            "Paris Saint-Germain": "Paris Saint Germain",
        }
        self.top5 = {
            "46": "IT1",
            "159": "SER1",  # not top5 — ignored in league edges
            "27": "L1",
            "9840": "SA1",
            "1003": "GB1",
            "418": "ES1",
            "714": "ES1",
        }
        self.resolver = ingest.build_nation_resolver()

    def _process(self, row: dict[str, str]) -> ingest.PlayerEdges:
        unmapped_clubs: dict[str, list[str]] = {}
        unmapped_nations: list[dict[str, str]] = []
        player = ingest.process_row(
            row,
            clubs=self.clubs,
            aliases=self.aliases,
            top5_map=self.top5,
            resolver=self.resolver,
            manual_clubs={},
            unmapped_clubs=unmapped_clubs,
            unmapped_nations=unmapped_nations,
        )
        assert player is not None
        self.assertEqual(unmapped_clubs, {})
        self.assertEqual(unmapped_nations, [])
        return player

    def test_distefano_dual_nation_edges(self) -> None:
        player = self._process(
            {
                "Player Name": "Alfredo Di Stéfano",
                "Nationality": "Argentina / Spain",
                "Position": "FWD",
                "Senior Clubs Played For": "River Plate, Real Madrid, Espanyol",
                "transfermarkt_id": "135778",
                "wikidata_qid": "Q164546",
            }
        )
        self.assertEqual(player.nation_slugs, {"argentina", "spain"})
        self.assertIn("418", player.club_ids)
        self.assertIn("ES1", player.league_ids)
        self.assertEqual(player.position_bucket, "FWD")
        self.assertTrue(player.qualifies())

    def test_brazilian_leicester_edges(self) -> None:
        player = self._process(
            {
                "Player Name": "Test Brazilian",
                "Nationality": "Brazil",
                "Position": "FWD",
                "Senior Clubs Played For": "Leicester City",
                "transfermarkt_id": "999001",
                "wikidata_qid": "Q1",
            }
        )
        self.assertIn("brazil", player.nation_slugs)
        self.assertIn("1003", player.club_ids)
        self.assertIn("GB1", player.league_ids)

    def test_single_attribute_excluded(self) -> None:
        player = self._process(
            {
                "Player Name": "Nation Only",
                "Nationality": "Brazil",
                "Position": "",
                "Senior Clubs Played For": "",
                "transfermarkt_id": "999002",
                "wikidata_qid": "Q2",
            }
        )
        self.assertFalse(player.qualifies())

    def test_pancev_included_via_two_clubs(self) -> None:
        player = self._process(
            {
                "Player Name": "Darko Pančev",
                "Nationality": "",
                "Position": "FWD",
                "Senior Clubs Played For": "Red Star Belgrade, Inter Milan",
                "transfermarkt_id": "100098",
                "wikidata_qid": "Q311362",
            }
        )
        self.assertEqual(player.nation_slugs, set())
        self.assertEqual(player.club_ids, {"159", "46"})
        self.assertTrue(player.qualifies())

    def test_al_shabab_alias_resolves(self) -> None:
        player = self._process(
            {
                "Player Name": "Ali Daei",
                "Nationality": "",
                "Position": "FWD",
                "Senior Clubs Played For": "Bayern Munich, Al-Shabab",
                "transfermarkt_id": "335",
                "wikidata_qid": "Q159622",
            }
        )
        self.assertIn("9840", player.club_ids)
        self.assertIn("27", player.club_ids)

    def test_stripped_nation_not_emitted(self) -> None:
        unmapped_clubs: dict[str, list[str]] = {}
        unmapped_nations: list[dict[str, str]] = []
        player = ingest.process_row(
            {
                "Player Name": "Should Strip",
                "Nationality": "Iran",
                "Position": "FWD",
                "Senior Clubs Played For": "Bayern Munich",
                "transfermarkt_id": "999003",
                "wikidata_qid": "Q3",
            },
            clubs=self.clubs,
            aliases=self.aliases,
            top5_map=self.top5,
            resolver=self.resolver,
            manual_clubs={},
            unmapped_clubs=unmapped_clubs,
            unmapped_nations=unmapped_nations,
        )
        assert player is not None
        self.assertEqual(player.nation_slugs, set())
        self.assertEqual(unmapped_nations, [])
        self.assertTrue(player.qualifies())  # Bayern + FWD

    def test_full_ingest_writes_outputs(self) -> None:
        rows = [
            {
                "Player Name": "Alfredo Di Stéfano",
                "Nationality": "Argentina / Spain",
                "DOB": "Jul 4, 1926",
                "Position": "FWD",
                "Senior Clubs Played For": "River Plate, Real Madrid, Espanyol",
                "transfermarkt_id": "135778",
                "wikidata_qid": "Q164546",
            }
        ]
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            staging = tmp_path / "legendary"
            summary_path = tmp_path / "summary.json"
            excluded_path = tmp_path / "excluded.json"
            with (
                patch.object(ingest, "STAGING_LEGENDARY", staging),
                patch.object(ingest, "SUMMARY_PATH", summary_path),
                patch.object(ingest, "EXCLUDED_REPORT", excluded_path),
                patch.object(ingest, "load_club_resolver", return_value=(self.clubs, self.aliases)),
                patch.object(ingest, "load_top5_league_map", return_value=self.top5),
                patch.object(ingest, "load_manual_club_fixes", return_value={}),
            ):
                summary = ingest.ingest_rows(rows)

            self.assertEqual(summary["included_preview"], 1)
            nation_rows = list(
                csv.DictReader((staging / "legendary_player_nation.csv").open(encoding="utf-8"))
            )
            nation_attrs = {row["attribute_id"] for row in nation_rows}
            self.assertEqual(nation_attrs, {"nation:argentina", "nation:spain"})


if __name__ == "__main__":
    unittest.main()
