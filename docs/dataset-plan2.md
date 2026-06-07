# Tiki-Taka-Toe - Flutter Implementation Plan

This document turns the completed dataset pipeline in [dataset-plan.md](./dataset-plan.md) and the gameplay specification in [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) into an implementation plan for the Flutter app.

## Scope

Build **Tiki-Taka-Toe - 1 Player Mode**.

The first version is:

- One user only.
- No AI opponent.
- No local multiplayer.
- No X/O turn switching.
- No player turn indicator.
- No move counter.
- Timer-based.
- 5 hearts.
- Search-and-select player guessing.
- First 3-in-a-row win.
- Optional continue after first win.
- Full-board completion challenge.

Future multiplayer and coach attributes are explicitly out of scope for this plan.

## Source Of Truth

| Area | Source |
| --- | --- |
| ETL, schema, boards, validation SQL | [dataset-plan.md](./dataset-plan.md) |
| Gameplay rules, statuses, dialogs, edge cases | [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) |
| Existing app architecture | `lib/features/game/`, `lib/core/routing/`, `lib/features/home/` |

## Current Data Baseline

The data pipeline is complete through D12.

Expected available artifacts:

| Artifact | Path |
| --- | --- |
| Shipped SQLite DB | `assets/db/tiki_taka.db` |
| DB manifest | `tool/etl/output/manifest.json` |
| D12 fixtures | `tool/etl/fixtures/validation_cases.yaml` |
| D12 runner | `tool/etl/run_validation_cases.py` |
| Attribute SVGs | `assets/tiki_taka/attrs/` |

Runtime must use the bundled SQLite asset only. Raw CSV files and live APIs must not be used during gameplay.

---

## Gaps To Fix Before Flutter Gameplay Work

These must be fixed before building the Tiki-Taka screen, search flow, or game engine.

### Gap G1 - Register Attribute Assets

`pubspec.yaml` currently registers the DB asset, but the new attribute images under `assets/tiki_taka/attrs/` must also be registered.

Expected result:

```yaml
flutter:
  assets:
    - assets/tiki_taka/attrs/
```

If Flutter does not include nested asset files from the parent entry in this project setup, register each subfolder:

```yaml
    - assets/tiki_taka/attrs/clubs/
    - assets/tiki_taka/attrs/leagues/
    - assets/tiki_taka/attrs/nations/
```

### Gap G2 - Resolve `icon_key` To SVG Asset Paths

The database stores `attributes.icon_key` values such as:

```text
club_31
nation_egypt
league_gb1
pos_fwd
```

The current SVG files are human-readable names such as:

```text
assets/tiki_taka/attrs/clubs/Liverpool.svg
assets/tiki_taka/attrs/nations/Egypt.svg
assets/tiki_taka/attrs/leagues/Premier-League.svg
```

Flutter needs a stable mapping from DB `icon_key` to asset path.

Recommended approach:

1. Keep human-readable filenames.
2. Add a generated or maintained manifest:

```text
assets/tiki_taka/attrs/manifest.json
```

Example:

```json
{
  "club_31": "assets/tiki_taka/attrs/clubs/Liverpool.svg",
  "nation_egypt": "assets/tiki_taka/attrs/nations/Egypt.svg",
  "league_gb1": "assets/tiki_taka/attrs/leagues/Premier-League.svg"
}
```

Alternative:

- Rename every asset file to match `icon_key`, for example `clubs/club_31.svg`.

Do not resolve assets from display names at runtime without a tested map. Accents, punctuation, and naming variants will create fragile UI bugs.

### Gap G3 - Add Asset Coverage Validation

Add a small validation script or extend D12 so every non-position attribute has an asset.

Rules:

- `club`, `nation`, and `league` attributes must resolve to an existing SVG.
- `position` attributes do not require images and render as text.
- Missing assets fail validation before Flutter work is considered complete.

### Gap G4 - Add Runtime SQLite Dependency

The smoke test uses `sqflite_common_ffi` as a dev dependency. The app runtime still needs the mobile Flutter SQLite dependency.

Expected:

- Add `sqflite` for device runtime.
- Add `path` and/or `path_provider` if the selected DB-opening approach copies the asset DB to an app-local file before opening.
- Keep the DB read-only from the app perspective.

### Gap G5 - Decide DB Asset Opening Strategy

Flutter cannot reliably open a bundled asset file directly as a mutable database on every platform. Use a dedicated `TikiTakaDatabase` service that:

