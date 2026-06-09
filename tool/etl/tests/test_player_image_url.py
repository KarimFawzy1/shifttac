"""Unit tests for player_image_url helpers."""
from __future__ import annotations

import unittest

from player_image_url import (
    build_commons_thumbnail_url,
    commons_file_from_url,
    filename_from_p18_uri,
    is_valid_commons_image_url,
    tm_id,
    tm_numeric,
)


class PlayerImageUrlTests(unittest.TestCase):
    def test_tm_id_normalization(self) -> None:
        self.assertEqual(tm_id("148455"), "tm:148455")
        self.assertEqual(tm_id("tm:148455"), "tm:148455")
        self.assertEqual(tm_numeric("tm:148455"), "148455")

    def test_filename_from_p18_uri_decodes_percent_encoding(self) -> None:
        uri = "http://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg"
        self.assertEqual(filename_from_p18_uri(uri), "Mohamed Salah 2018.jpg")

    def test_build_commons_thumbnail_url_single_encode(self) -> None:
        url = build_commons_thumbnail_url("Mohamed Salah 2018.jpg")
        self.assertEqual(
            url,
            "https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128",
        )
        self.assertNotIn("%2520", url)

    def test_build_commons_thumbnail_url_from_already_encoded_filename(self) -> None:
        encoded = filename_from_p18_uri(
            "http://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg"
        )
        url = build_commons_thumbnail_url(encoded)
        self.assertNotIn("%2520", url)
        self.assertTrue(url.endswith("?width=128"))

    def test_is_valid_commons_image_url(self) -> None:
        valid = build_commons_thumbnail_url("Test Player.jpg")
        self.assertTrue(is_valid_commons_image_url(valid))
        self.assertFalse(is_valid_commons_image_url("http://commons.wikimedia.org/x"))
        self.assertFalse(
            is_valid_commons_image_url(
                "https://www.transfermarkt.com/img/test.jpg"
            )
        )

    def test_commons_file_from_url(self) -> None:
        url = build_commons_thumbnail_url("Erling Haaland June 2025.jpg")
        self.assertEqual(commons_file_from_url(url), "Erling Haaland June 2025.jpg")


if __name__ == "__main__":
    unittest.main()
