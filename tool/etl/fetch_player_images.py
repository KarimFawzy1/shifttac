#!/usr/bin/env python3
"""Phase D7b — resolve player image URLs from Wikidata (P2446 → P18 → Commons).

See docs/player-image-plan.md.

Inputs:
  tool/etl/staging/players_table.csv
  tool/etl/config/player_image_overrides.yaml   (optional)

Outputs:
  tool/etl/staging/player_images.csv
  tool/etl/reports/fetch_player_images_summary.json

Usage:
  python tool/etl/fetch_player_images.py
  python tool/etl/fetch_player_images.py --only-missing
  python tool/etl/fetch_player_images.py --limit 100
  python tool/etl/fetch_player_images.py --verify-urls
  python tool/etl/fetch_player_images.py --refresh
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import REPORTS  # noqa: E402
from player_image_url import (  # noqa: E402
    USER_AGENT,
    build_commons_thumbnail_url,
    commons_file_from_url,
    filename_from_p18_uri,
    is_valid_commons_image_url,
    ssl_context,
    tm_id,
    tm_numeric,
    verify_commons_image_url,
)

STAGING = _ETL_DIR / "staging"
CONFIG = _ETL_DIR / "config"
PLAYERS_TABLE_PATH = STAGING / "players_table.csv"
PLAYER_IMAGES_PATH = STAGING / "player_images.csv"
LEGENDARY_PROFILES_PATH = STAGING / "legendary" / "legendary_player_profiles.csv"
OVERRIDES_PATH = CONFIG / "player_image_overrides.yaml"
SUMMARY_PATH = REPORTS / "fetch_player_images_summary.json"
LEGENDARY_MISSES_PATH = REPORTS / "legendary_image_misses.json"

SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"
BATCH_SIZE = 400
BATCH_SLEEP_SECONDS = 1.0
MAX_RETRIES = 5
RETRY_BACKOFF_SECONDS = 2.0

PLAYER_IMAGES_FIELDS = ("player_id", "image_url", "commons_file")


@dataclass
class PlayerImageRow:
    player_id: str
    image_url: str
    commons_file: str


@dataclass
class FetchStats:
    total_players: int = 0
    processed_players: int = 0
    matched_wikidata: int = 0
    with_p18: int = 0
    written_rows: int = 0
    newly_resolved_count: int = 0
    legendary_total: int = 0
    legendary_matched_wikidata: int = 0
    legendary_with_image: int = 0
    legendary_qid_resolved: int = 0
    legendary_p2446_resolved: int = 0
    skipped: Counter[str] = field(default_factory=Counter)
    batch_errors: list[dict[str, Any]] = field(default_factory=list)
    verify_urls_enabled: bool = False
    only_missing: bool = False
    refresh: bool = False


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve Wikidata P2446/P18 Commons thumbnail URLs for Tiki-Taka players."
        ),
    )
    parser.add_argument(
        "--only-missing",
        action="store_true",
        help="Resolve only players not already present in player_images.csv.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help="Dev: process only the first N players from players_table.csv.",
    )
    parser.add_argument(
        "--verify-urls",
        action="store_true",
        help="GET each Commons URL and skip 404 / non-image responses.",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Full re-fetch unless combined with --only-missing.",
    )
    return parser


def normalize_qid(raw: str) -> str:
    qid = raw.strip()
    if qid.lower().startswith("wd:"):
        qid = qid[3:]
    qid = qid.upper()
    return qid if qid.startswith("Q") and qid[1:].isdigit() else ""


def load_legendary_qid_map(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}

    mapping: dict[str, str] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            player_id = tm_id(row.get("player_id", ""))
            qid = normalize_qid(row.get("wikidata_qid") or "")
            if player_id and qid:
                mapping[player_id] = qid
    return mapping


def load_included_legendary_ids(
    players_table_path: Path,
    legendary_profiles_path: Path,
) -> set[str]:
    if not legendary_profiles_path.is_file():
        return set()

    legendary_ids = {
        tm_id(row.get("player_id", ""))
        for row in csv.DictReader(legendary_profiles_path.open(encoding="utf-8"))
        if (row.get("player_id") or "").strip()
    }
    if not players_table_path.is_file():
        return set()

    table_ids = {
        tm_id(row.get("id", ""))
        for row in csv.DictReader(players_table_path.open(encoding="utf-8"))
        if (row.get("id") or "").strip()
    }
    return legendary_ids & table_ids


def partition_targets_by_qid(
    target_ids: list[str],
    qid_map: dict[str, str],
) -> tuple[list[tuple[str, str]], list[str]]:
    qid_targets: list[tuple[str, str]] = []
    p2446_targets: list[str] = []
    for player_id in target_ids:
        qid = qid_map.get(player_id, "")
        if qid:
            qid_targets.append((player_id, qid))
        else:
            p2446_targets.append(player_id)
    return qid_targets, p2446_targets


def load_player_ids(path: Path, *, limit: int | None) -> list[str]:
    if not path.is_file():
        raise FileNotFoundError(f"Missing input: {path}")

    ids: list[str] = []
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            raw_id = (row.get("id") or "").strip()
            if not raw_id:
                continue
            ids.append(tm_id(raw_id))
            if limit is not None and len(ids) >= limit:
                break
    return ids


def load_existing_rows(path: Path) -> dict[str, PlayerImageRow]:
    if not path.is_file():
        return {}

    rows: dict[str, PlayerImageRow] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            player_id = tm_id(row.get("player_id", ""))
            image_url = (row.get("image_url") or "").strip()
            if not player_id or not image_url:
                continue
            commons_file = (row.get("commons_file") or "").strip() or commons_file_from_url(
                image_url
            )
            rows[player_id] = PlayerImageRow(
                player_id=player_id,
                image_url=image_url,
                commons_file=commons_file,
            )
    return rows


def select_target_ids(
    all_ids: list[str],
    existing: dict[str, PlayerImageRow],
    *,
    only_missing: bool,
    refresh: bool,
) -> list[str]:
    if refresh and not only_missing:
        return list(all_ids)
    if only_missing:
        return [player_id for player_id in all_ids if player_id not in existing]
    return list(all_ids)


def load_overrides(path: Path) -> dict[str, PlayerImageRow]:
    if not path.is_file():
        return {}

    try:
        import yaml
    except ImportError as exc:
        raise SystemExit("Install PyYAML: pip install pyyaml") from exc

    with path.open(encoding="utf-8") as handle:
        raw = yaml.safe_load(handle) or {}

    if not isinstance(raw, dict):
        return {}

    overrides: dict[str, PlayerImageRow] = {}
    for key, value in raw.items():
        if not isinstance(value, dict):
            continue
        player_id = tm_id(str(key))
        image_url = str(value.get("url") or "").strip()
        if not image_url:
            continue
        if not is_valid_commons_image_url(image_url):
            continue
        commons_file = str(value.get("commons_file") or "").strip() or commons_file_from_url(
            image_url
        )
        overrides[player_id] = PlayerImageRow(
            player_id=player_id,
            image_url=image_url,
            commons_file=commons_file,
        )
    return overrides


def build_qid_sparql_query(qids: list[str]) -> str:
    values = " ".join(f"wd:{qid}" for qid in qids)
    return f"""