1. Loads `assets/db/tiki_taka.db`.
2. Copies it to an app-local database path on first use or when `schema_version` / source hash changes.
3. Opens it read-only where supported, or enforces read-only behavior by never exposing write methods.
4. Closes the DB cleanly on app shutdown if needed.

### Gap G6 - Confirm Rules Are Locked

Use [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) as the locked v1 gameplay spec.

Resolved v1 decisions:

| Decision | v1 answer |
| --- | --- |
| Nation rule | Citizenship from player profile |
| Failed answer | Remove one heart; cell stays empty |
| Reuse player | Banned once per board |
| Default board template | Clubs x Nations |
| Default min intersection | 3 |
| Data source | Bundled SQLite only |
| Coach attributes | Deferred |

### Gap G7 - Confirm First Slice Does Not Reuse Classic/Shift Screen Directly

Existing `GameplayScreen` is built around Classic/Shift sessions, X/O marks, turns, and AI support. Tiki-Taka 1P has different state and UI.

Recommended:

- Add a dedicated `lib/features/tiki_taka/` feature.
- Reuse shared primitives where they fit, such as `WinChecker`, styling, routing patterns, dialogs, app scaffold, audio, and constants.
- Do not force Tiki-Taka through `GameCubit` if it creates turn-system or X/O leakage.

### Gap-to-Phase Map

| Gap | Phase | Deliverable |
| --- | --- | --- |
| G1 | Phase G1 | `pubspec.yaml` asset entries |
| G2 | Phase G2 | `manifest.json` + generator |
| G3 | Phase G3 | `validate_attribute_assets.py` |
| G4 | Phase G4 | Runtime `sqflite` deps |
| G5 | Phase G5 | DB contract doc + stubs |
| G6 | Phase G6 | Rules lock + doc alignment |
| G7 | Phase G7 | `lib/features/tiki_taka/` scaffold |
| All | Phase T0 | Preflight gate before T1 |

---

## Implementation Phases

Complete **Gap Closure Phases G1-G7** before **Flutter Phases T1-T12**.

Order:

```text
G1 -> G2 -> G3 -> G4 -> G5 -> G6 -> G7 -> T0 (gate) -> T1 -> ... -> T12
```

Every phase must be delivered as a small reviewable commit and pushed before moving to the next phase.

Suggested commit style:

```text
tiki-taka: <phase id> <short summary>
```

Examples:

```text
tiki-taka: G1 register attribute assets in pubspec
tiki-taka: G2 add icon_key asset manifest
tiki-taka: T3 add tiki-taka game engine
```

Each DoD below includes:

- Code/docs/tests complete for that phase.
- Relevant tests or validation commands pass.
- Phase changes are committed.
- Commit is pushed to remote.

---

## Gap Closure Phases (G1-G7)

These phases close the pre-Flutter gaps listed above. Do not start T1 until G1-G7 and T0 pass.

---

## Phase G1 - Register Attribute Assets

**Closes:** Gap G1

**Goal:** Register all Tiki-Taka attribute SVG folders so Flutter can load them at runtime.

**Tasks:**

1. Add asset entries to `pubspec.yaml` for `assets/tiki_taka/attrs/`.
2. If the parent folder entry does not bundle nested files on your Flutter version, register:
   - `assets/tiki_taka/attrs/clubs/`
   - `assets/tiki_taka/attrs/leagues/`
   - `assets/tiki_taka/attrs/nations/`
3. Run `flutter pub get`.
4. Add a minimal widget or test that loads one known SVG from each subfolder via `SvgPicture.asset`.

**DoD:**

- [x] `pubspec.yaml` lists all required Tiki-Taka attribute asset paths.
- [x] `flutter pub get` succeeds.
- [x] At least one club, league, and nation SVG loads without asset-not-found errors.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G2 - Attribute Asset Manifest (`icon_key` Mapping)

**Closes:** Gap G2

**Goal:** Provide a stable, testable map from DB `attributes.icon_key` to bundled SVG paths.

**Tasks:**

1. Choose and document the strategy:
   - **Preferred:** keep human-readable SVG filenames and add `assets/tiki_taka/attrs/manifest.json`, or
   - **Alternate:** rename files to match `icon_key` (e.g. `clubs/club_31.svg`).
2. If using a manifest, add a generator script, for example:
   - `tool/etl/generate_attribute_asset_manifest.py`
   - Input: allowlist YAMLs + current SVG filenames + SQLite `attributes` table (or staging attributes CSV).
   - Output: `assets/tiki_taka/attrs/manifest.json`
