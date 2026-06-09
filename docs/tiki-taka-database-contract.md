# Tiki-Taka Database Contract

This document defines how the Flutter app opens and uses the bundled SQLite database at runtime. It closes **Gap G5** and aligns with [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) Section 19 (local DB, no live APIs).

## Scope

| In scope | Out of scope (v1) |
| --- | --- |
| Read-only queries against `assets/db/tiki_taka.db` | Live Transfermarkt APIs |
| Copy bundled asset to an app-local file before open | Writing match state to SQLite |
| Search, validation, board load DAOs (Phase T2+) | Coach attributes, multiplayer sync |
| Reading nullable `players.image_url` for **display-only** player avatars (schema v2+) | Live Wikidata / Commons calls from the app |
| `Image.network` against HTTPS Commons URLs stored in DB when online | Transfermarkt `image_url` hotlinking |

Gameplay match state (hearts, timer, filled cells, used player IDs) stays **in memory** in the game engine/cubit — never persisted to this database.

Player images are **cosmetic**. Image load failures degrade to a placeholder; they never affect search, validation, or board placement. See [player-image-plan.md](./player-image-plan.md).

## Why copy the bundled asset?

Flutter cannot reliably open a bundled asset file as SQLite on every platform. `TikiTakaDatabase` therefore:

1. Reads the shipped asset from `assets/db/tiki_taka.db`.
2. Copies it to an app-local path on first use.
3. Opens the **local copy** for queries.

Stub types live under `lib/features/tiki_taka/data/local/`. Full open logic is implemented in **Phase T1**.

## Copy-on-first-use

On `open()`:

1. Resolve the local DB path via `TikiTakaDatabasePaths.resolveLocalDatabasePath()` (application support directory).
2. Read `meta.schema_version` and `meta.source_csv_hash` from the **bundled** asset (or from a small meta probe).
3. Build a fingerprint: `"{schema_version}:{source_csv_hash}"`.
4. Compare with the fingerprint stored in `SharedPreferences` (`tiki_taka_db_fingerprint`).
5. Copy the bundled asset to the local path when:
   - the local file does not exist, or
   - the stored fingerprint differs from the bundled fingerprint.
6. Open the local file with `readOnly: true` where the platform supports it.

## Invalidation rules

Re-copy the bundled DB when **either** meta value changes after an app update:

| `meta.key` | Purpose |
| --- | --- |
| `schema_version` | SQLite schema bump |
| `source_csv_hash` | ETL input changed |

When the fingerprint changes, delete or overwrite the previous local copy, copy the new asset, persist the new fingerprint, then open.

**Schema v2 (player images):** When `meta.schema_version` changes from `1` to `2`, the app re-copies the bundled DB even if `source_csv_hash` is unchanged. The v2 `players` table adds nullable `image_url` (Commons thumbnail URLs resolved at ETL — see [player-image-plan.md](./player-image-plan.md)).

## `players.image_url` (schema v2+)

| Column | Type | Notes |
| --- | --- | --- |
| `image_url` | TEXT NULL | HTTPS Wikimedia Commons thumbnail URL; `NULL` when unresolved |

- Populated at **build time** by `tool/etl/fetch_player_images.py` + `build_database.py`.
- DAOs expose the column to the UI as optional `imageUrl` on search/validation results (Phase P4+).
- The app **reads** this column only; it never updates image URLs at runtime.

## Read-only guarantee

The app **never writes** to Tiki-Taka SQLite:

- No `INSERT`, `UPDATE`, `DELETE`, or `rawInsert` from app code.
- `TikiTakaDatabase` exposes only read/query access through DAOs (Phase T2+).
- Open options use `readOnly: true` when supported.
- Public APIs must not expose write helpers.

Match progress, hearts, and timer are not stored in this database.

## Lifecycle

Use a **lazy singleton** `TikiTakaDatabase` per app process:

- First Tiki-Taka feature access calls `open()` (idempotent).
- Subsequent callers reuse the same connection.
- `close()` may run on app shutdown or when tearing down the Tiki-Taka feature scope; reopening calls `open()` again.

Avoid opening multiple writable connections. One shared read-only connection is sufficient for v1.

## Runtime data flow

```text
assets/db/tiki_taka.db          (Flutter asset, read-only source of truth)
        ↓ copy when missing or fingerprint stale
<appSupport>/tiki_taka.db       (local read-only working copy)
        ↓ sqflite readOnly open
TikiTakaDatabase.database
        ↓ DAOs (Phase T2+)
search · validate · load board
```

## Error handling (T1+)

| Condition | Behavior |
| --- | --- |
| Bundled asset missing | Controlled error; Tiki-Taka mode unavailable |
| Copy fails | Controlled error with retry surface |
| `schema_version` unreadable | Treat as corrupt asset; do not open |
| Local file present but corrupt | Delete local copy, re-copy from asset, retry once |

## Related files

| File | Role |
| --- | --- |
| `lib/features/tiki_taka/data/local/tiki_taka_database.dart` | `DefaultTikiTakaDatabase` service (T1) |
| `lib/features/tiki_taka/data/local/tiki_taka_database_paths.dart` | Asset/local paths and fingerprint keys |
| `test/tiki_taka_database_smoke_test.dart` | Dev smoke test (FFI, read-only) |
| `docs/dataset-plan.md` | ETL schema and table definitions |
| `docs/player-image-plan.md` | Player image ETL, schema v2, maintainability runbook |
| `docs/tiki-taka-toe-rules.md` §19–20 | Product data-source rules |

## Implementation phases

| Phase | Deliverable |
| --- | --- |
| **G5** (this doc) | Contract + path helpers + stub interface |
| **T1** | Working `open()` / `close()` / copy + invalidation |
| **T2** | DAOs for boards, search, validation |
