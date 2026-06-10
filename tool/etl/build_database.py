#!/usr/bin/env python3
"""Phase D11 — export staging CSVs to tiki_taka.db + manifest.

Writes:
  tool/etl/output/tiki_taka.db
  tool/etl/output/manifest.json
  assets/db/tiki_taka.db  (copy for Flutter)

Exit 1 if required staging files are missing.
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
import shutil
import sqlite3
import sys
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

_ETL_DIR = Path(__file__).resolve().parent
if str(_ETL_DIR) not in sys.path:
    sys.path.insert(0, str(_ETL_DIR))

from etl_common import DATASETS, REPORTS, ROOT, load_yaml  # noqa: E402
from player_image_url import is_valid_commons_image_url  # noqa: E402

STAGING = _ETL_DIR / "staging"
OUTPUT_DIR = _ETL_DIR / "output"
DB_PATH = OUTPUT_DIR / "tiki_taka.db"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
ASSET_DB_PATH = ROOT / "assets" / "db" / "tiki_taka.db"
PLAYER_IMAGE_SUMMARY_PATH = REPORTS / "fetch_player_images_summary.json"

SCHEMA_VERSION = 3
MAX_DB_BYTES = 20 * 1024 * 1024

PLAYER_IMAGE_SOURCE = "wikidata_p2446_p18"
PLAYER_IMAGES_PATH = STAGING / "player_images.csv"

SOURCE_CSV_FILES = (
    "players.csv",
    "clubs.csv",
    "competitions.csv",
    "countries.csv",
    "transfers.csv",
    "appearances.csv",
    "national_teams.csv",
)

REQUIRED_STAGING = (
    "players_table.csv",
    "player_attributes.csv",
    "player_aliases.csv",
    "attribute_pair_stats.csv",
    "boards.csv",
    "board_slots.csv",
    "attributes_nation.csv",
    "attributes_position.csv",
)

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def tm_id(raw: str) -> str:
    raw = raw.strip()
    return raw if raw.startswith("tm:") else f"tm:{raw}"


def nullable_text(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


def load_player_image_urls() -> dict[str, str]:
    """Load optional D7b staging map: player_id -> image_url."""
    if not PLAYER_IMAGES_PATH.is_file():
        return {}

    urls: dict[str, str] = {}
    with PLAYER_IMAGES_PATH.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            player_id = tm_id(row.get("player_id", ""))
            image_url = nullable_text(row.get("image_url"))
            if player_id and image_url and is_valid_commons_image_url(image_url):
                urls[player_id] = image_url
    return urls


def transform_player_row(
    row: dict[str, str],
    image_urls: dict[str, str],
) -> tuple:
    player_id = tm_id(row["id"])
    image_url = nullable_text(row.get("image_url")) or image_urls.get(player_id)
    if image_url and not is_valid_commons_image_url(image_url):
        image_url = None
    search_rank = int((row.get("search_rank") or "0").strip() or 0)
    return (
        player_id,
        row["display_name"],
        row["search_text"],
        nullable_text(row.get("position")),
        nullable_text(row.get("nation")),
        image_url,
        search_rank,
    )


def slugify(value: str) -> str:
    text = _SLUG_RE.sub("_", value.lower()).strip("_")
    return text or "unknown"


def compute_source_csv_hash() -> str:
    """Fingerprint input includes TM CSVs and optional player_images.csv."""
    digest = hashlib.sha256()
    for name in SOURCE_CSV_FILES:
        path = DATASETS / name
        if not path.is_file():
            raise FileNotFoundError(f"Missing source CSV for hash: {path}")
        digest.update(name.encode("utf-8"))
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
    if PLAYER_IMAGES_PATH.is_file():
        digest.update(b"player_images.csv")
        with PLAYER_IMAGES_PATH.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def load_player_images_fetched_at(fallback: str) -> str:
    if not PLAYER_IMAGE_SUMMARY_PATH.is_file():
        return fallback
    try:
        with PLAYER_IMAGE_SUMMARY_PATH.open(encoding="utf-8") as handle:
            payload = json.load(handle)
        fetched_at = payload.get("fetched_at")
        if isinstance(fetched_at, str) and fetched_at.strip():
            return fetched_at.strip()
    except (OSError, json.JSONDecodeError):
        pass
    return fallback


def require_staging() -> list[str]:
    return [name for name in REQUIRED_STAGING if not (STAGING / name).is_file()]


def build_club_attributes() -> list[tuple]:
    rows: list[tuple] = []
    clubs = load_yaml("clubs_allowlist.yaml").get("clubs") or {}
    for display_name, club_id in clubs.items():
        cid = str(club_id)
        attr_id = f"club:{cid}"
        rows.append(
            (
                attr_id,
                "club",
                display_name,
                f"club_{cid}",
                cid,
                f"club_{cid}",
            )
        )
    return rows


def build_league_attributes() -> list[tuple]:
    rows: list[tuple] = []
    leagues = load_yaml("leagues_allowlist.yaml").get("leagues") or {}
    for display_name, comp_id in leagues.items():
        comp = str(comp_id).upper()
        attr_id = f"league:{comp}"
        rows.append(
            (
                attr_id,
                "league",
                display_name,
                comp.lower(),
                comp,
                f"league_{comp.lower()}",
            )
        )
    return rows


def load_attribute_csv(path: Path) -> list[tuple]:
    rows: list[tuple] = []
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            rows.append(
                (
                    row["id"],
                    row["type"],
                    row["display_name"],
                    row["slug"],
                    row.get("source_id") or "",
                    row.get("icon_key") or "",
                )
            )
    return rows


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE attributes (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            display_name TEXT NOT NULL,
            slug TEXT NOT NULL UNIQUE,
            source_id TEXT,
            icon_key TEXT
        );

        CREATE TABLE players (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            search_text TEXT NOT NULL,
            position TEXT,
            nation TEXT,
            image_url TEXT,
            search_rank INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE player_attributes (
            player_id TEXT NOT NULL,
            attribute_id TEXT NOT NULL,
            source TEXT NOT NULL,
            PRIMARY KEY (player_id, attribute_id, source),
            FOREIGN KEY (player_id) REFERENCES players(id),
            FOREIGN KEY (attribute_id) REFERENCES attributes(id)
        );

        CREATE TABLE player_aliases (
            player_id TEXT NOT NULL,
            alias TEXT NOT NULL,
            PRIMARY KEY (player_id, alias),
            FOREIGN KEY (player_id) REFERENCES players(id)
        );

        CREATE TABLE attribute_pair_stats (
            attr_a TEXT NOT NULL,
            attr_b TEXT NOT NULL,
            player_count INTEGER NOT NULL,
            sample_player_ids TEXT NOT NULL,
            PRIMARY KEY (attr_a, attr_b)
        );

        CREATE TABLE boards (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            min_intersection INTEGER NOT NULL
        );

        CREATE TABLE board_slots (
            board_id TEXT NOT NULL,
            slot_kind TEXT NOT NULL,
            slot_index INTEGER NOT NULL,
            attribute_id TEXT NOT NULL,
            PRIMARY KEY (board_id, slot_kind, slot_index),
            FOREIGN KEY (board_id) REFERENCES boards(id),
            FOREIGN KEY (attribute_id) REFERENCES attributes(id)
        );

        CREATE INDEX idx_pa_attribute ON player_attributes(attribute_id);
        CREATE INDEX idx_pa_player ON player_attributes(player_id);
        CREATE INDEX idx_alias ON player_aliases(alias);
        CREATE INDEX idx_players_search_rank ON players(search_rank DESC);
        CREATE INDEX idx_pair ON attribute_pair_stats(attr_a, attr_b);
        """
    )