3. Manifest must cover every `club`, `nation`, and `league` row in the shipped DB.
4. Document manifest format in this file or a short comment at the top of `manifest.json`.
5. Register `manifest.json` in `pubspec.yaml` if not already covered by a parent asset entry.

**Manifest format** (`assets/tiki_taka/attrs/manifest.json`):

Flat JSON object mapping `attributes.icon_key` → Flutter asset path. Position rows are omitted.

```json
{
  "club_31": "assets/tiki_taka/attrs/clubs/Liverpool.svg",
  "league_gb1": "assets/tiki_taka/attrs/leagues/Premier-League.svg",
  "nation_egypt": "assets/tiki_taka/attrs/nations/Egypt.svg"
}
```

**Generation:** `python tool/etl/generate_attribute_asset_manifest.py`

- Input: shipped `assets/db/tiki_taka.db`, bundled SVG filenames, optional `tool/etl/config/attribute_asset_overrides.yaml`.
- Slug rule: `display_name` with spaces replaced by hyphens under `clubs/`, `nations/`, or `leagues/`.
- Output: `assets/tiki_taka/attrs/manifest.json` (84 entries for v1).

**DoD:**

- [x] Every shipped `club`, `nation`, and `league` `icon_key` maps to exactly one asset path.
- [x] `position` attributes are excluded from the manifest (text-only in UI).
- [x] Manifest is generated or maintained reproducibly (script or documented manual process).
- [x] No runtime resolution by raw `display_name` alone.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G3 - Asset Coverage Validation

**Closes:** Gap G3

**Goal:** Fail CI/local preflight when an attribute image is missing.

**Tasks:**

1. Add validation script, for example:
   - `tool/etl/validate_attribute_assets.py`
2. Script checks:
   - opens `assets/db/tiki_taka.db` or reads staging attribute tables,
   - loads `assets/tiki_taka/attrs/manifest.json` (or scans `icon_key` filenames),
   - asserts every `club`, `nation`, and `league` attribute resolves to an existing file,
   - skips `position` attributes.
3. Write report to `tool/etl/reports/validate_attribute_assets_summary.json`.
4. Exit non-zero on missing assets.
5. Optionally wire into `build_database.py` post-step or document as a required command before Flutter work.

**Validation command** (required before Flutter asset work):

```bash
python tool/etl/validate_attribute_assets.py
```

Writes `tool/etl/reports/validate_attribute_assets_summary.json` with pass/fail status, counts, and any missing manifest entries or SVG files.

**DoD:**

- [x] Validation script passes on the current repo (84 SVGs + full attribute set).
- [x] Removing or breaking one mapped asset causes validation to fail.
- [x] Report JSON is written on each run.
- [x] Command is documented in this file:

```bash
python tool/etl/validate_attribute_assets.py
```

- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G4 - Runtime SQLite Dependencies

**Closes:** Gap G4

**Goal:** Add Flutter runtime packages required to open the bundled database on device.

**Tasks:**

1. Add to `dependencies` in `pubspec.yaml`:
   - `sqflite` (runtime DB access)
   - `path` (path joining)
   - `path_provider` (app-local DB copy location)
2. Keep `sqflite_common_ffi` in `dev_dependencies` for tests.
3. Run `flutter pub get`.
4. Confirm no conflict with existing app dependencies.

**DoD:**

- [x] `sqflite`, `path`, and `path_provider` are runtime dependencies.
- [x] `sqflite_common_ffi` remains dev-only.
- [x] `flutter pub get` succeeds.
- [x] App still builds (`flutter analyze` clean or no new errors from dependency add).
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G5 - DB Opening Strategy And Contract

**Closes:** Gap G5

**Goal:** Document and scaffold how the app opens `assets/db/tiki_taka.db` read-only at runtime.

**Tasks:**

1. Add a short contract doc or section, for example:
   - `docs/tiki-taka-database-contract.md`
2. Document:
   - copy bundled asset to app-local path on first open,
   - re-copy when `meta.schema_version` or `source_csv_hash` changes,
   - open for read-only queries only,
   - no writes from app code,
   - lifecycle: open once per session or lazy singleton.
3. Add placeholder types only (no full DAO implementation yet):
   - `lib/features/tiki_taka/data/local/tiki_taka_database.dart` (interface or stub),
   - `lib/features/tiki_taka/data/local/tiki_taka_database_paths.dart`.
4. Align contract with [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) Section 19 (local DB, no live APIs).

**Contract:** [tiki-taka-database-contract.md](./tiki-taka-database-contract.md)

**DoD:**

