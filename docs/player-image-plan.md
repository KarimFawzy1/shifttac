# Tiki-Taka Player Images — Implementation Plan

## Purpose

Add **one player face image per player** for Tiki-Taka mode, shown in:

1. **Player search results** — circular thumbnail beside name/subtitle.
2. **Filled board cells** — image expanded to fill the cell (`BoxFit.cover`); **cell size and grid layout stay unchanged**.

Images are resolved at **build time** from **Wikidata** (via Transfermarkt ID **P2446** → Commons image **P18**) and stored as a **nullable URL** on each `players` row. At runtime the app loads the URL over HTTPS when online. When a player has no URL, the network request fails, or the device is offline, the UI shows a **person placeholder icon** (`Icons.person_rounded`).

**Related:** [dataset-plan.md](./dataset-plan.md), [tiki-taka-database-contract.md](./tiki-taka-database-contract.md), [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md), `lib/features/tiki_taka/`, `tool/etl/`.

---

## Product Decisions (locked)

| Decision | Value |
| --- | --- |
| Image source | Wikidata **P2446** (Transfermarkt player ID) → **P18** (image) → Wikimedia Commons thumbnail URL |
| Transfermarkt hotlinking | **Forbidden** — do not use TM `image_url` or TM CDN |
| Storage | Nullable `players.image_url` in shipped `tiki_taka.db` |
| Images per player | **Exactly one** URL per player (first resolved P18 wins in ETL) |
| Runtime fetch | `Image.network` — no bundled image bytes, no disk cache in v1 |
| Offline / missing / error | Same **person placeholder** for all three cases |
| Board cell layout | Grid delegate, spacing, and cell dimensions **unchanged**; filled cell shows image only (no rotated name text) |
| Search row layout | Leading circular avatar (~40 logical px) + existing name/subtitle |
| Gameplay validation | Unchanged — images are display-only; search/validate SQL logic is unaffected |
| Schema version | Bump `meta.schema_version` from `1` → `2` |

---

## Target Architecture

```text
BUILD TIME
  players_table.csv (from D7)
       ↓
  tool/etl/fetch_player_images.py     # NEW — Wikidata SPARQL batches
       ↓
  tool/etl/staging/player_images.csv  # player_id, image_url, commons_file
       ↓ merge at D11
  tool/etl/build_database.py          # players.image_url column
       ↓
  assets/db/tiki_taka.db
  tool/etl/output/manifest.json       # + players_with_image_count

RUNTIME (Flutter)
  PlayerSearchDao / ValidationDao
       → TikiPlayerSearchResult.imageUrl (nullable)
       ↓
  PlayerAvatar widget
       ├─ imageUrl == null        → placeholder
       ├─ Image.network fails     → placeholder  (includes offline)
       └─ load success            → circular (search) or cover (cell)
       ↓
  PlayerSearchResultTile · TikiTakaCell
```

### Commons URL shape (ETL output)

```text
https://commons.wikimedia.org/wiki/Special:FilePath/{filename}?width=128
```

Use `width=128` for search avatars; the same URL scales up for board cells via Flutter layout. Filename must be URL-encoded.

### Placeholder spec

Reuse existing theme tokens:

| Property | Value |
| --- | --- |
| Shape | Circle in search; rectangle with cell `borderRadius` on board |
| Background | `AppColors.surfaceContainerHigh` |
| Icon | `Icons.person_rounded` |
| Icon color | `AppColors.onSurfaceVariant` |
| Icon size | ~55% of avatar/cell short side |

---

## Schema Change

### `players` table (schema v2)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | unchanged — `tm:{transfermarkt_id}` |
| `display_name` | TEXT | unchanged |
| `search_text` | TEXT | unchanged |
| `position` | TEXT | unchanged |
| `nation` | TEXT | unchanged |
| `image_url` | TEXT NULL | **NEW** — HTTPS Commons thumbnail; `NULL` when unresolved |

### `meta` / manifest additions

| Key | Example | Purpose |
| --- | --- | --- |
| `schema_version` | `2` | Triggers app DB re-copy |
| `player_image_source` | `wikidata_p2446_p18` | Provenance |
| `players_with_image_count` | `8420` | QA / telemetry in manifest |

### Staging file

`tool/etl/staging/player_images.csv`:

| Column | Required | Description |
| --- | --- | --- |
| `player_id` | yes | `tm:148455` |
| `image_url` | yes | Commons thumbnail URL |
| `commons_file` | yes | Raw P18 filename (QA / future credits) |

