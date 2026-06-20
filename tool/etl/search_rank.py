"""Precomputed player search rank from Transfermarkt market value + manual boosts."""
from __future__ import annotations

from etl_common import load_yaml

_BOOST_CONFIG = "search_rank_boost.yaml"
_LEGENDARY_BOOST_CONFIG = "legendary_search_rank_boost.yaml"


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