- [x] DB opening strategy is written and reviewed.
- [x] Copy-on-first-use and schema/hash invalidation rules are explicit.
- [x] Stub files exist under `lib/features/tiki_taka/data/local/`.
- [x] Contract states app never writes to SQLite.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G6 - Rules Lock And Cross-Doc Alignment

**Closes:** Gap G6

**Goal:** Confirm v1 gameplay rules are locked and referenced consistently across docs.

**Tasks:**

1. Verify [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) Section 30 (Resolved Product Decisions) matches implementation intent.
2. Update [dataset-plan.md](./dataset-plan.md) open-decisions section to point at the rules doc (if not already).
3. Add a one-page **v1 rules checklist** in this file or the rules doc appendix:
   - 1 player, 5 hearts, timer, no AI, no turns,
   - failed answer costs heart,
   - duplicate player banned,
   - search must select DB player,
   - first win + optional full-board completion.
4. Mark any remaining open questions as **post-v1** explicitly.

### v1 Rules Checklist (locked)

Aligned with [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md) Appendix A and Section 30.

| Rule | v1 |
| --- | --- |
| 1 player | Yes — no opponent |
| 5 hearts | Yes — invalid guess costs 1 |
| Timer | Yes — continues after first win if user continues |
| No AI | Yes |
| No turns | Yes — no X/O, turn indicator, or move counter |
| Failed answer | Removes heart; cell stays empty |
| Duplicate player | Banned once per board |
| Search | Must select a player from DB search results |
| First win | First 3-in-a-row |
| Full-board completion | Optional after Continue Playing |

**Deferred post-v1:** local multiplayer (F1), AI opponent (F2), coach attributes (F3), national-team nation edges, dual citizenship, edit filled cells, rich board browser (F4).

**DoD:**

- [x] No unresolved v1 gameplay decisions block Flutter implementation.
- [x] [dataset-plan.md](./dataset-plan.md), [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md), and this file agree on v1 scope.
- [x] Multiplayer and coach attributes are marked deferred.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase G7 - Feature Architecture Scaffold

**Closes:** Gap G7

**Goal:** Create the dedicated Tiki-Taka feature module without coupling to Classic/Shift gameplay.

**Tasks:**

1. Create folder scaffold:

   ```text
   lib/features/tiki_taka/
   ├── data/
   │   ├── local/
   │   │   └── daos/
   │   └── models/
   ├── domain/
   │   ├── logic/
   │   └── services/
   └── presentation/
      ├── screens/
      ├── state/
      └── widgets/
   ```

2. Add `lib/features/tiki_taka/README.md` documenting:
   - dedicated feature (not `GameCubit` / `GameplayScreen`),
   - reusable shared pieces: `WinChecker`, theme, routing, audio, scaffold,
   - forbidden reuse: X/O turn UI, move counter, AI session config.
3. Do **not** add home entry or routing yet (that is Phase T9).

**Scaffold:** `lib/features/tiki_taka/README.md` documents layout, allowed reuse, and forbidden Classic/Shift coupling.

**DoD:**

- [x] `lib/features/tiki_taka/` scaffold exists.
- [x] README states Tiki-Taka is separate from Classic/Shift engines.
- [x] No changes to Classic/Shift gameplay behavior in this phase.
- [x] `flutter analyze` passes.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T0 - Preflight Gate

**Goal:** Verify all gap-closure work (G1-G7) before starting gameplay implementation (T1+).

**Tasks:**

1. Run database QA:

   ```bash
   python tool/etl/run_validation_cases.py
   flutter test test/tiki_taka_database_smoke_test.dart
   ```

2. Run asset QA:

   ```bash
   python tool/etl/validate_attribute_assets.py
   ```

3. Manually confirm checklist:
   - [x] G1 pubspec assets registered
   - [x] G2 manifest complete
   - [x] G3 asset validation passes
   - [x] G4 runtime deps added
   - [x] G5 DB contract documented
   - [x] G6 rules locked
   - [x] G7 feature scaffold present
4. Record gate result in `tool/etl/reports/tiki_taka_preflight_gate.json` (optional script or manual note in commit message).

**Gate runner:**

```bash
python tool/etl/run_tiki_taka_preflight_gate.py
```

Runs D12 validation, G3 asset coverage, G1–G7 artifact checks, and Tiki-Taka Flutter tests. Writes `tool/etl/reports/tiki_taka_preflight_gate.json`.

**DoD:**

- [x] D12 validation passes (10/10 or current case count).
- [x] DB smoke test passes.
- [x] Asset coverage validation passes.
- [x] All G1-G7 DoD items checked.
- [x] No blocking gaps remain before T1.
- [x] Phase changes are committed (gate report or checklist update).
- [x] Commit is pushed to remote.