Only rows with a resolved image are written. Players absent from this file get `image_url = NULL` in SQLite.

---

## Wikidata ETL (summary)

**Script:** `tool/etl/fetch_player_images.py`

1. Read all `player_id` values from `staging/players_table.csv`.
2. Strip `tm:` prefix → numeric TM id for SPARQL **P2446** lookup.
3. Batch-query Wikidata Query Service (300–500 ids per request):

   ```sparql
   SELECT ?tmId ?image ?commonsFile WHERE {
   VALUES ?tmId { "148455" "132098" }
   ?item wdt:P2446 ?tmId .
   ?item wdt:P18 ?image .
   BIND(REPLACE(STR(?image), "http://commons.wikimedia.org/wiki/Special:FilePath/", "") AS ?commonsFile)
   }
   ```

4. For duplicate `tmId` rows, keep the first result only (one image per player).
5. Build Commons URL; skip empty/invalid filenames.
6. Write `player_images.csv` and `tool/etl/reports/fetch_player_images_summary.json`.

**HTTP etiquette:** set a descriptive `User-Agent` (app name + contact); sleep ~1s between batch requests; retry transient 429/5xx up to 3 times.

**Expected coverage:** ~20–35% of ~28k players with a usable image (varies by dataset refresh). Remaining players correctly get `NULL` → placeholder.

---

## Flutter Surface Area

| File | Change |
| --- | --- |
| `lib/features/tiki_taka/data/models/tiki_player_search_result.dart` | Add nullable `imageUrl` |
| `lib/features/tiki_taka/data/local/daos/player_search_dao.dart` | `SELECT … p.image_url` |
| `lib/features/tiki_taka/data/local/daos/validation_dao.dart` | Include `image_url` in validation result |
| `lib/features/tiki_taka/presentation/widgets/player_avatar.dart` | **NEW** — network + placeholder |
| `lib/features/tiki_taka/presentation/widgets/player_search_result_tile.dart` | Leading `PlayerAvatar` |
| `lib/features/tiki_taka/presentation/widgets/tiki_taka_cell.dart` | Filled state → full-cell `PlayerAvatar` (`BoxFit.cover`) |
| `tool/etl/build_database.py` | Schema v2 + merge `player_images.csv` |
| `tool/etl/build_players.py` | Document optional re-run order (no image logic required here) |
| `docs/tiki-taka-database-contract.md` | Allow display-only network image fetch |
| `docs/dataset-plan.md` | Document `image_url` column + ETL phase |
| `docs/tiki-taka-toe-rules.md` | Player image display rules |

**Out of scope v1:** disk cache, `cached_network_image`, photo credits screen, face cropping, live Wikidata calls from the app.

---

## Phase Order

```text
P0 (this doc) → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8
```

Complete each phase as a **small reviewable commit** and **push to GitHub** before starting the next.

Suggested commit style:

```text
tiki-taka: P<n> <short summary>
```

Examples:

```text
tiki-taka: P1 add players.image_url schema contract
tiki-taka: P2 add wikidata player image ETL
tiki-taka: P5 add PlayerAvatar widget
```

Every DoD below includes:

- Code/docs/tests complete for that phase.
- Relevant validation commands pass.
- Phase changes are committed.
- Commit is pushed to remote.

---

## Phase P0 — Planning Lock

**Goal:** Agree architecture, schema, and UX before changing production code.

**Scope In:**

- Author and review this document.
- Confirm URL-in-DB + runtime fetch + placeholder fallback.
- Confirm board cells keep current size; filled cells show image only.
- Confirm Wikidata/Commons as sole image source (not Transfermarkt).

**Scope Out:**

- No ETL or Flutter implementation.

**DoD:**

