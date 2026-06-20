#!/usr/bin/env python3
"""Phase 1 — ingest legendary players into staging/legendary/*.csv.

Reads legendary_players_with_tm_id.csv and emits club, nation, league, and position
edges for players that pass the D7 two-attribute qualification gate.
"""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import (  # noqa: E402
    NationResolver,
    REPORTS,
    collapse_whitespace,
    load_yaml,
    make_search_text,
)

ROOT = _ETL_DIR.parents[1]
CSV_PATH = ROOT / "legendary-players" / "legendary_players_with_tm_id.csv"
MANUAL_CLUB_FIXES = ROOT / "legendary-players" / "manual_club_fixes.csv"
STAGING_LEGENDARY = _ETL_DIR / "staging" / "legendary"
EXCLUDED_REPORT = ROOT / "legendary-players" / "reports" / "excluded_players.json"
SUMMARY_PATH = REPORTS / "ingest_legendary_summary.json"

DUAL_NATION_VALUE = "Argentina / Spain"
DUAL_NATION_SLUGS = ("argentina", "spain")

STRIPPED_NATION_SLUGS = frozenset(
    {
        "north_macedonia",
        "iran",
        "georgia",
        "paraguay",
        "zambia",
        "south_africa",
        "new_zealand",
        "montenegro",
    }
)

STRIPPED_NATION_DISPLAY = frozenset(
    {
        "North Macedonia",
        "Iran",
        "Georgia",
        "Paraguay",
        "Zambia",
        "South Africa",
        "New Zealand",
        "Montenegro",
    }
)

LEGENDARY_POSITION_BUCKETS = {
    "GK": "GK",
    "DEF": "DEF",
    "MID": "MID",
    "FWD": "FWD",
}

MIN_DISTINCT_ATTRIBUTES = 2
QUALIFYING_KINDS = frozenset({"club", "nation", "league", "pos"})

PROFILE_FIELDS = ("player_id", "display_name", "search_text", "nation_slug", "wikidata_qid")
CLUB_FIELDS = ("player_id", "club_id", "attribute_id", "source")
NATION_FIELDS = ("player_id", "nation_slug", "attribute_id", "source")
LEAGUE_FIELDS = ("player_id", "competition_id", "attribute_id", "source")
POSITION_FIELDS = ("player_id", "position_bucket", "attribute_id", "source")


@dataclass
class PlayerEdges:
    player_id: str
    display_name: str
    wikidata_qid: str
    nation_slug: str = ""
    club_ids: set[str] = field(default_factory=set)
    nation_slugs: set[str] = field(default_factory=set)
    league_ids: set[str] = field(default_factory=set)
    position_bucket: str = ""

    def attribute_ids(self) -> set[str]:
        attrs: set[str] = set()
        for club_id in self.club_ids:
            attrs.add(f"club:{club_id}")
        for slug in self.nation_slugs:
            attrs.add(f"nation:{slug}")
        for league_id in self.league_ids:
            attrs.add(f"league:{league_id}")
        if self.position_bucket:
            attrs.add(f"pos:{self.position_bucket}")
        return attrs

    def attribute_kinds(self) -> set[str]:
        kinds: set[str] = set()
        if self.club_ids:
            kinds.add("club")
        if self.nation_slugs:
            kinds.add("nation")
        if self.league_ids:
            kinds.add("league")
        if self.position_bucket:
            kinds.add("pos")
        return kinds

    def qualifies(self) -> bool:
        attrs = self.attribute_ids()
        if len(attrs) < MIN_DISTINCT_ATTRIBUTES:
            return False
        return bool(self.attribute_kinds() & QUALIFYING_KINDS)


def parse_clubs(raw: str) -> list[str]:
    return [part.strip() for part in (raw or "").split(",") if part.strip()]


def load_club_resolver() -> tuple[dict[str, str], dict[str, str]]:
    """Return (display_name→club_id, aliases)."""
    clubs_cfg = load_yaml("clubs_allowlist.yaml").get("clubs") or {}
    clubs = {str(name): str(club_id) for name, club_id in clubs_cfg.items()}
    aliases = dict(load_yaml("legendary_club_aliases.yaml").get("aliases") or {})
    return clubs, aliases


def resolve_club_id(
    club_name: str,
    clubs: dict[str, str],
    aliases: dict[str, str],
) -> str | None:
    canonical = aliases.get(club_name, club_name)
    if canonical in clubs:
        return clubs[canonical]
    if club_name in clubs:
        return clubs[club_name]
    return None