---

## Phase T1 - Runtime Database Foundation

**Goal:** Add the runtime database service used by all Tiki-Taka data access code.

**Target files:**

   ```text
   lib/features/tiki_taka/data/local/tiki_taka_database.dart
   lib/features/tiki_taka/data/local/tiki_taka_database_paths.dart
   test/features/tiki_taka/data/local/tiki_taka_database_test.dart
   ```

**Depends on:** G4, G5, T0

**Tasks:**

1. Implement `TikiTakaDatabase` per G5 contract (replace G5 stubs).
2. Copy bundled DB asset to an app-local path when needed.
3. Open DB for read operations.
4. Read and verify `meta.schema_version`.
5. Expose a safe lifecycle API:
   - `open()`,
   - `database`,
   - `close()`.
6. Keep write operations out of public APIs.
7. Invalidate/re-copy local DB when `schema_version` or `source_csv_hash` changes.

**DoD:**

- [x] DB opens on Flutter runtime code path.
- [x] `meta.schema_version` is readable.
- [x] Missing DB asset returns a controlled error state.
- [x] Unit test verifies DB open and core table availability.
- [x] `flutter test` passes for new and existing Tiki-Taka DB tests.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T2 - Data Models And DAOs

**Goal:** Provide typed reads for boards, attributes, players, search, and validation.

**Target files:**

```text
lib/features/tiki_taka/data/models/tiki_attribute.dart
lib/features/tiki_taka/data/models/tiki_board.dart
lib/features/tiki_taka/data/models/tiki_board_slot.dart
lib/features/tiki_taka/data/models/tiki_player_search_result.dart
lib/features/tiki_taka/data/local/daos/board_dao.dart
lib/features/tiki_taka/data/local/daos/player_search_dao.dart
lib/features/tiki_taka/data/local/daos/validation_dao.dart
```

**Tasks:**

1. Model `attributes`, `boards`, `board_slots`, and player search results.
2. Implement `BoardDao`:
   - load board by id,
   - load random/default board,
   - load rows and columns in slot order,
   - prefer Clubs x Nations for default board selection.
3. Implement `PlayerSearchDao`:
   - prefix search on `players.search_text`,
   - alias search via `player_aliases`,
   - dedupe players by id,
   - return display name and optional cached metadata.
4. Implement `ValidationDao` with the exact independent AND rule:

   ```sql
   SELECT DISTINCT p.id, p.display_name
   FROM players p
   INNER JOIN player_attributes a
   ON a.player_id = p.id AND a.attribute_id = :row_attr
   INNER JOIN player_attributes b
   ON b.player_id = p.id AND b.attribute_id = :col_attr
   WHERE p.id = :player_id
   LIMIT 1;
   ```

5. Add DAO tests using known D12 cases.

**DoD:**

- [x] Board DAO loads a board with exactly 3 row attributes and 3 column attributes.
- [x] Attribute order matches `slot_kind` and `slot_index`.
- [x] Search supports full names and aliases.
- [x] Search is accent-insensitive through existing normalized DB fields.
- [x] Validation passes Salah Egypt x Liverpool.
- [x] Validation fails a known invalid case.
- [x] Duplicate search results are deduped by `player_id`.
- [x] Tests pass.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T3 - Domain Services And Game Engine

**Goal:** Implement the 1P game rules without UI.

**Target files:**

```text
lib/features/tiki_taka/domain/models/tiki_cell.dart
lib/features/tiki_taka/domain/models/tiki_game_status.dart
lib/features/tiki_taka/domain/models/tiki_game_state.dart
lib/features/tiki_taka/domain/services/answer_validator.dart
lib/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart
test/features/tiki_taka/domain/logic/tiki_taka_game_engine_test.dart
```

**Tasks:**

1. Define game state:
   - `initial`,
   - `loadingBoard`,
   - `ongoing`,
   - `firstWin`,
   - `continuing`,
   - `completed`,
   - `lost`.
2. Track:
   - board,
   - 9 cells,
   - selected player per filled cell,
   - used player IDs,
   - hearts,
   - elapsed time,
   - winning line if present.
3. Implement `AnswerValidator`:
   - checks DAO validation,
   - blocks duplicate `player_id`,
   - returns valid/invalid reason.
4. Implement `TikiTakaGameEngine`:
   - valid answer fills cell,
   - invalid answer removes one heart,
   - occupied cells cannot be changed,
   - hearts reaching 0 sets `lost`,
   - first 3-in-row sets `firstWin`,
   - continue action sets `continuing`,
   - full board sets `completed`.
