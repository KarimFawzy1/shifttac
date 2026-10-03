"""Shared paths and config helpers for Tiki-Taka ETL scripts."""
from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("Install PyYAML: pip install pyyaml") from exc

ETL_DIR = Path(__file__).resolve().parent
ROOT = ETL_DIR.parents[1]
CONFIG = ETL_DIR / "config"
DATASETS = ROOT / "transfermarkt-datasets"
STAGING_RAW = ETL_DIR / "staging"
STAGING_NORM = ETL_DIR / "staging" / "normalized"
REPORTS = ETL_DIR / "reports"

_WHITESPACE = re.compile(r"\s+")


def load_yaml(name: str) -> dict:
    path = CONFIG / name
    if not path.is_file():
        raise FileNotFoundError(f"Missing config: {path}")
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def collapse_whitespace(value: str) -> str:
    return _WHITESPACE.sub(" ", value.strip())


def normalize_player_name(value: str) -> str:
    return collapse_whitespace(value)


def make_search_text(display_name: str) -> str:
    from search_transliteration import make_search_text as _make_search_text

    return _make_search_text(display_name)


class NationResolver:
    """Map Transfermarkt citizenship strings to allowlisted nation slugs."""

    def __init__(
        self, nations_allowlist: dict[str, str], nation_aliases: dict[str, str]
    ) -> None:
        self.allowed_slugs = set(nations_allowlist.values())
        self._raw_to_slug: dict[str, str] = {}
        for display, slug in nations_allowlist.items():
            self._raw_to_slug[display] = slug
        for raw, slug in nation_aliases.items():
            self._raw_to_slug[raw] = slug

    def resolve(self, citizenship: str | None) -> str:
        raw = collapse_whitespace(citizenship or "")
        if not raw:
            return ""
        return self._raw_to_slug.get(raw, "")


class PositionMapper:
    """Map TM position / sub_position to GK | DEF | MID | FWD (prefer sub_position)."""

    VALID_BUCKETS = frozenset({"GK", "DEF", "MID", "FWD"})

    def __init__(
        self,
        coarse_position: dict[str, str],
        sub_position: dict[str, str],
    ) -> None:
        self._coarse = dict(coarse_position)
        self._sub = dict(sub_position)
        self.unmapped: Counter[str] = Counter()

    def resolve(self, position: str | None, sub_position: str | None) -> str | None:
        coarse = collapse_whitespace(position or "")
        fine = collapse_whitespace(sub_position or "")

        if coarse == "Missing" or (not coarse and not fine):
            return None

        if fine:
            bucket = self._sub.get(fine)
            if bucket:
                return bucket
            # Unknown sub_position — fall back to coarse `position` column.
            self.unmapped[f"sub_position:{fine}|position:{coarse}"] += 1

        if coarse:
            bucket = self._coarse.get(coarse)
            if bucket:
                return bucket
            self.unmapped[f"position:{coarse}|sub_position:{fine}"] += 1

        return None
