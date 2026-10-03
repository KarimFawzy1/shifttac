#!/usr/bin/env python3
"""Merge master player bios with popularity rankings into one deduplicated CSV."""

from __future__ import annotations

import csv
import json
import re
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

BASE = Path(__file__).resolve().parent
MASTER_CSV = BASE / "Top Egyptian Premier League Players.csv"
RANKED_CSV = BASE / "egyptian_league_players_popularity_ranked.csv"
OUTPUT_CSV = BASE / "egyptian_players_combined.csv"
REPORT_PATH = BASE / "reports" / "merge_summary.json"

# Same person appears under two names in the master list.
ALIAS_TO_CANONICAL: dict[str, str] = {
    "bencharki": "Achraf Bencharki",
    "mohamed aboul gabal": "Mohamed Abou Gabal (Gabaski)",
}

OUTPUT_FIELDS = [
    "Player Name",
    "Nationality",
    "DOB",
    "Position",
    "Senior Clubs Played For",
    "wikidata_qid",
    "transfermarkt_id",
    "Popularity Rank",
    "Popularity Score",
    "Popularity Tier",
    "Score Type",
    "Confidence",
    "Basis / Notes",
    "merge_notes",
]


@dataclass
class Popularity:
    rank: str = ""
    score: str = ""
    tier: str = ""
    score_type: str = ""
    confidence: str = ""
    notes: str = ""

    @classmethod
    def from_ranked_row(cls, row: dict[str, str]) -> Popularity:
        return cls(
            rank=(row.get("Rank") or "").strip(),
            score=(row.get("Popularity Score") or "").strip(),
            tier=(row.get("Popularity Tier") or "").strip(),
            score_type=(row.get("Score Type") or "").strip(),
            confidence=(row.get("Confidence") or "").strip(),
            notes=(row.get("Basis / Notes") or "").strip(),
        )

    def is_better_than(self, other: Popularity) -> bool:
        try:
            return int(self.score or 0) > int(other.score or 0)
        except ValueError:
            return False


@dataclass
class PlayerRow:
    name: str
    nationality: str = ""
    dob: str = ""
    position: str = ""
    clubs: str = ""
    wikidata_qid: str = ""
    transfermarkt_id: str = ""
    popularity: Popularity = field(default_factory=Popularity)
    merge_notes: list[str] = field(default_factory=list)

    def to_csv_row(self) -> dict[str, str]:
        pop = self.popularity
        return {
            "Player Name": self.name,
            "Nationality": self.nationality,
            "DOB": self.dob,
            "Position": self.position,
            "Senior Clubs Played For": self.clubs,
            "wikidata_qid": self.wikidata_qid,
            "transfermarkt_id": self.transfermarkt_id,
            "Popularity Rank": pop.rank,
            "Popularity Score": pop.score,
            "Popularity Tier": pop.tier,
            "Score Type": pop.score_type,
            "Confidence": pop.confidence,
            "Basis / Notes": pop.notes,
            "merge_notes": "; ".join(self.merge_notes),
        }