5. Reuse `WinChecker` if practical; otherwise add a Tiki-specific wrapper around the same 8 line definitions.

**DoD:**

- [x] Starting hearts = 5.
- [x] Valid answer fills the selected cell.
- [x] Invalid answer leaves cell empty and removes one heart.
- [x] Duplicate player is invalid and removes one heart.
- [x] Occupied cell cannot be edited.
- [x] Hearts reaching 0 produces `lost`.
- [x] First line produces `firstWin`.
- [x] Continue keeps existing board and cells.
- [x] Completing all 9 cells produces `completed`.
- [x] Engine tests pass.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T4 - State Management

**Goal:** Connect DAOs and domain logic to presentation with a Cubit or equivalent state controller.

**Target files:**

```text
lib/features/tiki_taka/presentation/state/tiki_taka_cubit.dart
lib/features/tiki_taka/presentation/state/tiki_taka_state.dart
test/features/tiki_taka/presentation/state/tiki_taka_cubit_test.dart
```

**Tasks:**

1. Load a board on screen start.
2. Start timer when board becomes playable.
3. Stop timer when:
   - user loses,
   - user completes full board,
   - user exits match.
4. Keep timer running after first win if user chooses Continue Playing.
5. Expose actions:
   - load board,
   - search players,
   - select player for cell,
   - continue after first win,
   - restart,
   - pause/resume timer if needed,
   - exit.
6. Handle rapid taps and dialogs safely.

**DoD:**

- [x] Cubit loads a playable board.
- [x] Cubit exposes row and column header data.
- [x] Timer starts after board load.
- [x] Timer stops on lost/completed/exit.
- [x] Invalid selection reduces hearts through state.
- [x] Valid selection fills cell through state.
- [x] Restart clears cells, used players, timer, and hearts.
- [x] State tests cover lifecycle and edge cases.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T5 - Attribute Header Assets UI

**Depends on:** G1, G2, G3

**Goal:** Render board headers with images for clubs/leagues/nations and text for positions.

**Target files:**

```text
lib/features/tiki_taka/presentation/widgets/tiki_attribute_header.dart
lib/features/tiki_taka/presentation/widgets/tiki_attribute_icon.dart
lib/features/tiki_taka/presentation/widgets/tiki_board_frame.dart
test/features/tiki_taka/presentation/widgets/tiki_attribute_header_test.dart
```

**Tasks:**

1. Implement asset path resolution using G2 manifest (not display-name guessing).
2. Render:
   - club SVGs,
   - league SVGs,
   - nation SVGs,
   - position labels as text.
3. Add fallback display:
   - label initials or text,
   - visible error-safe placeholder,
   - no crash on missing optional icon.
4. Keep headers readable at phone sizes.
5. Add semantic labels for accessibility.

**DoD:**

- [x] Club header displays SVG.
- [x] Nation header displays SVG.
- [x] League header displays SVG.
- [x] Position header displays text only.
- [x] Missing asset has a graceful fallback.
- [x] Header labels remain accessible to screen readers.
- [x] Widget tests pass for all attribute types.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T6 - Tiki-Taka Board Screen Skeleton

**Goal:** Build the playable screen layout without search/dialog completion polish.

**Target files:**

```text
lib/features/tiki_taka/presentation/screens/tiki_taka_gameplay_screen.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_board.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_cell.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_hud.dart
```

**Tasks:**

1. Build the 3 x 3 playable grid.
2. Display 3 column attributes above the grid.
3. Display 3 row attributes on the left.
4. Display hearts and timer.
5. Do not display:
   - turn indicator,
   - X/O active player,
   - move counter,
   - opponent panel,
   - AI panel.
6. Tapping an empty cell triggers a placeholder search action.
7. Filled cells show player display name as text.
8. Keep cell size fixed; text adapts to the cell.

**DoD:**

- [x] Board screen renders from a real board loaded from SQLite.
- [x] 3 row headers and 3 column headers appear.
- [x] Hearts and timer appear.
- [x] No Classic/Shift turn UI appears.
- [x] Empty cell tap is handled.
- [x] Occupied cell tap is ignored or explained.
- [x] Long player names do not overflow.
- [x] Basic widget/golden/layout tests pass where practical.
- [x] Phase changes are committed.
- [x] Commit is pushed to remote.

---

## Phase T7 - Player Search Dialog

**Goal:** Implement the search-and-select flow for a cell.

**Target files:**