SELECT ?item ?image WHERE {{
  VALUES ?item {{ {values} }}
  OPTIONAL {{ ?item wdt:P18 ?image . }}
}}
""".strip()


def entity_uri_to_qid(entity_uri: str) -> str:
    return normalize_qid(entity_uri.rstrip("/").rsplit("/", 1)[-1])


def fetch_qid_sparql_batch(
    qids: list[str],
    *,
    batch_index: int,
) -> tuple[set[str], dict[str, str | None]]:
    query = build_qid_sparql_query(qids)
    body = urllib.parse.urlencode({"query": query}).encode("utf-8")
    request = urllib.request.Request(
        SPARQL_ENDPOINT,
        data=body,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/sparql-results+json",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )

    last_error: Exception | None = None
    payload: dict[str, Any] | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with urllib.request.urlopen(request, timeout=90, context=ssl_context()) as response:
                payload = json.load(response)
            break
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code == 429 and attempt < MAX_RETRIES:
                retry_after = exc.headers.get("Retry-After")
                try:
                    wait_seconds = float(retry_after) if retry_after else 65.0
                except ValueError:
                    wait_seconds = 65.0
                time.sleep(max(wait_seconds, 1.0))
                continue
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
    if payload is None:
        raise RuntimeError(
            f"QID SPARQL batch {batch_index} failed after {MAX_RETRIES} attempts: {last_error}"
        )

    found_qids: set[str] = set()
    results: dict[str, str | None] = {qid: None for qid in qids}
    bindings = payload.get("results", {}).get("bindings", [])
    if not isinstance(bindings, list):
        raise RuntimeError(f"QID SPARQL batch {batch_index} returned unexpected JSON shape")

    for binding in bindings:
        if not isinstance(binding, dict):
            continue
        item_binding = binding.get("item")
        if not isinstance(item_binding, dict):
            continue
        qid = entity_uri_to_qid(str(item_binding.get("value") or ""))
        if not qid or qid not in results:
            continue
        found_qids.add(qid)
        image_binding = binding.get("image")
        image_uri = image_binding.get("value") if isinstance(image_binding, dict) else None
        if image_uri:
            results[qid] = str(image_uri)
    return found_qids, results


def build_sparql_query(tm_ids: list[str]) -> str:
    values = " ".join(f'"{tm_numeric(player_id)}"' for player_id in tm_ids)
    return f"""
