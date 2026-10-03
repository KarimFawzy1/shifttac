"""Unit tests for search_transliteration (parity with Dart normalizer)."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parents[1]
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from search_transliteration import make_search_text, transliterate_for_search  # noqa: E402

# Keep in sync with test/features/tiki_taka/data/local/search_query_normalizer_test.dart
PARITY_CASES: tuple[tuple[str, str], ...] = (
    ("Virgil van Dijk", "virgil van dijk"),
    ("Martin Ødegaard", "martin odegaard"),
    ("Alexander Sørloth", "alexander sorloth"),
    ("Simon Kjær", "simon kjaer"),
    ("Stefan Kießling", "stefan kiessling"),
    ("Kevin Großkreutz", "kevin grosskreutz"),
    ("Luka Modrić", "luka modric"),
    ("Hakan Çalhanoğlu", "hakan calhanoglu"),
    ("Paweł Olkowski", "pawel olkowski"),
    ("Yunus Mallı", "yunus malli"),
    ("Milan Škriniar", "milan skriniar"),
    ("Randal Kolo Muani", "randal kolo muani"),
    ("Ionuț Radu", "ionut radu"),
    ("Marcin Kamiński", "marcin kaminski"),
    ("  Mohamed   Salah  ", "mohamed salah"),
)


class SearchTransliterationTests(unittest.TestCase):
    def test_make_search_text_cases(self) -> None:
        for display_name, expected in PARITY_CASES:
            with self.subTest(display_name=display_name):
                self.assertEqual(make_search_text(display_name), expected)

    def test_ligatures_and_strokes_transliterate(self) -> None:
        self.assertEqual(transliterate_for_search("ø"), "o")
        self.assertEqual(transliterate_for_search("æ"), "ae")
        self.assertEqual(transliterate_for_search("ß"), "ss")
        self.assertEqual(transliterate_for_search("œ"), "oe")
        self.assertEqual(transliterate_for_search("ł"), "l")
        self.assertEqual(transliterate_for_search("ı"), "i")

    def test_accented_latin_decomposes(self) -> None:
        self.assertEqual(transliterate_for_search("ć"), "c")
        self.assertEqual(transliterate_for_search("š"), "s")
        self.assertEqual(transliterate_for_search("ğ"), "g")


if __name__ == "__main__":
    unittest.main()