def load_top5_league_map() -> dict[str, str]:
    cfg = load_yaml("club_top5_league.yaml")
    return {str(k): str(v).upper() for k, v in (cfg.get("mapping") or {}).items()}


def load_manual_club_fixes() -> dict[str, list[str]]:
    """transfermarkt_id → extra club_ids from manual_club_fixes.csv and supplements yaml."""
    fixes: dict[str, list[str]] = defaultdict(list)

    if MANUAL_CLUB_FIXES.is_file():
        with MANUAL_CLUB_FIXES.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                tm_id = (row.get("transfermarkt_id") or "").strip()
                club_id = (row.get("club_id") or "").strip()
                if tm_id and club_id:
                    fixes[tm_id].append(club_id)

    supplements = load_yaml("legendary_club_supplements.yaml")
    for edge in supplements.get("edges") or []:
        raw_pid = str(edge.get("player_id") or "").strip().removeprefix("tm:")
        club_id = str(edge.get("club_id") or "").strip()
        if raw_pid and club_id:
            fixes[raw_pid].append(club_id)

    return fixes


def build_nation_resolver() -> NationResolver:
    nations_cfg = load_yaml("nations_allowlist.yaml").get("nations") or {}
    aliases_cfg = load_yaml("name_aliases.yaml").get("nations") or {}
    return NationResolver(nations_cfg, aliases_cfg)


def map_legendary_position(raw: str) -> str:
    token = collapse_whitespace(raw or "").upper()
    return LEGENDARY_POSITION_BUCKETS.get(token, "")


def resolve_nation_slugs(nationality: str, resolver: NationResolver) -> list[str]:
    nat = collapse_whitespace(nationality or "")
    if not nat:
        return []
    if nat == DUAL_NATION_VALUE:
        return list(DUAL_NATION_SLUGS)
    slug = resolver.resolve(nat)
    if not slug or slug in STRIPPED_NATION_SLUGS:
        return []
    return [slug]


def process_row(
    row: dict[str, str],
    *,
    clubs: dict[str, str],
    aliases: dict[str, str],
    top5_map: dict[str, str],
    resolver: NationResolver,
    manual_clubs: dict[str, list[str]],
    unmapped_clubs: dict[str, list[str]],
    unmapped_nations: list[dict[str, str]],
) -> PlayerEdges | None:
    tm_id = (row.get("transfermarkt_id") or "").strip()
    if not tm_id:
        return None

    display_name = collapse_whitespace(row.get("Player Name") or "")
    player = PlayerEdges(
        player_id=tm_id,
        display_name=display_name,
        wikidata_qid=(row.get("wikidata_qid") or "").strip(),
    )

    nationality = row.get("Nationality") or ""
    nation_slugs = resolve_nation_slugs(nationality, resolver)
    nat_clean = collapse_whitespace(nationality)
    if nat_clean and not nation_slugs and nat_clean not in STRIPPED_NATION_DISPLAY:
        unmapped_nations.append({"player": display_name, "nationality": nat_clean})
    player.nation_slugs.update(nation_slugs)
    if nation_slugs:
        player.nation_slug = nation_slugs[0]

    for club_name in parse_clubs(row.get("Senior Clubs Played For", "")):
        club_id = resolve_club_id(club_name, clubs, aliases)
        if not club_id:
            unmapped_clubs.setdefault(club_name, []).append(display_name)
            continue
        player.club_ids.add(club_id)

    for club_id in manual_clubs.get(tm_id, []):
        player.club_ids.add(club_id)

    for club_id in player.club_ids:
        league_id = top5_map.get(club_id)
        if league_id:
            player.league_ids.add(league_id)

    bucket = map_legendary_position(row.get("Position") or "")
    if bucket:
        player.position_bucket = bucket

    return player