SELECT ?tmId ?image WHERE {{
  VALUES ?tmId {{ {values} }}
  ?item wdt:P2446 ?tmId .
  OPTIONAL {{ ?item wdt:P18 ?image . }}
}}
""".strip()


def fetch_sparql_batch(tm_ids: list[str], *, batch_index: int) -> dict[str, str | None]:
    query = build_sparql_query(tm_ids)
    body = urllib.parse.urlencode({"query": query}).encode("utf-8")
    request = urllib.request.Request(
        SPARQL_ENDPOINT,
        data=body,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/sparql-results+json",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )

    last_error: Exception | None = None
    payload: dict[str, Any] | None = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with urllib.request.urlopen(request, timeout=90, context=ssl_context()) as response:
                payload = json.load(response)
            break
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code == 429 and attempt < MAX_RETRIES:
                retry_after = exc.headers.get("Retry-After")
                try:
                    wait_seconds = float(retry_after) if retry_after else 65.0
                except ValueError:
                    wait_seconds = 65.0
                time.sleep(max(wait_seconds, 1.0))
                continue
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
    if payload is None:
        raise RuntimeError(
            f"SPARQL batch {batch_index} failed after {MAX_RETRIES} attempts: {last_error}"
        )

    results: dict[str, str | None] = {}
    bindings = payload.get("results", {}).get("bindings", [])
    if not isinstance(bindings, list):
        raise RuntimeError(f"SPARQL batch {batch_index} returned unexpected JSON shape")

    for binding in bindings:
        if not isinstance(binding, dict):
            continue
        tm_value = binding.get("tmId", {}).get("value")
        if tm_value is None:
            continue
        tm_key = str(tm_value)
        if tm_key in results:
            continue
        image_binding = binding.get("image")
        image_uri = image_binding.get("value") if isinstance(image_binding, dict) else None
        results[tm_key] = str(image_uri) if image_uri else None
    return results


def resolve_url_from_p18(p18_uri: str, stats: FetchStats, *, verify_urls: bool) -> str | None:
    try:
        filename = filename_from_p18_uri(p18_uri)
    except Exception:
        stats.skipped["invalid_filename"] += 1
        return None

    if not filename:
        stats.skipped["invalid_filename"] += 1
        return None

    url = build_commons_thumbnail_url(filename)
    if not is_valid_commons_image_url(url):
        stats.skipped["invalid_url"] += 1
        return None

    if verify_urls and not verify_commons_image_url(url):
        stats.skipped["commons_not_found"] += 1
        return None

    return url


def resolve_qid_images(
    qid_targets: list[tuple[str, str]],
    stats: FetchStats,
    *,
    verify_urls: bool,
    included_legendary_ids: set[str] | None = None,
) -> dict[str, PlayerImageRow]:
    if not qid_targets:
        return {}

    resolved: dict[str, PlayerImageRow] = {}
    qids = [qid for _, qid in qid_targets]
    player_by_qid = {qid: player_id for player_id, qid in qid_targets}

    successful_batches = 0
    for batch_index, start in enumerate(range(0, len(qids), BATCH_SIZE)):
        batch_qids = qids[start : start + BATCH_SIZE]
        try:
            found_qids, batch_results = fetch_qid_sparql_batch(batch_qids, batch_index=batch_index)
            successful_batches += 1
        except RuntimeError as exc:
            stats.batch_errors.append(
                {
                    "batch_index": batch_index,
                    "player_count": len(batch_qids),
                    "resolver": "wikidata_qid_p18",
                    "error": str(exc),
                }
            )
            stats.skipped["batch_failed"] += len(batch_qids)
            continue

        if batch_index > 0:
            time.sleep(BATCH_SLEEP_SECONDS)

        for qid in batch_qids:
            player_id = player_by_qid[qid]
            is_legendary = included_legendary_ids is not None and player_id in included_legendary_ids
            if qid not in found_qids:
                stats.skipped["no_wikidata"] += 1
                continue

            stats.matched_wikidata += 1
            if is_legendary:
                stats.legendary_matched_wikidata += 1
                stats.legendary_qid_resolved += 1

            p18_uri = batch_results.get(qid)
            if not p18_uri:
                stats.skipped["no_p18"] += 1
                continue

            stats.with_p18 += 1
            url = resolve_url_from_p18(p18_uri, stats, verify_urls=verify_urls)
            if not url:
                continue

            filename = commons_file_from_url(url) or filename_from_p18_uri(p18_uri)
            resolved[player_id] = PlayerImageRow(
                player_id=player_id,
                image_url=url,
                commons_file=filename,
            )

    if qid_targets and successful_batches == 0:
        raise RuntimeError("All QID SPARQL batches failed; no Wikidata results fetched")

    return resolved


def resolve_wikidata_images(
    target_ids: list[str],
    stats: FetchStats,
    *,
    verify_urls: bool,
    included_legendary_ids: set[str] | None = None,
) -> dict[str, PlayerImageRow]:
    resolved: dict[str, PlayerImageRow] = {}
    numeric_targets = [tm_numeric(player_id) for player_id in target_ids]
    id_by_numeric = {tm_numeric(player_id): player_id for player_id in target_ids}

    successful_batches = 0
    for batch_index, start in enumerate(range(0, len(numeric_targets), BATCH_SIZE)):
        batch_numeric = numeric_targets[start : start + BATCH_SIZE]

        try:
            batch_results = fetch_sparql_batch(batch_numeric, batch_index=batch_index)
            successful_batches += 1
        except RuntimeError as exc:
            stats.batch_errors.append(
                {
                    "batch_index": batch_index,
                    "player_count": len(batch_numeric),
                    "error": str(exc),
                }
            )
            stats.skipped["batch_failed"] += len(batch_numeric)
            continue

        if batch_index > 0:
            time.sleep(BATCH_SLEEP_SECONDS)

        for numeric in batch_numeric:
            player_id = id_by_numeric[numeric]
            is_legendary = included_legendary_ids is not None and player_id in included_legendary_ids
            if numeric not in batch_results:
                stats.skipped["no_wikidata"] += 1
                continue

            stats.matched_wikidata += 1
            if is_legendary:
                stats.legendary_matched_wikidata += 1
                stats.legendary_p2446_resolved += 1
            p18_uri = batch_results[numeric]
            if not p18_uri:
                stats.skipped["no_p18"] += 1
                continue

            stats.with_p18 += 1
            try:
                url = resolve_url_from_p18(p18_uri, stats, verify_urls=verify_urls)
            except Exception:
                stats.skipped["invalid_filename"] += 1
                continue

            if not url:
                continue

            filename = commons_file_from_url(url) or filename_from_p18_uri(p18_uri)
            resolved[player_id] = PlayerImageRow(
                player_id=player_id,
                image_url=url,
                commons_file=filename,
            )

    if target_ids and successful_batches == 0:
        raise RuntimeError("All SPARQL batches failed; no Wikidata results fetched")

    return resolved


def apply_overrides(
    rows: dict[str, PlayerImageRow],
    overrides: dict[str, PlayerImageRow],
    stats: FetchStats,
    *,
    verify_urls: bool,
) -> None:
    for player_id, override in overrides.items():
        if verify_urls and not verify_commons_image_url(override.image_url):
            stats.skipped["commons_not_found"] += 1
            continue
        rows[player_id] = override


def write_player_images(path: Path, rows: dict[str, PlayerImageRow]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    sorted_rows = sorted(rows.values(), key=lambda row: row.player_id)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=PLAYER_IMAGES_FIELDS)
        writer.writeheader()
        for row in sorted_rows:
            writer.writerow(
                {
                    "player_id": row.player_id,
                    "image_url": row.image_url,
                    "commons_file": row.commons_file,
                }
            )
    return len(sorted_rows)


def count_legendary_with_image(
    included_legendary_ids: set[str],
    rows: dict[str, PlayerImageRow],
) -> int:
    return sum(1 for player_id in included_legendary_ids if player_id in rows)


def write_legendary_misses(
    path: Path,
    *,
    included_legendary_ids: set[str],
    rows: dict[str, PlayerImageRow],
    qid_map: dict[str, str],
    profile_names: dict[str, str],
) -> None:
    misses: list[dict[str, str]] = []
    for player_id in sorted(included_legendary_ids, key=tm_numeric):
        if player_id in rows:
            continue
        misses.append(
            {
                "player_id": player_id,
                "display_name": profile_names.get(player_id, ""),
                "wikidata_qid": qid_map.get(player_id, ""),
            }
        )

    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "reported_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "legendary_total": len(included_legendary_ids),
        "legendary_with_image": len(included_legendary_ids) - len(misses),
        "miss_count": len(misses),
        "misses": misses,
    }
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def load_legendary_profile_names(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    return {
        tm_id(row.get("player_id", "")): (row.get("display_name") or "").strip()
        for row in csv.DictReader(path.open(encoding="utf-8"))
        if (row.get("player_id") or "").strip()
    }


def write_summary(path: Path, stats: FetchStats) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    legendary_match_rate = (
        stats.legendary_with_image / stats.legendary_total
        if stats.legendary_total
        else 0.0
    )
    legendary_image_rate = legendary_match_rate
    payload = {
        "fetched_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "total_players": stats.total_players,
        "processed_players": stats.processed_players,
        "matched_wikidata": stats.matched_wikidata,
        "with_p18": stats.with_p18,
        "written_rows": stats.written_rows,
        "newly_resolved_count": stats.newly_resolved_count,
        "legendary": {
            "total": stats.legendary_total,
            "matched_wikidata": stats.legendary_matched_wikidata,
            "with_image": stats.legendary_with_image,
            "match_rate": round(legendary_match_rate, 4),
            "image_rate": round(legendary_image_rate, 4),
            "qid_resolved": stats.legendary_qid_resolved,
            "p2446_resolved": stats.legendary_p2446_resolved,
        },
        "skipped": dict(sorted(stats.skipped.items())),
        "batch_errors": stats.batch_errors,
        "verify_urls_enabled": stats.verify_urls_enabled,
        "only_missing": stats.only_missing,
        "refresh": stats.refresh,
        "player_image_source": "wikidata_p2446_p18_and_qid_fast_path",
    }
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")


def run(args: argparse.Namespace) -> int:
    stats = FetchStats(
        verify_urls_enabled=args.verify_urls,
        only_missing=args.only_missing,
        refresh=args.refresh,
    )

    all_ids = load_player_ids(PLAYERS_TABLE_PATH, limit=args.limit)
    stats.total_players = len(all_ids)
    if not all_ids:
        print("fetch_player_images FAILED: no players in players_table.csv", file=sys.stderr)
        return 1

    existing = load_existing_rows(PLAYER_IMAGES_PATH)
    if args.refresh and not args.only_missing:
        existing = {}

    qid_map = load_legendary_qid_map(LEGENDARY_PROFILES_PATH)
    included_legendary_ids = load_included_legendary_ids(
        PLAYERS_TABLE_PATH,
        LEGENDARY_PROFILES_PATH,
    )
    profile_names = load_legendary_profile_names(LEGENDARY_PROFILES_PATH)
    stats.legendary_total = len(included_legendary_ids)

    target_ids = select_target_ids(
        all_ids,
        existing,
        only_missing=args.only_missing,
        refresh=args.refresh,
    )
    stats.processed_players = len(target_ids)

    merged: dict[str, PlayerImageRow] = dict(existing)
    if target_ids:
        qid_targets, p2446_targets = partition_targets_by_qid(target_ids, qid_map)
        if qid_targets:
            fetched_qid = resolve_qid_images(
                qid_targets,
                stats,
                verify_urls=args.verify_urls,
                included_legendary_ids=included_legendary_ids,
            )
            for player_id, row in fetched_qid.items():
                if player_id not in existing:
                    stats.newly_resolved_count += 1
                merged[player_id] = row
        if p2446_targets:
            fetched_p2446 = resolve_wikidata_images(
                p2446_targets,
                stats,
                verify_urls=args.verify_urls,
                included_legendary_ids=included_legendary_ids,
            )
            for player_id, row in fetched_p2446.items():
                if player_id not in existing:
                    stats.newly_resolved_count += 1
                merged[player_id] = row

    overrides = load_overrides(OVERRIDES_PATH)
    apply_overrides(merged, overrides, stats, verify_urls=args.verify_urls)

    stats.legendary_with_image = count_legendary_with_image(included_legendary_ids, merged)
    stats.written_rows = write_player_images(PLAYER_IMAGES_PATH, merged)
    write_legendary_misses(
        LEGENDARY_MISSES_PATH,
        included_legendary_ids=included_legendary_ids,
        rows=merged,
        qid_map=qid_map,
        profile_names=profile_names,
    )
    write_summary(SUMMARY_PATH, stats)

    print(
        "fetch_player_images OK: "
        f"{stats.written_rows:,} rows written "
        f"({stats.newly_resolved_count:,} newly resolved this run)"
    )
    if stats.legendary_total:
        print(
            f"  legendary: {stats.legendary_with_image}/{stats.legendary_total} with images "
            f"(matched_wikidata={stats.legendary_matched_wikidata})"
        )
    print(f"  output:  {PLAYER_IMAGES_PATH}")
    print(f"  summary: {SUMMARY_PATH}")
    print(
        "  skipped: "
        + ", ".join(f"{key}={count}" for key, count in sorted(stats.skipped.items()))
        if stats.skipped
        else "  skipped: none"
    )
    if stats.batch_errors:
        print(f"  batch_errors: {len(stats.batch_errors)}", file=sys.stderr)

    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return run(args)
    except FileNotFoundError as exc:
        print(f"fetch_player_images FAILED: {exc}", file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(f"fetch_player_images FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