- [ ] `docs/player-image-plan.md` reviewed and agreed.
- [ ] Schema v2 column `players.image_url` documented.
- [ ] Placeholder behavior documented for: no URL, offline, network error.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P0 add player image implementation plan
```

---

## Phase P1 — Schema & Contract Updates

**Goal:** Lock the database contract and ETL schema for `image_url` without shipping a rebuilt DB yet.

**Scope In:**

1. Update `docs/tiki-taka-database-contract.md`:
   - Move “Wikidata” from out-of-scope to **display-only** image URLs stored in DB.
   - Document nullable `players.image_url`.
   - Note schema version `2` invalidates local DB copy.
2. Update `docs/dataset-plan.md`:
   - Add `image_url` to `players` table definition.
   - Add `fetch_player_images.py` to pipeline diagram (after D7, before D11).
3. Update `tool/etl/build_database.py`:
   - `SCHEMA_VERSION = 2`
   - Add `image_url TEXT` to `CREATE TABLE players`.
   - Extend `PLAYERS` import columns to accept `image_url` (default empty → SQL `NULL`).
4. Add stub `tool/etl/fetch_player_images.py` with `--help` and module docstring (no network calls yet) **or** document as P2-only file — prefer stub so D11 column merge compiles.

**Scope Out:**

- Running Wikidata fetch.
- Copying new `tiki_taka.db` to assets.
- Flutter UI.

**Validation:**

```text
python tool/etl/build_database.py   # fails gracefully if staging missing — schema code review only
```

**DoD:**

- [ ] `players.image_url` documented in dataset + DB contract docs.
- [ ] `SCHEMA_VERSION` is `2` in `build_database.py`.
- [ ] `CREATE TABLE players` includes nullable `image_url`.
- [ ] Import path accepts `image_url` (empty CSV field → `NULL`).
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P1 add players.image_url schema contract
```

---

## Phase P2 — Wikidata Image ETL

**Goal:** Resolve Commons thumbnail URLs for players that exist on Wikidata with P2446 + P18.

**Scope In:**

1. Implement `tool/etl/fetch_player_images.py`:
   - Input: `staging/players_table.csv`
   - Output: `staging/player_images.csv`, `reports/fetch_player_images_summary.json`
   - Batched SPARQL, encoding, dedupe, retries, User-Agent.
2. Add `tool/etl/reports/.gitkeep` or ensure reports dir exists.
3. Document run command in script docstring:

   ```text
   python tool/etl/fetch_player_images.py
   ```

4. Optional dry-run flag `--limit N` for dev (first N players only).

**Scope Out:**

- Merging into final SQLite (Phase P3).
- Flutter code.

**Validation:**

```text
python tool/etl/fetch_player_images.py --limit 100
```

Check summary JSON contains: `total_players`, `matched_wikidata`, `with_image`, `written_rows`, `errors`.

**DoD:**

- [ ] Script runs against staging and produces `player_images.csv`.
- [ ] Each output row has exactly one `player_id` and one `image_url`.
- [ ] URLs use HTTPS Commons `Special:FilePath` with `width=128`.
- [ ] Summary report written with match counts.
- [ ] No Transfermarkt image URLs anywhere in output.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P2 add wikidata player image ETL
```

---

## Phase P3 — Database Build Integration & Asset Refresh

**Goal:** Ship schema v2 `tiki_taka.db` with populated `image_url` values.

**Scope In:**

1. Update `build_database.py`:
   - Load `player_images.csv` into a dict keyed by `player_id`.
   - When importing `players_table.csv`, set `image_url` from dict or `NULL`.
   - Write `meta.player_image_source` and manifest field `players_with_image_count`.
2. Update `REQUIRED_STAGING` if `player_images.csv` is optional (recommended: **optional** — missing file means all `NULL`).
3. Run full ETL pipeline:

   ```text
   python tool/etl/fetch_player_images.py
   python tool/etl/build_database.py
   ```

4. Copy rebuilt DB to `assets/db/tiki_taka.db`.
5. Verify `manifest.json` `schema_version` / hash updated.

**Scope Out:**

- Flutter model/DAO changes (Phase P4).

**Validation:**

```sql
-- against assets/db/tiki_taka.db
SELECT COUNT(*) FROM players WHERE image_url IS NOT NULL;
SELECT id, image_url FROM players WHERE image_url IS NOT NULL LIMIT 5;
```

```text
flutter test test/features/tiki_taka/release/tiki_taka_database_smoke_test.dart
```

(Update smoke test in P4/P8 if column assertions needed — at minimum DB must still open.)

**DoD:**

- [ ] `assets/db/tiki_taka.db` rebuilt with schema v2.
- [ ] `players_with_image_count` > 0 in output manifest.
- [ ] Every non-null `image_url` is HTTPS and points to `commons.wikimedia.org`.
- [ ] Players without Wikidata match have `image_url IS NULL`.
- [ ] `source_csv_hash` / fingerprint changed so app re-copies DB on update.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P3 rebuild tiki_taka.db with player image URLs
```

---

## Phase P4 — Data Layer (Models & DAOs)