def write_csv(path: Path, fieldnames: tuple[str, ...], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def ingest_rows(rows: list[dict[str, str]]) -> dict[str, object]:
    clubs, aliases = load_club_resolver()
    top5_map = load_top5_league_map()
    resolver = build_nation_resolver()
    manual_clubs = load_manual_club_fixes()

    unmapped_clubs: dict[str, list[str]] = {}
    unmapped_nations: list[dict[str, str]] = []
    included: list[PlayerEdges] = []
    excluded: list[dict[str, object]] = []
    dual_nation_players: list[str] = []

    for row in rows:
        player = process_row(
            row,
            clubs=clubs,
            aliases=aliases,
            top5_map=top5_map,
            resolver=resolver,
            manual_clubs=manual_clubs,
            unmapped_clubs=unmapped_clubs,
            unmapped_nations=unmapped_nations,
        )
        if player is None:
            continue

        if set(DUAL_NATION_SLUGS).issubset(player.nation_slugs):
            dual_nation_players.append(player.display_name)

        if player.qualifies():
            included.append(player)
        else:
            excluded.append(
                {
                    "player_name": player.display_name,
                    "transfermarkt_id": player.player_id,
                    "attribute_count": len(player.attribute_ids()),
                    "attributes": sorted(player.attribute_ids()),
                    "reason": "insufficient_attributes",
                }
            )

    profile_rows: list[dict[str, str]] = []
    club_rows: list[dict[str, str]] = []
    nation_rows: list[dict[str, str]] = []
    league_rows: list[dict[str, str]] = []
    position_rows: list[dict[str, str]] = []

    league_edge_count = 0
    zero_league_players = 0

    for player in sorted(included, key=lambda p: p.player_id):
        profile_rows.append(
            {
                "player_id": player.player_id,
                "display_name": player.display_name,
                "search_text": make_search_text(player.display_name),
                "nation_slug": player.nation_slug,
                "wikidata_qid": player.wikidata_qid,
            }
        )
        for club_id in sorted(player.club_ids):
            club_rows.append(
                {
                    "player_id": player.player_id,
                    "club_id": club_id,
                    "attribute_id": f"club:{club_id}",
                    "source": "legendary_career",
                }
            )
        for slug in sorted(player.nation_slugs):
            nation_rows.append(
                {
                    "player_id": player.player_id,
                    "nation_slug": slug,
                    "attribute_id": f"nation:{slug}",
                    "source": "legendary_citizenship",
                }
            )
        if not player.league_ids:
            zero_league_players += 1
        for league_id in sorted(player.league_ids):
            league_edge_count += 1
            league_rows.append(
                {
                    "player_id": player.player_id,
                    "competition_id": league_id,
                    "attribute_id": f"league:{league_id}",
                    "source": "league_club",
                }
            )
        if player.position_bucket:
            position_rows.append(
                {
                    "player_id": player.player_id,
                    "position_bucket": player.position_bucket,
                    "attribute_id": f"pos:{player.position_bucket}",
                    "source": "legendary_profile",
                }
            )

    write_csv(STAGING_LEGENDARY / "legendary_player_profiles.csv", PROFILE_FIELDS, profile_rows)
    write_csv(STAGING_LEGENDARY / "legendary_player_club.csv", CLUB_FIELDS, club_rows)
    write_csv(STAGING_LEGENDARY / "legendary_player_nation.csv", NATION_FIELDS, nation_rows)
    write_csv(STAGING_LEGENDARY / "legendary_player_league.csv", LEAGUE_FIELDS, league_rows)
    write_csv(STAGING_LEGENDARY / "legendary_player_position.csv", POSITION_FIELDS, position_rows)

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "csv_rows": len(rows),
        "included_preview": len(included),
        "excluded_insufficient_attributes": len(excluded),
        "dual_nation_players": sorted(dual_nation_players),
        "unmapped_clubs": sorted(unmapped_clubs.keys()),
        "unmapped_nations": unmapped_nations,
        "league_edges_added": league_edge_count,
        "players_with_zero_league": zero_league_players,
        "output_counts": {
            "profiles": len(profile_rows),
            "clubs": len(club_rows),
            "nations": len(nation_rows),
            "leagues": len(league_rows),
            "positions": len(position_rows),
        },
    }

    EXCLUDED_REPORT.parent.mkdir(parents=True, exist_ok=True)
    EXCLUDED_REPORT.write_text(
        json.dumps(
            {
                "excluded_count": len(excluded),
                "excluded_players": excluded,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    REPORTS.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    return summary


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"Missing {CSV_PATH}", file=sys.stderr)
        return 1

    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8")))
    summary = ingest_rows(rows)

    print(f"Ingested {summary['included_preview']} / {summary['csv_rows']} legendary players")
    print(f"Excluded (<2 attributes): {summary['excluded_insufficient_attributes']}")
    print(f"League edges: {summary['league_edges_added']}")
    print(f"Summary: {SUMMARY_PATH}")
    print(f"Excluded report: {EXCLUDED_REPORT}")

    if summary["unmapped_clubs"] or summary["unmapped_nations"]:
        print("Unmapped clubs:", summary["unmapped_clubs"], file=sys.stderr)
        print("Unmapped nations:", summary["unmapped_nations"], file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