```text
lib/features/tiki_taka/presentation/widgets/player_search_dialog.dart
lib/features/tiki_taka/presentation/widgets/player_search_result_tile.dart
```

**Tasks:**

1. Open dialog after tapping an empty cell.
2. Show selected row and column attributes in the dialog.
3. Provide search input.
4. Search local DB as user types.
5. Show empty state for no results.
6. Require selecting a database player; do not allow raw free-text submit.
7. On selection, call Cubit validation flow.
8. Close dialog after valid answer or controlled invalid feedback.

**DoD:**

- [ ] Dialog shows cell context.
- [ ] Search returns players by full name.
- [ ] Search returns players by alias.
- [ ] Empty search state is clear.
- [ ] User cannot submit unselected free text.
- [ ] Selecting valid player fills the cell.
- [ ] Selecting invalid player removes one heart and leaves cell empty.
- [ ] Dialog/cubit tests pass.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Phase T8 - Outcome Dialogs And Flow Polish

**Goal:** Complete first-win, continue, completed, lost, restart, and exit flows.

**Target files:**

```text
lib/features/tiki_taka/presentation/widgets/tiki_taka_first_win_dialog.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_completion_dialog.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_lost_dialog.dart
lib/features/tiki_taka/presentation/widgets/tiki_taka_pause_sheet.dart
```

**Tasks:**

1. Show first-win dialog when user gets 3 in a row.
2. First-win dialog includes:
   - Continue Playing,
   - Restart,
   - Go Home.
3. Continue Playing keeps timer running.
4. Full-board completion dialog includes:
   - completion time,
   - hearts remaining,
   - Restart,
   - Go Home.
5. Lost dialog appears at 0 hearts.
6. Restart resets board state according to rules.
7. Exit stops timer and returns home.
8. Handle first win and full completion happening close together.

**DoD:**

- [ ] First win dialog appears once per board.
- [ ] Continue Playing keeps existing filled cells.
- [ ] Timer continues after Continue Playing.
- [ ] Full board completion stops timer.
- [ ] Lost state stops timer.
- [ ] Restart resets all state.
- [ ] Home exit works from all terminal dialogs.
- [ ] Edge-case tests pass.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Phase T9 - Routing And Home Entry

**Goal:** Make Tiki-Taka accessible from the app without disrupting Classic or Shift.

**Target files:**

```text
lib/core/routing/app_routes.dart
lib/core/routing/app_router.dart
lib/features/home/presentation/screens/home_screen.dart
lib/features/game/domain/models/game_mode.dart
```

**Tasks:**

1. Add a Tiki-Taka route or game mode entry.
2. Decide whether Tiki-Taka uses:
   - a dedicated route, recommended, or
   - `GameMode.tikiTaka` with a separate screen branch.
3. Add home card / CTA for Tiki-Taka.
4. Keep existing Shift, Classic, and AI flows unchanged.
5. Add navigation tests if current test patterns support them.

**DoD:**

- [ ] User can launch Tiki-Taka from home.
- [ ] Existing Shift and Classic launch paths still work.
- [ ] Back/home behavior is consistent with the app.
- [ ] No Tiki-Taka route leaks X/O gameplay state.
- [ ] Navigation smoke tests pass where practical.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Phase T10 - How To Play, Copy, And User Education

**Goal:** Explain Tiki-Taka rules in-app.

**Target files:**

```text
lib/features/how_to_play/presentation/screens/how_to_play_screen.dart
lib/features/how_to_play/presentation/widgets/
```

**Tasks:**

1. Add Tiki-Taka rules section:
   - match row + column,
   - select a database player,
   - wrong answer costs heart,
   - duplicate player banned,
   - first line wins,
   - full board challenge.
2. Explain hearts and timer.
3. Explain attribute images and position text.
4. Avoid mentioning Transfermarkt internals to users.

**DoD:**

- [ ] How-to-play includes Tiki-Taka.
- [ ] Copy matches [tiki-taka-toe-rules.md](./tiki-taka-toe-rules.md).
- [ ] Rules do not conflict with implemented behavior.
- [ ] Existing how-to-play sections still render correctly.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Phase T11 - Integration Testing And Regression Pack

**Goal:** Prove the full feature works against the shipped DB.

**Tasks:**

1. Keep `test/tiki_taka_database_smoke_test.dart`.
2. Add DAO integration tests for:
   - board load,
   - player search,
   - answer validation.
3. Add game flow tests for:
   - valid answer,
   - invalid answer,
   - duplicate answer,
   - first win,
   - continue,
   - completed,
   - lost.
4. Add widget tests for:
   - no turn indicator,
   - hearts visible,
   - timer visible,
   - header assets,
   - long player names.