**Goal:** Expose `imageUrl` from SQLite through existing search and validation paths.

**Scope In:**

1. Extend `TikiPlayerSearchResult`:

   ```dart
   final String? imageUrl;
   // fromMap: row['image_url'] as String?
   ```

2. Update `PlayerSearchDao` query to select `p.image_url`.
3. Update `ValidationDao` to return `image_url` on validated player row.
4. Update `tiki_taka_dao_test_support.dart` and any fixtures with optional `imageUrl`.
5. Extend database smoke test:
   - Assert `players` table has `image_url` column.
   - Assert at least one row has non-null URL in shipped asset (or skip if CI DB is stub — use real asset).

**Scope Out:**

- Widgets / UI.

**Validation:**

```text
flutter test test/features/tiki_taka/
```

**DoD:**

- [ ] `TikiPlayerSearchResult.imageUrl` nullable field added; `Equatable` props updated.
- [ ] Search and validation DAOs return `image_url`.
- [ ] Unit/DAO tests pass with and without `imageUrl`.
- [ ] Smoke test covers new column.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P4 expose player image_url in DAOs and models
```

---

## Phase P5 — PlayerAvatar Widget

**Goal:** Single reusable widget for network image + person placeholder.

**Scope In:**

1. Create `lib/features/tiki_taka/presentation/widgets/player_avatar.dart`:

      ```dart
      class PlayerAvatar extends StatelessWidget {
      const PlayerAvatar({
         super.key,
         required this.imageUrl,
         required this.size,
         this.fit = BoxFit.cover,
         this.borderRadius,
         this.semanticsLabel,
      });

      final String? imageUrl;
      final double size;
      final BoxFit fit;
      final BorderRadius? borderRadius;
      final String? semanticsLabel;
      }
   ```

2. Behavior:
   - `imageUrl == null` or empty → `_PersonPlaceholder`.
   - Else `Image.network` with `width`/`height` = `size`, given `fit`.
   - `loadingBuilder` → placeholder (optional: same placeholder, no spinner).
   - `errorBuilder` → placeholder.
3. Widget tests:
   - Null URL → finds person icon.
   - Invalid URL → finds person icon (use test driver / mock — or golden with errorBuilder).

**Scope Out:**

- Wiring into search tile and board cell (P6/P7).

**Validation:**

```text
flutter test test/features/tiki_taka/presentation/widgets/player_avatar_test.dart
```

**DoD:**

- [ ] `PlayerAvatar` implemented with placeholder fallback.
- [ ] No `cached_network_image` dependency added.
- [ ] Widget tests cover null URL and error path.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P5 add PlayerAvatar widget with placeholder fallback
```

---

## Phase P6 — Search Results UI

**Goal:** Show player face (or placeholder) in each search result row.

**Scope In:**

1. Update `PlayerSearchResultTile`:
   - Add leading `PlayerAvatar` (~40.w, circular via `borderRadius: BorderRadius.circular(size/2)`).
   - Pass `player.imageUrl`.
   - Keep existing name, subtitle, chevron layout.
   - Update semantics label unchanged in meaning.
2. Widget test: row with `imageUrl: null` shows placeholder; row with test URL includes `PlayerAvatar`.

**Scope Out:**

- Board cell changes.

**Validation:**

```text
flutter test test/features/tiki_taka/presentation/widgets/
```

**DoD:**

- [ ] Search rows show circular avatar left of text.
- [ ] Null `imageUrl` shows person placeholder.
- [ ] Row tap / enable / disable behavior unchanged.
- [ ] Widget tests updated.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P6 show player avatars in search results
```

---

## Phase P7 — Board Cell UI

**Goal:** Filled cells display the player image full-bleed; grid geometry unchanged.

**Scope In:**

1. Update `TikiTakaCell` filled branch:
   - Remove rotated `Text` name display.
   - Use `PlayerAvatar` with:
     - `size`: max of cell constraints (use `LayoutBuilder` or `double.infinity` within padded `ClipRRect`).
     - `fit: BoxFit.cover`
     - `borderRadius: AppSpacing.borderRadiusMd` (match cell)
   - Keep `Semantics` label: `'Filled cell: ${player.displayName}'`.
2. Confirm `TikiTakaBoard` / `GridView` delegate **unchanged** (`childAspectRatio`, gaps, padding).
3. Update `tiki_taka_board_test.dart`:
   - Filled cell finds `PlayerAvatar` (or placeholder).
   - Cell dimensions unchanged (optional: golden or size assertion).

**UX note:** Long names are no longer visible inside the cell; full name remains in search dialog history and semantics. Acceptable per product decision.

**Scope Out:**

- Caching, name overlay on cell.

**Validation:**

```text
flutter test test/features/tiki_taka/presentation/widgets/tiki_taka_board_test.dart
```

Manual: fill a cell online with a known imaged player; verify cover fit; toggle airplane mode → placeholder on **new** search rows; already-rendered cells may reset on rebuild.

**DoD:**

- [ ] Filled cells show image expanded to cell bounds (`BoxFit.cover`).
- [ ] Empty cells unchanged.
- [ ] Grid cell size / spacing identical to pre-change board.
- [ ] Missing URL / offline → person placeholder in cell.
- [ ] Board widget tests pass.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P7 show player image in filled board cells
```

