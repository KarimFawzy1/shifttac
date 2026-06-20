"""Unit tests for fetch_player_images legendary QID fast path."""
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

import fetch_player_images as fetch  # noqa: E402
from fetch_player_images import PlayerImageRow  # noqa: E402


class FetchPlayerImagesLegendaryTests(unittest.TestCase):
    def test_normalize_qid(self) -> None:
        self.assertEqual(fetch.normalize_qid("q12897"), "Q12897")
        self.assertEqual(fetch.normalize_qid("wd:Q164546"), "Q164546")
        self.assertEqual(fetch.normalize_qid(""), "")

    def test_partition_targets_by_qid(self) -> None:
        qid_map = {"tm:17121": "Q12897", "tm:8024": "Q17515"}
        qid_targets, p2446_targets = fetch.partition_targets_by_qid(
            ["tm:17121", "tm:8024", "tm:9999"],
            qid_map,
        )
        self.assertEqual(qid_targets, [("tm:17121", "Q12897"), ("tm:8024", "Q17515")])
        self.assertEqual(p2446_targets, ["tm:9999"])

    def test_resolve_qid_images_uses_fast_path(self) -> None:
        stats = fetch.FetchStats()
        found = {"Q12897", "Q17515"}
        batch_results = {
            "Q12897": "http://commons.wikimedia.org/wiki/Special:FilePath/Pele%201970.jpg",
            "Q17515": None,
        }

        with patch.object(fetch, "fetch_qid_sparql_batch", return_value=(found, batch_results)):
            resolved = fetch.resolve_qid_images(
                [("tm:17121", "Q12897"), ("tm:8024", "Q17515")],
                stats,
                verify_urls=False,
                included_legendary_ids={"tm:17121", "tm:8024"},
            )

        self.assertIn("tm:17121", resolved)
        self.assertNotIn("tm:8024", resolved)
        self.assertEqual(stats.matched_wikidata, 2)
        self.assertEqual(stats.legendary_matched_wikidata, 2)
        self.assertEqual(stats.with_p18, 1)
        self.assertEqual(stats.skipped["no_p18"], 1)

    def test_load_overrides_rejects_invalid_urls(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "overrides.yaml"
            path.write_text(
                """
tm:17121:
  url: "https://www.transfermarkt.com/img/test.jpg"
tm:8024:
  url: "https://commons.wikimedia.org/wiki/Special:FilePath/Maradona%201986.jpg?width=128"
""".strip(),
                encoding="utf-8",
            )
            overrides = fetch.load_overrides(path)
            self.assertNotIn("tm:17121", overrides)
            self.assertIn("tm:8024", overrides)

    def test_write_legendary_misses(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "misses.json"
            fetch.write_legendary_misses(
                path,
                included_legendary_ids={"tm:17121", "tm:8024"},
                rows={"tm:17121": PlayerImageRow("tm:17121", "https://commons.wikimedia.org/wiki/Special:FilePath/x.jpg?width=128", "x.jpg")},
                qid_map={"tm:17121": "Q12897", "tm:8024": "Q17515"},
                profile_names={"tm:17121": "Pelé", "tm:8024": "Maradona"},
            )
            payload = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(payload["miss_count"], 1)
            self.assertEqual(payload["misses"][0]["player_id"], "tm:8024")

    def test_run_only_missing_uses_qid_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging"
            legendary = staging / "legendary"
            reports = root / "reports"
            staging.mkdir()
            legendary.mkdir()
            reports.mkdir()

            self._write_csv(
                staging / "players_table.csv",
                ["id", "display_name", "search_text", "position", "nation", "search_rank"],
                [{"id": "tm:17121", "display_name": "Pelé", "search_text": "pele", "position": "FWD", "nation": "brazil", "search_rank": "500"}],
            )
            self._write_csv(
                legendary / "legendary_player_profiles.csv",
                ["player_id", "display_name", "search_text", "nation_slug", "wikidata_qid"],
                [{"player_id": "17121", "display_name": "Pelé", "search_text": "pele", "nation_slug": "brazil", "wikidata_qid": "Q12897"}],
            )
            self._write_csv(staging / "player_images.csv", ["player_id", "image_url", "commons_file"], [])

            resolved = {
                "tm:17121": PlayerImageRow(
                    "tm:17121",
                    "https://commons.wikimedia.org/wiki/Special:FilePath/Pele%201970.jpg?width=128",
                    "Pele 1970.jpg",
                )
            }

            args = fetch.build_parser().parse_args(["--only-missing"])
            with (
                patch.object(fetch, "STAGING", staging),
                patch.object(fetch, "REPORTS", reports),
                patch.object(fetch, "PLAYERS_TABLE_PATH", staging / "players_table.csv"),
                patch.object(fetch, "PLAYER_IMAGES_PATH", staging / "player_images.csv"),
                patch.object(fetch, "LEGENDARY_PROFILES_PATH", legendary / "legendary_player_profiles.csv"),
                patch.object(fetch, "LEGENDARY_MISSES_PATH", reports / "legendary_image_misses.json"),
                patch.object(fetch, "SUMMARY_PATH", reports / "fetch_player_images_summary.json"),
                patch.object(fetch, "OVERRIDES_PATH", root / "missing_overrides.yaml"),
                patch.object(fetch, "resolve_qid_images", return_value=resolved) as qid_mock,
                patch.object(fetch, "resolve_wikidata_images", return_value={}) as p2446_mock,
            ):
                code = fetch.run(args)

            self.assertEqual(code, 0)
            qid_mock.assert_called_once()
            p2446_mock.assert_not_called()
            summary = json.loads((reports / "fetch_player_images_summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["legendary"]["with_image"], 1)

    def _write_csv(self, path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)


if __name__ == "__main__":
    unittest.main()