5. Run ETL validations:

   ```bash
   python tool/etl/run_validation_cases.py
   ```

6. Run Flutter tests:

```bash
flutter test
```

**DoD:**

- [ ] D12 validation passes.
- [ ] DB smoke test passes.
- [ ] DAO tests pass.
- [ ] Game engine tests pass.
- [ ] Widget tests pass.
- [ ] Full `flutter test` passes.
- [ ] No new linter errors.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Phase T12 - Performance, Size, And Release Readiness

**Goal:** Make the feature shippable.

**Tasks:**

1. Check app size impact from:
   - SQLite DB,
   - SVG attribute assets,
   - SQLite dependencies.
2. Verify DB remains under target size unless product accepts a new limit.
3. Verify SVG rendering is smooth on low-end devices.
4. Confirm search latency is acceptable.
5. Add loading and error states:
   - DB missing/corrupt,
   - no boards,
   - no search results,
   - asset fallback.
6. Run manual QA on a physical Android device if available.
7. Verify app works offline.

**DoD:**

- [ ] App works offline.
- [ ] Tiki-Taka screen loads without network.
- [ ] Board load is fast.
- [ ] Search feels responsive.
- [ ] Attribute SVGs do not noticeably bloat app size.
- [ ] DB copy/open path works after app reinstall.
- [ ] Corrupt/missing DB shows controlled error.
- [ ] Release build succeeds.
- [ ] Manual smoke test passes on device/emulator.
- [ ] Phase changes are committed.
- [ ] Commit is pushed to remote.

---

## Future Phases Not In v1

Do not start these until the 1 Player Mode is shipped and stable.

### Future F1 - Local Multiplayer

Adds:

- Player X and Player O.
- Turn switching.
- Square ownership.
- Failed-answer multiplayer rule.
- Possible steal mechanic.

### Future F2 - AI Opponent

Adds:

- Bot player selection.
- Knowledge-aware answer picking.
- Difficulty balancing.

### Future F3 - Coach Attributes

Adds:

- Coach ETL from `games.csv` and `game_lineups.csv`.
- `coach:{slug}` attributes.
- Coach images or text labels.
- New D12 validation cases.

### Future F4 - Rich Board Browser

Adds:

- Board list.
- Difficulty filtering.
- Featured board selection.
- Board completion history.

---

## Recommended First Implementation Slice

Complete gap closure first, then prove the vertical slice:

**Gap closure (required before gameplay):**

1. G1 - Register Attribute Assets
2. G2 - Attribute Asset Manifest
3. G3 - Asset Coverage Validation
4. G4 - Runtime SQLite Dependencies
5. G5 - DB Opening Strategy And Contract
6. G6 - Rules Lock And Cross-Doc Alignment
7. G7 - Feature Architecture Scaffold
8. T0 - Preflight Gate

**Flutter vertical slice (after T0):**

1. T1 - Runtime Database Foundation
2. T2 - Data Models And DAOs
3. T5 - Attribute Header Assets UI
4. T6 - Board Screen Skeleton

This slice proves:

- all pre-Flutter gaps are closed,
- the DB opens in the app,
- a real board loads,
- headers render with the new SVG assets,
- the board layout matches the rules,
- existing Classic/Shift modes remain untouched.

After that, implement engine (T3-T4), search (T7), dialogs (T8), routing (T9), how-to-play (T10), and release polish (T11-T12).

---

## Phase Summary

| Phase | Type | Goal |
| --- | --- | --- |
| G1 | Gap | Register attribute SVG assets in pubspec |
| G2 | Gap | `icon_key` to SVG manifest |
| G3 | Gap | Asset coverage validation script |
| G4 | Gap | Runtime SQLite dependencies |
| G5 | Gap | DB opening strategy and contract |
| G6 | Gap | Rules lock and doc alignment |
| G7 | Gap | Feature architecture scaffold |
| T0 | Gate | Preflight: all gaps closed |
| T1 | Flutter | Runtime database implementation |
| T2 | Flutter | Models and DAOs |
| T3 | Flutter | Game engine and validator |
| T4 | Flutter | Cubit / state management |
| T5 | Flutter | Attribute header UI |
| T6 | Flutter | Board screen skeleton |
| T7 | Flutter | Player search dialog |
| T8 | Flutter | Outcome dialogs and flow |
| T9 | Flutter | Routing and home entry |
| T10 | Flutter | How-to-play copy |
| T11 | Flutter | Integration tests |
| T12 | Flutter | Performance and release readiness |
