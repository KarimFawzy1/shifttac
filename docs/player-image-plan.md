# Tiki-Taka Player Images — Implementation Plan

## Purpose

Add **one player face image per player** for Tiki-Taka mode, shown in:

1. **Player search results** — circular thumbnail beside name/subtitle.
2. **Filled board cells** — image expanded to fill the cell (`BoxFit.cover`); **cell size and grid layout stay unchanged**.

Images are resolved at **build time** from **Wikidata** (via Transfermarkt ID **P2446** → Commons image **P18**) and stored as a **nullable URL** on each `players` row. At runtime the app loads the URL over HTTPS when online. **Any failure** at ETL or runtime (missing URL, offline, 404, timeout, corrupt image, invalid URL) degrades silently to a **person placeholder icon** — gameplay is never affected. See [Exception Handling](#exception-handling).

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
| Offline / missing / error | Same **person placeholder** for **all** failure cases (see [Exception Handling](#exception-handling)) |
| Error surfacing | **Silent degrade** — no snackbars, dialogs, or crashes; gameplay never blocked |
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
       ├─ invalid / missing URL   → placeholder (no network call)
       ├─ loading                 → placeholder (no spinner in v1)
       ├─ any load failure        → placeholder (offline, 404, timeout, corrupt…)
       └─ load success            → circular (search) or cover (cell)
       ↓
  PlayerSearchResultTile · TikiTakaCell
```

### Commons URL shape (ETL output)

```text
https://commons.wikimedia.org/wiki/Special:FilePath/{filename}?width=128
```

Use `width=128` for search avatars; the same URL scales up for board cells via Flutter layout. Filename must be URL-encoded **once** (see [URL encoding](#url-encoding-etl)).

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

## Exception Handling

Images are **cosmetic only**. Any failure anywhere in the pipeline must degrade to the person placeholder (runtime) or `image_url = NULL` (ETL) — **never** block search, validation, or board placement.

### Design principle

```text
ETL:     skip bad row → player has NULL image_url → still in DB, still playable
Runtime: any image failure → PlayerAvatar placeholder → search/cell still works
```

No user-facing error messages for image failures in v1. Log in debug / ETL reports only.

---

### Build-time exceptions (ETL)

Handled in `fetch_player_images.py`. A player that fails any step below is **omitted** from `player_images.csv` (SQLite `image_url` stays `NULL`).

| Exception | Cause | Handling |
| --- | --- | --- |
| Missing staging input | `players_table.csv` absent | Exit 1 with clear message (pipeline mis-order) |
| No Wikidata item | TM id not on Wikidata (no P2446) | Skip player; count as `no_wikidata` in summary |
| No P18 image | Item exists but no image property | Skip player; count as `no_p18` |
| Duplicate P2446 / P18 rows | SPARQL returns multiple bindings | Keep **first** row only per `tmId` |
| Empty / whitespace filename | Malformed P18 URI | Skip player; count as `invalid_filename` |
| Double-encoded filename | Wikidata returns `%20` in filename string | **`urllib.parse.unquote` once**, then **`quote` once** when building URL |
| Invalid URL after build | Fails local validation (not HTTPS, wrong host, empty path) | Skip player; count as `invalid_url` |
| SPARQL HTTP error | 429, 5xx, timeout | Retry batch up to **3** times with backoff; on final failure log batch id in `errors[]`, **continue** next batch |
| SPARQL parse error | Non-JSON or unexpected shape | Log batch error; continue (do not abort entire run) |
| Malformed SPARQL response row | Missing `tmId` or `image` binding | Skip that binding; increment `skipped_bindings` |
| Commons HEAD/GET 404 (optional verify) | Stale P18 file removed from Commons | Skip player; count as `commons_not_found` — use when `--verify-urls` enabled |
| Commons non-image response | Wrong `Content-Type` | Skip player; count as `commons_not_image` |
| Network / DNS failure | Offline dev machine mid-run | Retry batch; record failed batch ids in summary for manual re-run |
| Partial run | Script interrupted | Already-written CSV is valid input; re-run is idempotent (overwrites output) |

#### URL encoding (ETL)

Wikidata often returns P18 filenames that are **already percent-encoded** (e.g. `Mohamed%20Salah%202018.jpg`). Encoding again produces `%2520` and **404** at Commons.

```python
raw = filename_from_p18_uri(p18_uri)       # strip path prefix
decoded = urllib.parse.unquote(raw)        # "Mohamed Salah 2018.jpg"
encoded = urllib.parse.quote(decoded, safe="")
url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{encoded}?width=128"
```

Only accept URLs where:

- Scheme is `https`
- Host is `commons.wikimedia.org`
- Path contains `Special:FilePath/`

#### ETL summary report (`fetch_player_images_summary.json`)

Must include counts for observability:

```json
{
  "total_players": 28221,
  "matched_wikidata": 12000,
  "with_p18": 9500,
  "written_rows": 9200,
  "skipped": {
    "no_wikidata": 16221,
    "no_p18": 2500,
    "invalid_filename": 12,
    "invalid_url": 8,
    "commons_not_found": 280,
    "duplicate_tm_id": 0
  },
  "batch_errors": [],
  "verify_urls_enabled": false
}
```

ETL must **exit 0** when the run completes even if many players were skipped — only exit non-zero for missing inputs or total SPARQL failure (zero batches succeeded).

---

### Runtime exceptions (Flutter)

Handled entirely inside `PlayerAvatar`. Callers (`PlayerSearchResultTile`, `TikiTakaCell`) must not catch image errors themselves.

| Exception | Cause | Handling |
| --- | --- | --- |
| `imageUrl == null` | No Wikidata match / ETL skip | `_PersonPlaceholder` — **no** `Image.network` call |
| `imageUrl` empty / whitespace | Bad DB row (should not ship) | Treat as null → placeholder |
| `imageUrl` not HTTPS | Invalid stored URL | Treat as null → placeholder (validate before network) |
| `imageUrl` wrong host | Non-Commons URL in DB | Treat as null → placeholder |
| Device offline | No connectivity | `Image.network` fails → `errorBuilder` → placeholder |
| HTTP 404 / 410 | Commons file removed since ETL | `errorBuilder` → placeholder |
| HTTP 5xx | Commons / CDN error | `errorBuilder` → placeholder |
| Timeout | Slow or hung request | Rely on Flutter framework timeout → `errorBuilder` → placeholder |
| DNS failure | Network misconfiguration | `errorBuilder` → placeholder |
| SSL / certificate error | MITM, clock skew | `errorBuilder` → placeholder |
| Non-image body | HTML error page, redirect to wiki | `errorBuilder` → placeholder |
| Corrupt / undecodable image | Truncated JPEG/PNG | `errorBuilder` → placeholder |
| Widget disposed mid-load | User closed search quickly | Flutter cancels load; no crash (default `Image.network` behavior) |
| Loading state | Request in flight | `loadingBuilder` → **same placeholder** (no spinner in v1) |

#### Runtime validation (before `Image.network`)

```dart
bool isLoadablePlayerImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.scheme == 'https' &&
      uri.host == 'commons.wikimedia.org' &&
      uri.path.contains('Special:FilePath');
}
```

If validation fails → placeholder without network I/O.

#### Logging (debug only)

In debug builds, log a single line when falling back (no PII beyond player id):

```text
[PlayerAvatar] fallback player=tm:148455 reason=network_error
```

Do **not** log in release. Do **not** show `SnackBar` / dialog.

#### Gameplay guarantee

Image failures must **never**:

- Prevent opening the search dialog
- Block selecting a player
- Invalidate a correct answer
- Crash or assert in production

---

### Exception QA matrix (manual + automated)

| # | Scenario | Expected UI |
| --- | --- | --- |
| E1 | Player with `NULL image_url` | Placeholder in search + cell |
| E2 | Player with valid URL, online | Face image |
| E3 | Airplane mode, valid URL in DB | Placeholder |
| E4 | Malformed URL in test fixture (`http://`, empty string) | Placeholder, no crash |
| E5 | Valid URL that 404s (use fake Commons path in test) | Placeholder via `errorBuilder` |
| E6 | Rapid type-ahead in search | No crash when rows dispose mid-load |
| E7 | Fill board cell then go offline | Cell shows placeholder on rebuild; game state intact |
| E8 | ETL `--limit 10` with one bad TM id mixed in | Summary counts skip; DB build still succeeds |

---

## Flutter Surface Area

| File | Change |
| --- | --- |
| `lib/features/tiki_taka/data/models/tiki_player_search_result.dart` | Add nullable `imageUrl` |
| `lib/features/tiki_taka/data/local/daos/player_search_dao.dart` | `SELECT … p.image_url` |
| `lib/features/tiki_taka/data/local/daos/validation_dao.dart` | Include `image_url` in validation result |
| `lib/features/tiki_taka/presentation/widgets/player_avatar.dart` | **NEW** — network + placeholder |
| `lib/features/tiki_taka/domain/services/player_image_url_validator.dart` | **NEW** — `isLoadablePlayerImageUrl` (HTTPS Commons check) |
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

- [x] `docs/player-image-plan.md` reviewed and agreed.
- [x] Schema v2 column `players.image_url` documented.
- [x] Placeholder behavior documented for: no URL, offline, network error, and full [Exception Handling](#exception-handling) matrix.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

**Suggested commit:**

```text
tiki-taka: P0 add player image implementation plan
```

### Phase P0 Completion — 2026-06-09

#### Locked implementation direction

| Area | Decision |
| --- | --- |
| Image source | Wikidata **P2446** → **P18** → Commons `Special:FilePath` thumbnail URL |
| Forbidden | Transfermarkt `image_url` / TM CDN hotlinking |
| Storage | Nullable `players.image_url` in `tiki_taka.db` (schema v2) |
| Runtime | `Image.network` when URL valid + online; no disk cache in v1 |
| Failure UX | Silent degrade → `Icons.person_rounded` placeholder; no snackbars or crashes |
| Search UI | ~40 logical px circular avatar leading name/subtitle |
| Board UI | Filled cell: image `BoxFit.cover` full-bleed; grid size unchanged; no rotated name text |
| ETL | `fetch_player_images.py` batch SPARQL; `unquote` → `quote` URL encoding; skip bad rows |
| Gameplay | Images cosmetic only — search, validation, and board logic unchanged |

#### Commons URL verification (pre-implementation)

Manual browser + HTTP checks against players in `assets/db/tiki_taka.db`:

| Player | DB id | Result |
| --- | --- | --- |
| Mohamed Salah | `tm:148455` | URL loads — HTTP 200 `image/jpeg` |
| Lionel Messi | `tm:28003` | URL loads |
| Cristiano Ronaldo | `tm:8198` | URL loads |
| Erling Haaland | `tm:418560` | URL loads |
| Kevin De Bruyne | `tm:88755` | URL loads |
| Jude Bellingham | `tm:581678` | URL loads |

Example verified URL pattern:

```text
https://commons.wikimedia.org/wiki/Special:FilePath/Mohamed%20Salah%202018.jpg?width=128
```

#### Test baseline (pre-implementation)

Run: `flutter test` on 2026-06-09 — **407 / 407 passed**. P0 introduces **docs only** — no production code modified.

#### Next phase

Proceed to **Phase P1 — Schema & Contract Updates** (`players.image_url` in ETL + contract docs + `build_database.py` schema v2 stub).

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
   - Batched SPARQL, **single-pass URL encoding** (`unquote` → `quote`), dedupe, retries, User-Agent.
   - Per-player try/except: one bad player must not abort the run.
   - Optional `--verify-urls` flag: HEAD/GET Commons; skip 404 / non-image (see [Exception Handling](#exception-handling)).
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

Check summary JSON contains: `total_players`, `matched_wikidata`, `with_p18`, `written_rows`, `skipped` breakdown, `batch_errors`.

**DoD:**

- [ ] Script runs against staging and produces `player_images.csv`.
- [ ] Each output row has exactly one `player_id` and one `image_url`.
- [ ] URLs use HTTPS Commons `Special:FilePath` with `width=128`.
- [ ] Filename encoding uses **decode-then-encode** (no `%2520` double-encoding).
- [ ] Skipped players are counted in summary (`no_wikidata`, `no_p18`, `invalid_url`, etc.).
- [ ] SPARQL batch failure retries then continues; partial success still exits 0.
- [ ] Summary report written with match and skip counts.
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
- [ ] Spot-check: no `%2520` double-encoding in shipped URLs.
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

2. Behavior (see [Runtime exceptions](#runtime-exceptions-flutter)):
   - Validate URL with `isLoadablePlayerImageUrl` before any network call.
   - `imageUrl == null`, empty, or fails validation → `_PersonPlaceholder`.
   - Else `Image.network` with `width`/`height` = `size`, given `fit`.
   - `loadingBuilder` → same placeholder (no spinner in v1).
   - `errorBuilder` → placeholder for **all** network/decode failures.
   - Debug-only log on fallback; no user-facing error UI.
3. Widget tests:
   - Null URL → finds person icon.
   - Empty / malformed URL → finds person icon (no network).
   - Invalid HTTPS host → finds person icon.
   - Simulated `errorBuilder` path → finds person icon.

**Scope Out:**

- Wiring into search tile and board cell (P6/P7).

**Validation:**

```text
flutter test test/features/tiki_taka/presentation/widgets/player_avatar_test.dart
```

**DoD:**

- [ ] `PlayerAvatar` implemented with placeholder fallback for all failure modes in [Exception Handling](#exception-handling).
- [ ] URL validated before `Image.network`; invalid URLs never hit the network.
- [ ] No `cached_network_image` dependency added.
- [ ] Widget tests cover null, invalid URL, and error path.
- [ ] No snackbars, dialogs, or crashes on image failure.
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
| 7 | [Exception QA matrix](#exception-qa-matrix-manual--automated) E1–E8 pass |

**Scope Out:**

- Photo credits screen (future).

**DoD:**

- [ ] Rules and dataset docs reflect player image behavior.
- [ ] All `flutter test` pass.
- [ ] Manual QA checklist completed (including exception matrix E1–E8).
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
| Wikidata rate limits | Batch size 300–500, sleep, retries, `--limit` for dev; failed batches logged, run continues |
| Double URL encoding (`%2520`) | ETL `unquote` → `quote`; optional `--verify-urls` catches 404 before ship |
| Stale Commons file after ETL | Runtime `errorBuilder` → placeholder; optional ETL verify skips bad URLs |
| Offline gameplay | Core game is offline; images degrade gracefully |
| DB size growth | URLs only (~100 bytes × matches ≈ low MB); no binary blobs |
| Commons downtime | `errorBuilder` → placeholder; same as offline |
| Image load crash / assert | All failures contained in `PlayerAvatar`; widget tests for error paths |
| User confusion on placeholder | Expected; no error toast — cosmetic-only feature |
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
| P5 | `player_avatar.dart`, `player_image_url_validator.dart`, tests |
| P6 | `player_search_result_tile.dart` |
| P7 | `tiki_taka_cell.dart`, board tests |
| P8 | `tiki-taka-toe-rules.md`, QA sign-off |
