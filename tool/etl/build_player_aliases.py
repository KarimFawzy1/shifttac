#!/usr/bin/env python3
"""Phase D8 — player_aliases and search index for prefix lookup.

Builds alternate normalized search keys:
  - full search_text (same as players_table)
  - contiguous token n-grams (e.g. kolo muani, van dijk)
  - surname-only when unique among filtered players
  - manual entries from name_aliases.yaml (players section)

Writes:
  tool/etl/staging/player_aliases.csv
  tool/etl/reports/build_player_aliases_summary.json

Exit 1 if D7 players_table missing or DoD spot-checks fail.
"""
from __future__ import annotations

import csv
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS, load_yaml, make_search_text  # noqa: E402

STAGING = _ETL_DIR / "staging"
PLAYERS_TABLE_PATH = STAGING / "players_table.csv"
ALIASES_PATH = STAGING / "player_aliases.csv"
SUMMARY_PATH = REPORTS / "build_player_aliases_summary.json"

FIELDNAMES = ("player_id", "alias")
TOKEN_SPLIT = re.compile(r"[\s\-']+")
MIN_TOKEN_LEN = 2

MOHAMED_SALAH_ID = "tm:148455"
SALAH_PREFIX = "salah"

# (prefix, expected_player_id, display_name hint for error messages)
NGRAM_SPOT_CHECKS: tuple[tuple[str, str, str], ...] = (
    ("van dijk", "tm:139208", "Virgil van Dijk"),
    ("kolo muani", "tm:487969", "Randal Kolo Muani"),
    ("de jong", "tm:326330", "Frenkie de Jong"),
)


def tm_id(raw_player_id: str) -> str:
    return raw_player_id if raw_player_id.startswith("tm:") else f"tm:{raw_player_id}"


def normalize_alias(value: str) -> str:
    return make_search_text(value)


def tokenize(search_text: str) -> list[str]:
    return [
        t
        for t in TOKEN_SPLIT.split(search_text)
        if len(t) >= MIN_TOKEN_LEN
    ]


def contiguous_ngrams(tokens: list[str]) -> list[str]:
    """Contiguous token subsequences for prefix alias lookup (1..n tokens)."""
    if not tokens:
        return []

    phrases: list[str] = []
    for start in range(len(tokens)):
        for end in range(start, len(tokens)):
            phrase = " ".join(tokens[start : end + 1])
            if phrase:
                phrases.append(phrase)
    return phrases


def extract_surname(display_name: str) -> str:
    parts = TOKEN_SPLIT.split(normalize_alias(display_name))
    return parts[-1] if parts else ""


def load_players() -> list[dict[str, str]]:
    if not PLAYERS_TABLE_PATH.is_file():
        raise FileNotFoundError(f"Missing {PLAYERS_TABLE_PATH} (run D7 first)")
    players: list[dict[str, str]] = []
    with PLAYERS_TABLE_PATH.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            players.append(dict(row))
    return players


def resolve_yaml_player_ref(ref: str, by_display: dict[str, str]) -> str | None:
    ref = ref.strip()
    if not ref:
        return None
    if ref.startswith("tm:"):
        return ref
    if ref.isdigit():
        return tm_id(ref)
    normalized = normalize_alias(ref)
    return by_display.get(normalized)


def build_alias_rows(players: list[dict[str, str]]) -> tuple[list[dict[str, str]], dict]:
    by_display = {normalize_alias(p["display_name"]): p["id"] for p in players}
    player_ids = {p["id"] for p in players}

    # (player_id, alias) -> source tag for stats
    entries: dict[tuple[str, str], str] = {}

    def add(player_id: str, alias: str, source: str) -> None:
        alias = normalize_alias(alias)
        if not alias or player_id not in player_ids:
            return
        key = (player_id, alias)
        if key not in entries:
            entries[key] = source

    surname_to_players: dict[str, list[str]] = defaultdict(list)

    for player in players:
        pid = player["id"]
        display = player["display_name"]
        search_text = player["search_text"] or normalize_alias(display)

        add(pid, search_text, "full_name")

        tokens = tokenize(search_text)
        rank = int((player.get("search_rank") or "0").strip() or 0)
        for phrase in contiguous_ngrams(tokens):
            if " " not in phrase and rank == 0:
                continue
            source = "word_token" if " " not in phrase else "phrase_ngram"
            add(pid, phrase, source)

        surname = extract_surname(display)
        if surname:
            surname_to_players[surname].append(pid)

    for surname, pids in surname_to_players.items():
        if len(pids) == 1:
            add(pids[0], surname, "unique_surname")

    yaml_players = load_yaml("name_aliases.yaml").get("players") or {}
    for alias_raw, player_ref in yaml_players.items():
        pid = resolve_yaml_player_ref(str(player_ref), by_display)
        if pid:
            add(pid, str(alias_raw), "yaml")

    rows = [{"player_id": pid, "alias": alias} for (pid, alias) in sorted(entries)]
    stats = {
        "total_alias_rows": len(rows),
        "phrase_ngram_aliases": sum(1 for source in entries.values() if source == "phrase_ngram"),
        "unique_surnames_added": sum(
            1 for s, pids in surname_to_players.items() if len(pids) == 1
        ),
        "yaml_aliases_added": len(yaml_players),
        "players_indexed": len(players),
    }
    return rows, stats