def normalize_name(value: str) -> str:
    value = (value or "").strip().lower()
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = re.sub(r"[^a-z0-9\s]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def canonical_name(name: str) -> str:
    key = normalize_name(name)
    return ALIAS_TO_CANONICAL.get(key, name.strip())


def parse_clubs(raw: str) -> list[str]:
    parts = re.split(r"[,;]", raw or "")
    return [part.strip() for part in parts if part.strip()]


def join_clubs(clubs: list[str]) -> str:
    seen: list[str] = []
    for club in clubs:
        if club not in seen:
            seen.append(club)
    return ", ".join(seen)


def is_missing_dob(dob: str) -> bool:
    token = (dob or "").strip().upper()
    return not token or token in {"TBD", "01/01/YYYY"}


def dob_key(dob: str) -> str:
    return "" if is_missing_dob(dob) else dob.strip()


def row_richness(row: PlayerRow) -> tuple[int, int, int]:
    """Higher is richer: has DOB, club count, nationality present."""
    return (
        0 if is_missing_dob(row.dob) else 1,
        len(parse_clubs(row.clubs)),
        1 if row.nationality.strip() else 0,
    )


def merge_player_rows(primary: PlayerRow, secondary: PlayerRow, note: str) -> PlayerRow:
    merged = PlayerRow(
        name=primary.name,
        nationality=primary.nationality or secondary.nationality,
        dob=primary.dob if not is_missing_dob(primary.dob) else secondary.dob,
        position=primary.position or secondary.position,
        clubs=join_clubs(parse_clubs(primary.clubs) + parse_clubs(secondary.clubs)),
        wikidata_qid=primary.wikidata_qid or secondary.wikidata_qid,
        transfermarkt_id=primary.transfermarkt_id or secondary.transfermarkt_id,
        popularity=primary.popularity,
        merge_notes=list(primary.merge_notes),
    )
    if secondary.popularity.is_better_than(merged.popularity):
        merged.popularity = secondary.popularity
    merged.merge_notes.append(note)
    return merged


def load_ranked_index() -> dict[str, list[tuple[dict[str, str], Popularity]]]:
    by_name: dict[str, list[tuple[dict[str, str], Popularity]]] = defaultdict(list)
    with RANKED_CSV.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            name = (row.get("Player Name") or "").strip()
            if not name:
                continue
            by_name[normalize_name(name)].append((row, Popularity.from_ranked_row(row)))
    return by_name


def pick_popularity(
    player: PlayerRow,
    candidates: list[tuple[dict[str, str], Popularity]],
) -> Popularity:
    if not candidates:
        return Popularity()
    if len(candidates) == 1:
        return candidates[0][1]

    pos = player.position.strip().upper()
    dob = dob_key(player.dob)
    clubs = set(parse_clubs(player.clubs))

    scored: list[tuple[int, Popularity]] = []
    for _row, pop in candidates:
        score = int(pop.score or 0)
        if dob and dob_key(_row.get("DOB", "")) == dob:
            score += 1000
        if pos and (_row.get("Position") or "").strip().upper() == pos:
            score += 100
        if clubs:
            score += len(clubs & set(parse_clubs(_row.get("Senior Clubs Played For", ""))))
        scored.append((score, pop))

    scored.sort(key=lambda item: item[0], reverse=True)
    return scored[0][1]


def identity_key(player: PlayerRow) -> tuple:
    """Distinguish same-name different people when DOB is known."""
    name = normalize_name(player.name)
    dob = dob_key(player.dob)
    pos = player.position.strip().upper()
    if dob:
        return (name, dob, pos)
    clubs = tuple(sorted(parse_clubs(player.clubs)))
    return (name, pos, clubs)


def load_master_with_popularity(
    ranked_by_name: dict[str, list[tuple[dict[str, str], Popularity]]],
) -> list[PlayerRow]:
    players: list[PlayerRow] = []
    with MASTER_CSV.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            name = canonical_name(row.get("Player Name") or "")
            player = PlayerRow(
                name=name,
                nationality=(row.get("Nationality") or "").strip(),
                dob=(row.get("DOB") or "").strip(),
                position=(row.get("Position") or "").strip(),
                clubs=(row.get("Senior Clubs Played For") or "").strip(),
                wikidata_qid=(row.get("wikidata_qid") or "").strip(),
            )
            if normalize_name(name) != normalize_name(row.get("Player Name") or ""):
                player.merge_notes.append(
                    f"alias_redirect:{(row.get('Player Name') or '').strip()}->{name}"
                )
            pop = pick_popularity(player, ranked_by_name.get(normalize_name(name), []))
            player.popularity = pop
            players.append(player)
    return players


def dedupe_alias_rows(players: list[PlayerRow]) -> tuple[list[PlayerRow], list[str]]:
    """Merge alias duplicate rows (Bencharki, Aboul Gabal) into canonical names."""
    by_canonical: dict[str, list[PlayerRow]] = defaultdict(list)
    for player in players:
        by_canonical[normalize_name(player.name)].append(player)

    merged: list[PlayerRow] = []
    notes: list[str] = []
    for _key, group in by_canonical.items():
        if len(group) == 1:
            merged.append(group[0])
            continue
        group.sort(key=row_richness, reverse=True)
        combined = group[0]
        for duplicate in group[1:]:
            combined = merge_player_rows(
                combined,
                duplicate,
                f"merged_duplicate:{duplicate.name}",
            )
            notes.append(f"Merged duplicate rows for {combined.name}")
        merged.append(combined)
    return merged, notes


def dedupe_identity_collisions(players: list[PlayerRow]) -> tuple[list[PlayerRow], list[str]]:
    """Keep intentional same-name different people separate via identity_key."""
    by_identity: dict[tuple, PlayerRow] = {}
    notes: list[str] = []
    for player in players:
        key = identity_key(player)
        if key not in by_identity:
            by_identity[key] = player
            continue
        by_identity[key] = merge_player_rows(
            by_identity[key],
            player,
            "merged_identical_profile",
        )
        notes.append(f"Merged identical profile key for {player.name}")
    return list(by_identity.values()), notes


def main() -> None:
    ranked_by_name = load_ranked_index()
    players = load_master_with_popularity(ranked_by_name)
    master_count = len(players)

    players, alias_notes = dedupe_alias_rows(players)
    players, identity_notes = dedupe_identity_collisions(players)

    players.sort(
        key=lambda p: (
            -int(p.popularity.score or 0),
            int(p.popularity.rank or 9999),
            p.name.lower(),
        )
    )

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(player.to_csv_row() for player in players)

    missing_dob = sum(1 for p in players if is_missing_dob(p.dob))
    missing_qid = sum(1 for p in players if not p.wikidata_qid.strip())
    missing_popularity = sum(1 for p in players if not p.popularity.score)

    report = {
        "master_rows": master_count,
        "ranked_rows": sum(len(v) for v in ranked_by_name.values()),
        "output_rows": len(players),
        "rows_removed_by_dedup": master_count - len(players),
        "missing_dob": missing_dob,
        "missing_wikidata_qid": missing_qid,
        "missing_popularity_score": missing_popularity,
        "alias_merge_notes": alias_notes,
        "identity_merge_notes": identity_notes,
        "output_csv": str(OUTPUT_CSV),
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {OUTPUT_CSV} ({len(players)} players)")
    print(f"  master rows: {master_count}")
    print(f"  removed by dedup: {master_count - len(players)}")
    print(f"  missing DOB: {missing_dob}")
    print(f"  missing wikidata_qid: {missing_qid}")
    print(f"  report: {REPORT_PATH}")


if __name__ == "__main__":
    main()
