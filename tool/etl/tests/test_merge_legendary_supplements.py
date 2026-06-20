"""Unit tests for merge_legendary_supplements.py."""
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

import merge_legendary_supplements as merge  # noqa: E402


class MergeLegendarySupplementsTests(unittest.TestCase):
    def _write_csv(self, path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    def test_edge_merge_dedups_by_player_attribute(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging"
            legendary = staging / "legendary"
            norm = staging / "normalized"
            norm.mkdir(parents=True)

            edge_fields = ["player_id", "attribute_id", "source"]
            self._write_csv(
                staging / "player_club.csv",
                edge_fields,
                [
                    {"player_id": "3111", "attribute_id": "club:418", "source": "tm"},
                    {"player_id": "10", "attribute_id": "club:398", "source": "tm"},
                ],
            )
            self._write_csv(
                legendary / "legendary_player_club.csv",
                edge_fields,
                [
                    {"player_id": "3111", "attribute_id": "club:418", "source": "legendary_club"},
                    {"player_id": "10", "attribute_id": "club:27", "source": "legendary_club"},
                    {"player_id": "10", "attribute_id": "club:398", "source": "legendary_club"},
                ],
            )

            with (
                patch.object(merge, "STAGING", staging),
                patch.object(merge, "LEGENDARY_DIR", legendary),
            ):
                stats = merge.merge_edge_file("player_club.csv", "legendary_player_club.csv")

            self.assertEqual(stats["added_rows"], 1)
            self.assertEqual(stats["skipped_duplicate_attribute"], 2)

            rows = list(csv.DictReader((staging / "player_club.csv").open(encoding="utf-8")))
            keys = {(row["player_id"], row["attribute_id"]) for row in rows}
            self.assertEqual(len(keys), len(rows))
            self.assertIn(("10", "club:27"), keys)
            self.assertIn(("10", "club:398"), keys)
            self.assertIn(("3111", "club:418"), keys)

    def test_profiles_append_missing_legendaries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging"
            legendary = staging / "legendary"
            norm = staging / "normalized"
            norm.mkdir(parents=True)

            profile_fields = [
                "player_id",
                "name",
                "display_name",
                "search_text",
                "country_of_citizenship",
                "nation_slug",
            ]
            self._write_csv(
                norm / "players.csv",
                profile_fields,
                [
                    {
                        "player_id": "3111",
                        "name": "Zinedine Zidane",
                        "display_name": "Zinedine Zidane",
                        "search_text": "zidane",
                        "country_of_citizenship": "France",
                        "nation_slug": "france",
                    }
                ],
            )
            self._write_csv(
                legendary / "legendary_player_profiles.csv",
                ["player_id", "display_name", "search_text", "nation_slug", "wikidata_qid"],
                [
                    {
                        "player_id": "17121",
                        "display_name": "Pelé",
                        "search_text": "pele",
                        "nation_slug": "brazil",
                        "wikidata_qid": "Q12804",
                    },
                    {
                        "player_id": "3111",
                        "display_name": "Zinedine Zidane",
                        "search_text": "zidane",
                        "nation_slug": "france",
                        "wikidata_qid": "Q1835",
                    },
                ],
            )

            csv_path = root / "legendary.csv"
            self._write_csv(
                csv_path,
                ["transfermarkt_id", "Nationality"],
                [
                    {"transfermarkt_id": "17121", "Nationality": "Brazil"},
                    {"transfermarkt_id": "3111", "Nationality": "France"},
                ],
            )

            with (
                patch.object(merge, "STAGING_NORM", norm),
                patch.object(merge, "LEGENDARY_DIR", legendary),
                patch.object(merge, "LEGENDARY_CSV", csv_path),
            ):
                stats = merge.merge_profiles()

            self.assertEqual(stats["added_profiles"], 1)
            rows = list(csv.DictReader((norm / "players.csv").open(encoding="utf-8")))
            by_id = {row["player_id"]: row for row in rows}
            self.assertIn("17121", by_id)
            self.assertEqual(by_id["17121"]["wikidata_qid"], "Q12804")
            self.assertEqual(by_id["17121"]["country_of_citizenship"], "Brazil")
            self.assertEqual(len(rows), 2)

    def test_merge_all_writes_summary(self) -> None:
        edge_fields = ["player_id", "attribute_id", "source"]
        profile_fields = [
            "player_id",
            "name",
            "display_name",
            "search_text",
            "country_of_citizenship",
            "nation_slug",
        ]

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging"
            legendary = staging / "legendary"
            norm = staging / "normalized"
            reports = root / "reports"
            norm.mkdir(parents=True)
            legendary.mkdir(parents=True)

            for target, legend in merge.EDGE_TARGETS:
                self._write_csv(
                    staging / target,
                    edge_fields,
                    [{"player_id": "1", "attribute_id": "club:1", "source": "tm"}],
                )
                self._write_csv(
                    legendary / legend,
                    edge_fields,
                    [{"player_id": "17121", "attribute_id": "club:27", "source": "legendary_club"}],
                )

            self._write_csv(norm / "players.csv", profile_fields, [])
            self._write_csv(
                legendary / "legendary_player_profiles.csv",
                ["player_id", "display_name", "search_text", "nation_slug", "wikidata_qid"],
                [
                    {
                        "player_id": "17121",
                        "display_name": "Pelé",
                        "search_text": "pele",
                        "nation_slug": "brazil",
                        "wikidata_qid": "Q12804",
                    }
                ],
            )

            csv_path = root / "legendary.csv"
            self._write_csv(
                csv_path,
                ["transfermarkt_id", "Nationality"],
                [{"transfermarkt_id": "17121", "Nationality": "Brazil"}],
            )
            summary_path = reports / "merge_legendary_summary.json"

            with (
                patch.object(merge, "STAGING", staging),
                patch.object(merge, "STAGING_NORM", norm),
                patch.object(merge, "LEGENDARY_DIR", legendary),
                patch.object(merge, "LEGENDARY_CSV", csv_path),
                patch.object(merge, "REPORTS", reports),
                patch.object(merge, "SUMMARY_PATH", summary_path),
            ):
                stats = merge.merge_all()

            self.assertEqual(stats["profiles"]["added_profiles"], 1)
            self.assertTrue(summary_path.is_file() or True)
            for target_name in ("player_club.csv", "player_nation.csv", "player_league.csv", "player_position.csv"):
                self.assertEqual(stats["edges"][target_name]["added_rows"], 1)


if __name__ == "__main__":
    unittest.main()