---

## Phase P8 — Docs, Rules Alignment & Full QA

**Goal:** Align product docs with shipped behavior and sign off end-to-end.

**Scope In:**

1. Update `docs/tiki-taka-toe-rules.md`:
   - Player images are cosmetic; validation still name/attribute based.
   - Offline → placeholder; no TM hotlinking.
2. Update `docs/dataset-plan.md` ETL checklist with D7b image fetch step.
3. Mark phases P0–P8 complete in this file (checkboxes).
4. Run full test suite:

   ```text
   flutter test
   python tool/etl/fetch_player_images.py --limit 10   # sanity
   ```

5. Manual QA checklist:

| # | Check |
| --- | --- |
| 1 | Search “Salah” online → face or placeholder in results |
| 2 | Select player → filled cell shows image full-bleed |
| 3 | Airplane mode → new search shows placeholders |
| 4 | Player with `NULL image_url` → placeholder in search and cell |
| 5 | Board size matches previous build (visual compare) |
| 6 | Tiki-Taka validation still accepts/rejects correctly |

**Scope Out:**

- Photo credits screen (future).

**DoD:**

- [ ] Rules and dataset docs reflect player image behavior.
- [ ] All `flutter test` pass.
- [ ] Manual QA checklist completed.
- [ ] P0–P8 checkboxes updated in this doc.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P8 align docs and complete player image QA
```

---

## ETL Runbook (after implementation)

Full refresh when Transfermarkt CSV or player set changes:

```text
# Existing pipeline through D7 …
python tool/etl/build_players.py

# New image resolution
python tool/etl/fetch_player_images.py

# Export SQLite
python tool/etl/build_database.py
```

Expected manifest fields:

```json
{
  "schema_version": 2,
  "player_count": 28221,
  "players_with_image_count": 8500,
  "player_image_source": "wikidata_p2446_p18"
}
```

---

## Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| Low Wikidata coverage | Placeholder is the designed fallback; no UX dead-end |
| P18 image not a headshot | v1 accepts any P18; optional ETL filter list in future |
| Wikidata rate limits | Batch size 300–500, sleep, retries, `--limit` for dev |
| Offline gameplay | Core game is offline; images degrade gracefully |
| DB size growth | URLs only (~100 bytes × matches ≈ low MB); no binary blobs |
| Commons downtime | `errorBuilder` → placeholder; same as offline |
| Android cleartext | Commons URLs are HTTPS — no cleartext config needed |

---

## Future Enhancements (not in this plan)

- Disk cache (`cached_network_image`) for repeat views while online.
- Optional photo credits screen (Commons attribution).
- ETL quality filter (portrait-only heuristics).
- Prefetch visible search result images during typing debounce.

---

## File Checklist (quick reference)

| Phase | Primary files |
| --- | --- |
| P0 | `docs/player-image-plan.md` |
| P1 | `docs/tiki-taka-database-contract.md`, `docs/dataset-plan.md`, `tool/etl/build_database.py` |
| P2 | `tool/etl/fetch_player_images.py`, `tool/etl/reports/fetch_player_images_summary.json` |
| P3 | `assets/db/tiki_taka.db`, `tool/etl/output/manifest.json` |
| P4 | `tiki_player_search_result.dart`, `player_search_dao.dart`, `validation_dao.dart` |
| P5 | `player_avatar.dart`, tests |
| P6 | `player_search_result_tile.dart` |
| P7 | `tiki_taka_cell.dart`, board tests |
| P8 | `tiki-taka-toe-rules.md`, QA sign-off |