def import_csv(
    connection: sqlite3.Connection,
    table: str,
    columns: list[str],
    path: Path,
    transform: Callable[[dict[str, str]], tuple] | None = None,
) -> int:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        batch: list[tuple] = []
        count = 0
        placeholders = ",".join("?" for _ in columns)
        sql = f"INSERT INTO {table} ({','.join(columns)}) VALUES ({placeholders})"
        for row in reader:
            values = transform(row) if transform else tuple(row[col] for col in columns)
            batch.append(values)
            if len(batch) >= 5000:
                connection.executemany(sql, batch)
                count += len(batch)
                batch.clear()
        if batch:
            connection.executemany(sql, batch)
            count += len(batch)
    return count


def export_database() -> dict[str, int]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    build_path = OUTPUT_DIR / "tiki_taka.building.db"
    if build_path.exists():
        build_path.unlink()

    connection = sqlite3.connect(build_path)
    try:
        connection.execute("PRAGMA journal_mode = DELETE")
        create_schema(connection)

        attribute_rows = (
            build_club_attributes()
            + build_league_attributes()
            + load_attribute_csv(STAGING / "attributes_nation.csv")
            + load_attribute_csv(STAGING / "attributes_position.csv")
        )
        connection.executemany(
            """
            INSERT INTO attributes (id, type, display_name, slug, source_id, icon_key)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            attribute_rows,
        )

        image_urls = load_player_image_urls()
        player_count = import_csv(
            connection,
            "players",
            [
                "id",
                "display_name",
                "search_text",
                "position",
                "nation",
                "image_url",
                "search_rank",
            ],
            STAGING / "players_table.csv",
            transform=lambda row: transform_player_row(row, image_urls),
        )
        players_with_image_count = connection.execute(
            "SELECT COUNT(*) FROM players WHERE image_url IS NOT NULL"
        ).fetchone()[0]

        def transform_player_attributes(row: dict[str, str]) -> tuple:
            return (
                tm_id(row["player_id"]),
                row["attribute_id"],
                row["source"],
            )

        edge_count = import_csv(
            connection,
            "player_attributes",
            ["player_id", "attribute_id", "source"],
            STAGING / "player_attributes.csv",
            transform=transform_player_attributes,
        )

        def transform_aliases(row: dict[str, str]) -> tuple:
            return (tm_id(row["player_id"]), row["alias"])

        alias_count = import_csv(
            connection,
            "player_aliases",
            ["player_id", "alias"],
            STAGING / "player_aliases.csv",
            transform=transform_aliases,
        )

        pair_count = import_csv(
            connection,
            "attribute_pair_stats",
            ["attr_a", "attr_b", "player_count", "sample_player_ids"],
            STAGING / "attribute_pair_stats.csv",
            transform=lambda row: (
                row["attr_a"],
                row["attr_b"],
                int(row["player_count"]),
                row["sample_player_ids"],
            ),
        )

        board_count = import_csv(
            connection,
            "boards",
            ["id", "name", "min_intersection"],
            STAGING / "boards.csv",
            transform=lambda row: (
                row["id"],
                row["name"],
                int(row["min_intersection"]),
            ),
        )

        slot_count = import_csv(
            connection,
            "board_slots",
            ["board_id", "slot_kind", "slot_index", "attribute_id"],
            STAGING / "board_slots.csv",
            transform=lambda row: (
                row["board_id"],
                row["slot_kind"],
                int(row["slot_index"]),
                row["attribute_id"],
            ),
        )

        built_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        source_hash = compute_source_csv_hash()
        player_images_fetched_at = load_player_images_fetched_at(built_at)
        meta_rows = [
            ("schema_version", str(SCHEMA_VERSION)),
            ("built_at", built_at),
            ("source_csv_hash", source_hash),
            ("player_image_source", PLAYER_IMAGE_SOURCE),
            ("player_images_fetched_at", player_images_fetched_at),
        ]
        connection.executemany("INSERT INTO meta (key, value) VALUES (?, ?)", meta_rows)
        connection.commit()

        counts = {
            "attribute_count": len(attribute_rows),
            "player_count": player_count,
            "players_with_image_count": players_with_image_count,
            "player_attribute_rows": edge_count,
            "player_alias_rows": alias_count,
            "attribute_pair_stats_rows": pair_count,
            "board_count": board_count,
            "board_slot_rows": slot_count,
        }
    finally:
        connection.close()

    vacuum_conn = sqlite3.connect(build_path)
    try:
        vacuum_conn.execute("VACUUM")
    finally:
        vacuum_conn.close()

    final_db = DB_PATH
    if final_db.exists():
        try:
            final_db.unlink()
        except OSError:
            final_db = OUTPUT_DIR / "tiki_taka_new.db"
    shutil.move(str(build_path), str(final_db))
    if final_db != DB_PATH:
        shutil.copy2(final_db, DB_PATH)

    return counts, built_at, source_hash, player_images_fetched_at


def write_manifest(
    built_at: str,
    source_hash: str,
    counts: dict[str, int],
    *,
    player_images_fetched_at: str,
) -> None:
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "built_at": built_at,
        "source_csv_hash": source_hash,
        "player_count": counts["player_count"],
        "players_with_image_count": counts.get("players_with_image_count", 0),
        "player_image_source": PLAYER_IMAGE_SOURCE,
        "player_images_fetched_at": player_images_fetched_at,
        "attribute_count": counts["attribute_count"],
        "board_count": counts["board_count"],
        "player_attribute_rows": counts["player_attribute_rows"],
        "player_alias_rows": counts["player_alias_rows"],
        "attribute_pair_stats_rows": counts["attribute_pair_stats_rows"],
        "db_path": "assets/db/tiki_taka.db",
        "file_size_bytes": DB_PATH.stat().st_size if DB_PATH.is_file() else 0,
    }
    with MANIFEST_PATH.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")


def verify_readonly_open(db_path: Path) -> None:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    connection = sqlite3.connect(uri, uri=True)
    try:
        players = connection.execute("SELECT COUNT(*) FROM players").fetchone()[0]
        if players <= 0:
            raise ValueError("players table is empty")
    finally:
        connection.close()


def main() -> int:
    missing = require_staging()
    if missing:
        print("D11 export FAILED: missing staging files (run D7–D10):", file=sys.stderr)
        for name in missing:
            print(f"  - {STAGING / name}", file=sys.stderr)
        return 1

    try:
        counts, built_at, source_hash, player_images_fetched_at = export_database()
    except FileNotFoundError as exc:
        print(f"D11 export FAILED: {exc}", file=sys.stderr)
        return 1

    shutil.copy2(DB_PATH, ASSET_DB_PATH)
    write_manifest(
        built_at,
        source_hash,
        counts,
        player_images_fetched_at=player_images_fetched_at,
    )
    verify_readonly_open(ASSET_DB_PATH)

    size_bytes = DB_PATH.stat().st_size
    size_mb = size_bytes / (1024 * 1024)

    update_pubspec_asset_entry()

    errors: list[str] = []
    if size_bytes >= MAX_DB_BYTES:
        errors.append(f"DB size {size_mb:.2f} MB exceeds 20 MB target")

    print(
        f"D11 export OK: {counts['player_count']:,} players, "
        f"{counts.get('players_with_image_count', 0):,} with images, "
        f"{counts['attribute_count']} attributes, {counts['board_count']} boards, "
        f"{size_mb:.2f} MB"
    )
    print(f"  output: {DB_PATH}")
    print(f"  asset: {ASSET_DB_PATH}")
    print(f"  manifest: {MANIFEST_PATH}")

    if errors:
        for err in errors:
            print(f"  WARN: {err}", file=sys.stderr)
        return 1

    from run_validation_cases import run_cases  # noqa: E402

    d12_code, _ = run_cases(ASSET_DB_PATH, quiet=False)
    if d12_code != 0:
        print("D11 export FAILED: D12 validation cases did not pass", file=sys.stderr)
        return 1

    return 0


def update_pubspec_asset_entry() -> None:
    pubspec_path = ROOT / "pubspec.yaml"
    text = pubspec_path.read_text(encoding="utf-8")
    entry = "    - assets/db/tiki_taka.db"
    if entry in text:
        return
    needle = "    - assets/sounds/"
    if needle not in text:
        return
    pubspec_path.write_text(text.replace(needle, f"{entry}\n{needle}"), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