def prefix_search(
    players: list[dict[str, str]], alias_rows: list[dict[str, str]], prefix: str
) -> list[dict[str, str]]:
    """Simulate: players.search_text OR player_aliases.alias prefix match."""
    needle = normalize_alias(prefix)
    hits: dict[str, dict[str, str]] = {}

    for player in players:
        if (player["search_text"] or "").startswith(needle):
            hits[player["id"]] = player

    for row in alias_rows:
        if row["alias"].startswith(needle):
            pid = row["player_id"]
            if pid not in hits:
                for player in players:
                    if player["id"] == pid:
                        hits[pid] = player
                        break

    return sorted(hits.values(), key=lambda p: p["display_name"])


def run_spot_checks(
    players: list[dict[str, str]], alias_rows: list[dict[str, str]]
) -> tuple[list[str], dict]:
    errors: list[str] = []
    salah_hits = prefix_search(players, alias_rows, SALAH_PREFIX)
    salah_ids = {p["id"] for p in salah_hits}

    details: dict = {
        "prefix_salah_match_count": len(salah_hits),
        "prefix_salah_includes_mohamed_salah": MOHAMED_SALAH_ID in salah_ids,
        "prefix_salah_sample_names": [p["display_name"] for p in salah_hits[:8]],
    }

    if MOHAMED_SALAH_ID not in salah_ids:
        errors.append(
            f"prefix '{SALAH_PREFIX}' must return Mohamed Salah ({MOHAMED_SALAH_ID})"
        )

    # Colliding surname: find a token/surname prefix matching multiple players
    surname_counts = Counter(extract_surname(p["display_name"]) for p in players)
    collision_surname = next(
        (s for s, c in surname_counts.most_common() if c >= 3 and len(s) >= 3),
        "",
    )
    if collision_surname:
        collision_hits = prefix_search(players, alias_rows, collision_surname)
        details["collision_check"] = {
            "surname_prefix": collision_surname,
            "match_count": len(collision_hits),
            "sample_names": [p["display_name"] for p in collision_hits[:5]],
        }
        if len(collision_hits) < 2:
            errors.append(
                f"expected multiple rows for colliding surname prefix '{collision_surname}'"
            )
    else:
        details["collision_check"] = {"note": "no surname with 3+ players found"}

    ngram_checks: list[dict[str, object]] = []
    for prefix, expected_id, label in NGRAM_SPOT_CHECKS:
        hits = prefix_search(players, alias_rows, prefix)
        hit_ids = {player["id"] for player in hits}
        ok = expected_id in hit_ids
        ngram_checks.append(
            {
                "prefix": prefix,
                "expected_id": expected_id,
                "expected_name": label,
                "passed": ok,
                "match_count": len(hits),
            }
        )
        if not ok:
            errors.append(
                f"prefix '{prefix}' must return {label} ({expected_id})"
            )
    details["ngram_spot_checks"] = ngram_checks

    return errors, details


def main() -> int:
    try:
        players = load_players()
    except FileNotFoundError as exc:
        print(f"D8 build FAILED: {exc}", file=sys.stderr)
        return 1

    alias_rows, build_stats = build_alias_rows(players)

    STAGING.mkdir(parents=True, exist_ok=True)
    with ALIASES_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(alias_rows)

    spot_errors, spot_details = run_spot_checks(players, alias_rows)

    summary = {
        "phase": "D8",
        "built_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "output": str(ALIASES_PATH),
        "build_stats": build_stats,
        "spot_checks": spot_details,
        "spot_check_passed": not spot_errors,
    }

    REPORTS.mkdir(parents=True, exist_ok=True)
    with SUMMARY_PATH.open("w", encoding="utf-8", newline="") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")

    if spot_errors:
        print("D8 build FAILED:", file=sys.stderr)
        for err in spot_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(
        f"D8 build OK: {len(alias_rows):,} alias rows for {len(players):,} players, "
        f"prefix '{SALAH_PREFIX}' -> {spot_details['prefix_salah_match_count']} hits"
    )
    print(f"  output: {ALIASES_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
