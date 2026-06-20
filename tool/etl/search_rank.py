"""Precomputed player search rank from Transfermarkt market value + manual boosts."""
from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path

from etl_common import load_yaml

_ETL_DIR = Path(__file__).resolve().parent
_ROOT = _ETL_DIR.parents[1]
_LEGENDARY_CSV = _ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"

_BOOST_CONFIG = "search_rank_boost.yaml"
_LEGENDARY_BOOST_CONFIG = "legendary_search_rank_boost.yaml"

# Retired legends need ~120M to rank above active prefix matches on short queries.
LEGENDARY_SEARCH_RANK_FLOOR = 120_000_000


def _parse_eur(value: str | None) -> int:
    raw = (value or "").strip()
    if not raw:
        return 0
    try:
        return max(0, int(float(raw)))
    except ValueError:
        return 0


def _load_boost_file(config_name: str) -> dict[str, int]:
    boosts: dict[str, int] = {}
    try:
        players = load_yaml(config_name).get("players") or {}
    except FileNotFoundError:
        return boosts
    for player_ref, boost in players.items():
        ref = str(player_ref).strip().removeprefix("tm:")
        if not ref:
            continue
        try:
            points = int(boost)
        except (TypeError, ValueError):
            continue
        if points > 0:
            boosts[ref] = max(boosts.get(ref, 0), points)
    return boosts


def load_search_rank_boosts() -> dict[str, int]:
    """TM player_id (no tm: prefix) -> extra rank points in EUR."""
    boosts = _load_boost_file(_BOOST_CONFIG)
    for player_id, points in _load_boost_file(_LEGENDARY_BOOST_CONFIG).items():
        boosts[player_id] = max(boosts.get(player_id, 0), points)
    return boosts


@lru_cache(maxsize=1)
def load_legendary_roster_order() -> dict[str, int]:
    """Transfermarkt id -> 0-based row index in legendary CSV (lower = more prominent)."""
    if not _LEGENDARY_CSV.is_file():
        return {}

    order: dict[str, int] = {}
    with _LEGENDARY_CSV.open(encoding="utf-8", newline="") as handle:
        for index, row in enumerate(csv.DictReader(handle)):
            player_id = (row.get("transfermarkt_id") or "").strip().removeprefix("tm:")
            if player_id:
                order[player_id] = index
    return order


@lru_cache(maxsize=1)
def load_legendary_roster_ids() -> frozenset[str]:
    """Transfermarkt ids from legendary_players_with_tm_id.csv (no tm: prefix)."""
    return frozenset(load_legendary_roster_order().keys())


def legendary_search_rank_floor(player_id: str) -> int | None:
    """Minimum rank for a roster legend, or None when not on the roster."""
    normalized_id = player_id.strip().removeprefix("tm:")
    order = load_legendary_roster_order()
    index = order.get(normalized_id)
    if index is None:
        return None
    # Earlier CSV rows (Maradona, Pelé, …) outrank later rows on tied prefixes.
    return LEGENDARY_SEARCH_RANK_FLOOR + (len(order) - index)


def apply_legendary_search_rank_floor(player_id: str, search_rank: int) -> int:
    """Ensure roster legends surface above obscure active players on short prefixes."""
    floor = legendary_search_rank_floor(player_id)
    if floor is None:
        return search_rank
    return max(search_rank, floor)


def compute_search_rank(
    market_value_in_eur: str | None,
    highest_market_value_in_eur: str | None,
    *,
    manual_boost: int = 0,
) -> int:
    base = max(
        _parse_eur(market_value_in_eur),
        _parse_eur(highest_market_value_in_eur),
    )
    return base + max(0, manual_boost)
