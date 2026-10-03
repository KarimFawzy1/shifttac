"""Player-name transliteration for prefix search (ETL + Dart parity).

Algorithm:
  1. Replace ligatures and letters NFKD mishandles (ø, æ, ß, ł, ı, …).
  2. NFKD decompose remaining accented letters.
  3. Drop combining marks so ć→c, š→s, etc.
"""
from __future__ import annotations

import re
import unicodedata

_WHITESPACE = re.compile(r"\s+")

# Order matters: multi-char ligatures before single-char rules.
_SPECIAL_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("œ", "oe"),
    ("Œ", "oe"),
    ("æ", "ae"),
    ("Æ", "ae"),
    ("ß", "ss"),
    ("ø", "o"),
    ("Ø", "o"),
    ("ł", "l"),
    ("Ł", "l"),
    ("đ", "d"),
    ("Đ", "d"),
    ("ð", "d"),
    ("Ð", "d"),
    ("ı", "i"),  # Turkish dotless i
)


def transliterate_for_search(value: str) -> str:
    text = value
    for source, target in _SPECIAL_REPLACEMENTS:
        text = text.replace(source, target)

    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    )


def collapse_whitespace(value: str) -> str:
    return _WHITESPACE.sub(" ", value.strip())


def make_search_text(display_name: str) -> str:
    folded = transliterate_for_search(display_name).lower()
    return collapse_whitespace(folded)
