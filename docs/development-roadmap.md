<!-- markdownlint-configure-file {"MD060": false} -->

# ShiftTac — Development Roadmap

> **Tagline:** "Every move changes the board."
> **Document role:** Execution contract · Scope controller · Implementation sequence.

This document is the **single source of truth** for *what gets built, in what order, and when each thing is done*.
It binds together the four foundational specs:

- `docs/design.md` — visual identity, screens, motion
- `docs/rules.md` — gameplay rules and engine behavior
- `docs/implementation-rules.md` — engineering guardrails
- `docs/structure.md` — folder & file hierarchy

If anything in this roadmap conflicts with the four documents above, **those documents win**. This file only sequences and bounds the work.

---

## 0. How to Use This Roadmap

### 0.1 Core Working Rules

1. **Sequential by default.** Phases are executed in order. A phase only begins when the previous phase's Acceptance Criteria are 100% satisfied.
2. **No scope creep.** Anything not listed in a phase's "Scope In" is explicitly out of scope for that phase. Defer it to `Section 19 — Deferred Backlog`.
3. **Deterministic outputs.** Each phase has a fixed file list (`Deliverables`). Do not introduce extra files, folders, or abstractions except paths explicitly allowed in **Section 2.1** for the owning phase.
4. **Test the brain before the face.** Logic phases (engine, win checker, cubit) ship with tests before any UI consumes them.
5. **Vertical slice mindset.** Once Phase 7 is done, the game is playable end-to-end. Everything after Phase 7 is polish, depth, and surrounding screens.
6. **Respect the hero.** The board is the hero (`design.md §1.4`, `implementation-rules.md §4`). Never let a phase compromise board clarity to add chrome.

### 0.2 Definition of "Done" (Global)

A phase is **DONE** only when **all** of the following are true:

- [ ] All `Deliverables` files exist and compile.
- [ ] `flutter analyze` returns **0 errors / 0 warnings** for the phase's files.
- [ ] All `Acceptance Criteria` checks pass manually or via tests.
- [ ] No file added outside the phase's `Deliverables` list and **Section 2.1** (no stray helpers, no parallel folders).
- [ ] The phase does not modify files outside its `Touch Scope` unless explicitly allowed.
- [ ] Code follows `implementation-rules.md` (no premature DI, no repositories, no service layers, no business logic in widgets).

### 0.3 Determinism Contract

Every phase must produce the **same** files, the **same** public APIs, and the **same** state shape regardless of who executes it. To enforce this:

- File paths come from `structure.md` verbatim, **except** paths listed in **Section 2.1 — Roadmap-Approved Structure Extensions**. No renames of listed paths.
- Public class/method names are defined in this roadmap. No synonyms.
- State shape (Phase 4) is defined as a frozen contract. No fields added/removed without amending this document.

---

## 1. Guiding Principles (Carried Across All Phases)

| # | Principle | Source |
|---|-----------|--------|
| P1 | Logic outside the UI. Game rules live in `features/game/domain/logic/`. | `implementation-rules.md §2` |
| P2 | Feature-based folders. No generic `data/`, `services/`, `repositories/`. | `structure.md`, `implementation-rules.md §2` |
| P3 | Cubit holds authoritative UI state. No duplicated state in widgets. | `implementation-rules.md §3` |
| P4 | Active move queues are the source of truth; board is derived. | `rules.md §Source of Truth` |
| P5 | FIFO order: **remove oldest → place new → evaluate win**. Never reorder. | `rules.md §7` |
| P6 | Animations are visual-only. State never waits for animation. | `rules.md §Animation Rules`, `implementation-rules.md §5` |
| P7 | Use `flutter_screenutil` for responsive sizing; initialize once in `app.dart`. | `implementation-rules.md §12` |
| P8 | Use design tokens from `design.md`. No magic colors, magic spacing, magic durations. | `implementation-rules.md §6` |
| P9 | Implement incrementally. Small completed milestones over giant changesets. | `implementation-rules.md §10` |
| P10 | No draw state. The game continues until a player wins. | `rules.md §8` |

---

## 2. Tech Stack Lock-In

These are **fixed** for the MVP. Do not add or swap libraries during phases.

| Concern | Choice |
|---------|--------|
| Framework | Flutter (Dart SDK `^3.10.3` per current `pubspec.yaml`) |
| State management | `flutter_bloc` (Cubit only — no full BLoC) |
| Responsive sizing | `flutter_screenutil` |
| Equality / immutability | `equatable` |
| Routing | Simple `Navigator` + named routes via `core/routing/` (no `go_router` for MVP) |
| Persistence | **None** for MVP (no settings save, no stats save) — see Backlog |
| Audio | **Deferred** to **Phase 16** (Audio Layer). Earlier phases may omit SFX entirely or no-op; **Phase 14** is motion polish only. |
| Haptics | `HapticFeedback` from `flutter/services.dart` (built-in) |
| Testing | `flutter_test` only |
| Fonts | Google Fonts `Poppins` (headings) + `Nunito Sans` (body) — bundled via `google_fonts` package |

> **Rule:** If a phase needs something not on this list, **stop** and amend this section before adding the dependency.

### 2.1 Roadmap-Approved Structure Extensions (Beyond `structure.md`)

`docs/structure.md` is the baseline tree. The following paths are **intentional roadmap-level extensions** (not scope creep). No other paths may be added without amending this section and the affected phase(s).

| Path | Introduced | Purpose |
|------|------------|---------|
| `lib/features/game/domain/models/move.dart` | P3 | `Move` model (listed in `structure.md`; retained here as explicit contract anchor). |
| `lib/features/game/domain/logic/game_snapshot.dart` | P5 | Immutable `GameSnapshot` (split from single `game_engine.dart` file if preferred). |
| `lib/core/settings/app_settings_controller.dart` | P13 | Shared in-memory settings (`AppSettingsController`); no persistence. |
| `lib/core/audio/app_audio.dart` | P16 | SFX wrapper; reads `soundEffectsEnabled` from `AppSettingsController`. |
| `docs/qa-checklist.md` | P18 | Manual responsive QA log. |
| `test/edge_cases_test.dart` | P18 | Consolidated edge-case tests (additional focused test files under `test/` are allowed if named per Section 16 and tied to an owning phase). |

**Shared settings (MVP):** A single **`AppSettingsController`** instance lives at the app root (provided from `lib/app.dart` without any DI package). It is **in-memory only** — holds `soundEffectsEnabled`, `musicEnabled`, and `vibrationEnabled` via `ChangeNotifier` or `ValueNotifier`/`Listenable` pattern; resets to defaults on cold start. **No** `SharedPreferences`, repositories, services layer, or injectors.

---

## 3. Milestone Map (Bird's-Eye View)

```text
M0  Foundation         ─► Repo cleanup, pubspec, theme tokens, app shell, routing skeleton
M1  Game Brain         ─► Domain models + engine + win checker (+ unit tests)
M2  Game State Layer   ─► GameCubit + GameState (+ cubit tests)
M3  Playable Slice     ─► Gameplay screen + board + cells + win dialog  ◄── FIRST PLAYABLE
M4  Surrounding UX     ─► Home, Splash, Onboarding, How to Play, Settings
M5  Feel & Motion      ─► Animations, faded-mark polish, input lock, haptics
M6  Audio & Icon       ─► Sound effects, app icon, splash polish
M7  Hardening          ─► Edge case tests, responsive QA, accessibility pass
M8  Release Prep       ─► README, versioning, build configs, store-ready assets
```

Each milestone is broken into numbered phases below.

---

## 4. Phase Index

| Phase | Milestone | Title | Status |
|-------|-----------|-------|--------|
| P0 | M0 | Project Foundation & Cleanup | Done |
| P1 | M0 | Design System Tokens (Theme, Colors, Typography, Spacing) | Done |
| P2 | M0 | App Shell, Routing Skeleton, Shared Widgets | Pending |
| P3 | M1 | Game Domain Models | Pending |
| P4 | M1 | Win Checker | Pending |
| P5 | M1 | Game Engine (FIFO + Turn Lifecycle) | Pending |
| P6 | M2 | Game State + Cubit | Pending |
| P7 | M3 | Gameplay Screen (First Playable) | Pending |
| P8 | M3 | Win Dialog & Pause Bottom Sheet | Pending |
| P9 | M4 | Home Screen | Pending |
| P10 | M4 | Splash Screen | Pending |
| P11 | M4 | Onboarding (3 Screens) | Pending |
| P12 | M4 | How to Play Screen | Pending |
| P13 | M4 | Settings Screen | Pending |
| P14 | M5 | Animations & Motion Polish | Pending |
| P15 | M5 | Haptics & Input Lock Hardening | Pending |
| P16 | M6 | Audio Layer | Pending |
| P17 | M6 | App Icon & Splash Polish | Pending |
| P18 | M7 | Edge Case Tests & Responsive QA | Pending |
| P19 | M7 | Accessibility Pass | Pending |
| P20 | M8 | Release Prep (README, Build, Versioning) | Pending |

---

## PHASES

Each phase below follows the same shape:

> **Goal** · **Scope In** · **Scope Out** · **Touch Scope** · **Deliverables** · **Tasks** · **Acceptance Criteria** · **Dependencies** · **Risks**

---

## Phase 0 — Project Foundation & Cleanup

**Goal:** Replace the Flutter starter scaffold with a clean ShiftTac shell, and add the locked-in dependencies.

**Scope In:**

- Strip starter counter app from `lib/main.dart`.
- Update `pubspec.yaml` with dependencies from Section 2.
- Create the empty folder tree from `docs/structure.md`.
- Update `pubspec.yaml` `name`, `description`, asset declarations placeholders (paths only, no real assets yet).
- Update `README.md` with a 1-paragraph project intro + link to `docs/`.

**Scope Out:**

- Any theming or token implementation (Phase 1).
- Any screen UI (Phase 2+).
- Any actual asset files (added in their owning phases).

**Touch Scope:** `pubspec.yaml`, `lib/main.dart`, `README.md`, create `lib/core/`, `lib/features/`, `lib/shared/`, `assets/` subfolders, `test/`.

**Deliverables:**

- `pubspec.yaml` updated with: `flutter_bloc`, `equatable`, `flutter_screenutil`, `google_fonts`.
- `lib/main.dart` reduced to a minimal `runApp(const ShiftTacApp())` placeholder.
- `lib/app.dart` placeholder (returns a blank `MaterialApp` with the title `"ShiftTac"`).
- Empty folder scaffolding matching `structure.md` (use `.gitkeep` if needed).
- `README.md` rewritten (~1 page).

**Acceptance Criteria:**

- [x] `flutter pub get` succeeds.
- [x] `flutter analyze` returns 0 issues.
- [x] `flutter run` boots to a blank screen titled "ShiftTac" without errors.
- [x] Folder tree matches `structure.md` exactly (empty folders allowed).
- [x] Roadmap **Section 2.1** paths (e.g. `lib/core/settings/`, `lib/core/audio/`) are **not** required in P0 — they appear in their owning phases.
- [x] No leftover starter code (`_counter`, `MyHomePage`, etc.).

**Dependencies:** None.

**Risks:**

- Mis-pinning Dart SDK. **Mitigation:** keep `sdk: ^3.10.3`.
- Adding unlisted packages "while we're here". **Mitigation:** Section 2 is the lock list.

---

## Phase 1 — Design System Tokens

**Goal:** Encode every color, font, spacing, radius, and animation duration from `design.md` into reusable Dart constants. This phase is **pure data, no widgets**.

**Scope In:**

- `app_colors.dart` — every color from the `design.md` frontmatter + the primary palette (Warm Ivory, Soft Mist, Teal, Deep Teal, Soft Coral, Warm Gold, Ink Navy, Faded Mark Opacity).
- `app_text_styles.dart` — text styles for `display-lg`, `title-md`, `headline-sm`, `body-lg`, `body-md`, `label-bold`, `label-sm`, wired through `google_fonts` (Poppins / Nunito Sans).
- `app_spacing.dart` — `unit (4)`, `containerPadding (24)`, `gridGutter (12)`, `stackSm (8)`, `stackMd (16)`, `stackLg (32)`, plus radii `sm/default/md/lg/xl/full`.
- `app_theme.dart` — Light theme `ThemeData` built from the above tokens.
- `app_constants.dart` — app-wide constants (app name, version label, base design size `Size(390, 844)`).
- `game_constants.dart` — gameplay constants: `maxActiveMarks = 3`, `boardRows = 3`, `boardCols = 3`, `inputLockMs = 140`, `tapFeedbackMs = 140`, `movePlacementMs = 200`, `fadeRemovalMs = 250`, `dialogEntranceMs = 280`, `fadedMarkOpacity = 0.45`.

**Scope Out:**

- Dark theme (Backlog).
- Any widget consuming these tokens (next phases).

**Touch Scope:** `lib/core/theme/*`, `lib/core/constants/*`.

**Deliverables:**

```text
lib/core/theme/app_colors.dart
lib/core/theme/app_text_styles.dart
lib/core/theme/app_spacing.dart
lib/core/theme/app_theme.dart
lib/core/constants/app_constants.dart
lib/core/constants/game_constants.dart
```

**Acceptance Criteria:**

- [x] Every named color in `design.md` appears as a `static const Color` in `AppColors`.
- [x] Every typography role in `design.md` appears in `AppTextStyles`.
- [x] All numeric magic values used later (durations, opacities, sizes) live in `app_spacing.dart` or `game_constants.dart`.
- [x] `AppTheme.light` returns a `ThemeData` with `scaffoldBackgroundColor = AppColors.warmIvory`.
- [x] `flutter analyze` clean.

**Dependencies:** Phase 0.

**Risks:**

- Drifting from the design tokens. **Mitigation:** copy values verbatim from `design.md` frontmatter and §4.

---

## Phase 2 — App Shell, Routing & Shared Widgets

**Goal:** Wire `ScreenUtil`, the theme, and a route table. Add the *truly shared* widgets that every later screen will reuse.

**Scope In:**

- `app.dart` initializing `ScreenUtilInit(designSize: Size(390, 844))` and `MaterialApp` with `AppTheme.light`.
- `core/routing/app_routes.dart` — string route names (`/splash`, `/onboarding`, `/home`, `/game`, `/how-to-play`, `/settings`).
- `core/routing/app_router.dart` — `Route<dynamic>? onGenerateRoute(...)` mapping route names → temporary `Placeholder` screens (real screens replace placeholders in their own phases).
- `core/widgets/app_scaffold.dart` — base scaffold with warm ivory background, optional header slot, safe area, consistent horizontal padding.
- `core/widgets/primary_button.dart` — Teal CTA, Poppins SemiBold, rounded `lg`, tactile feedback.
- `core/widgets/secondary_button.dart` — outline / muted variant.
- `shared/widgets/infinity_logo.dart` — minimal infinity symbol with embedded X/O (static vector, no animation yet — animation added in Phase 10).
- `shared/widgets/app_icon_button.dart` — circular icon button used in headers.
- `shared/widgets/screen_header.dart` — header row (back · center logo · right action).

**Scope Out:**

- Real screen contents (each gets its own phase).
- Motion / shared animations (Phase 14).

**Touch Scope:** `lib/app.dart`, `lib/main.dart`, `lib/core/routing/*`, `lib/core/widgets/*`, `lib/shared/widgets/*`.

**Deliverables:**

```text
lib/app.dart
lib/core/routing/app_routes.dart
lib/core/routing/app_router.dart
lib/core/widgets/app_scaffold.dart
lib/core/widgets/primary_button.dart
lib/core/widgets/secondary_button.dart
lib/core/utils/extensions.dart            (BuildContext helpers: theme/textStyles/colors)
lib/shared/widgets/infinity_logo.dart
lib/shared/widgets/app_icon_button.dart
lib/shared/widgets/screen_header.dart
```

**Acceptance Criteria:**

- [ ] App boots to `/splash` route (placeholder allowed) on Warm Ivory background.
- [ ] All routes resolve without `Navigator` errors.
- [ ] `PrimaryButton` and `SecondaryButton` render correctly with theme colors.
- [ ] `InfinityLogo` renders crisply at multiple sizes (test at 24, 48, 96 logical px).
- [ ] No widget hardcodes a color, font, or spacing value — all flow from `core/theme`.

**Dependencies:** Phases 0, 1.

**Risks:**

- Premature animation in `InfinityLogo`. **Mitigation:** keep it static here; animate in Phase 10.

---

## Phase 3 — Game Domain Models

**Goal:** Define the immutable data primitives the engine and UI both speak. No logic yet — just types.

**Scope In:**

- `Player` enum: `x`, `o` (with helper `opponent`).
- `Position` value object: `row`, `col` (both `0..2`). Implements `Equatable`. Provides `index` getter (0..8) and `fromIndex` factory.
- `Cell` value object: `Position position`, `Player? owner`, `bool isFadedOldest`. Immutable, `copyWith`.
- `GameStatus` enum: `idle`, `playing`, `won`.
- `Move` value object: `Player player`, `Position position`, `int turnIndex`.

**Scope Out:**

- Engine logic (Phase 5).
- Cubit state (Phase 6).
- Any UI.

**Touch Scope:** `lib/features/game/domain/models/*`.

**Deliverables:**

```text
lib/features/game/domain/models/player.dart
lib/features/game/domain/models/position.dart
lib/features/game/domain/models/cell.dart
lib/features/game/domain/models/game_status.dart
lib/features/game/domain/models/move.dart
```

**Acceptance Criteria:**

- [ ] All models extend `Equatable` (or override `==` / `hashCode`).
- [ ] No model imports anything from `flutter/material.dart`. Pure Dart only.
- [ ] `Position.fromIndex(8)` returns `Position(row: 2, col: 2)` and vice versa.
- [ ] `Player.x.opponent == Player.o`.
- [ ] `flutter analyze` clean.

**Dependencies:** Phase 0.

**Risks:** None significant.

---

## Phase 4 — Win Checker

**Goal:** A pure function that decides whether a given player has a winning line on the current board. Tested first.

**Scope In:**

- `WinChecker.findWinningLine({required List<Move> activeMoves, required Player player}) → List<Position>?`
  - Returns the 3 winning `Position`s if the player owns a complete row/column/diagonal among their active moves.
  - Returns `null` otherwise.
- Unit tests for: horizontal × 3, vertical × 3, diagonal × 2, no-win, partial line, both-diagonals together.

**Scope Out:**

- Engine integration (Phase 5).
- Animation of the winning line (Phase 14).

**Touch Scope:** `lib/features/game/domain/logic/win_checker.dart`, `test/win_checker_test.dart`.

**Deliverables:**

```text
lib/features/game/domain/logic/win_checker.dart
test/win_checker_test.dart
```

**Acceptance Criteria:**

- [ ] All 8 winning lines (3 rows + 3 cols + 2 diagonals) are detected.
- [ ] Returns `null` for partial lines or empty boards.
- [ ] No side effects (pure function).
- [ ] Tests: minimum 10 unit tests, **all green**.

**Dependencies:** Phase 3.

**Risks:**

- Bug in diagonal detection. **Mitigation:** explicit test per diagonal.

---

## Phase 5 — Game Engine (FIFO + Turn Lifecycle)

**Goal:** Encapsulate gameplay rules. The engine is the **only** code allowed to mutate the active-move queues.

**Scope In:**

- `GameEngine` class with immutable input → immutable output methods (functional style):
  - `GameEngineResult attemptMove({required GameSnapshot snapshot, required Position position});`
  - `GameSnapshot restart();`
  - `Position? oldestPositionFor(Player player, GameSnapshot snapshot);`
- `GameSnapshot` model (lives in the engine file or `domain/logic/game_snapshot.dart`):
  - `Queue<Move> xMoves` (max 3)
  - `Queue<Move> oMoves` (max 3)
  - `Player currentPlayer`
  - `int turnIndex`
  - `GameStatus status`
  - `List<Position>? winningLine`
  - `Player? winner`
- `GameEngineResult`:
  - `GameSnapshot snapshot`
  - `bool moveAccepted`
  - `Move? removedMove` (the oldest that was kicked out, if any)
  - `Move? placedMove`
- Implements the deterministic Turn Lifecycle from `rules.md §Turn Flow`:
  1. Validate input (cell empty + status playing).
  2. Remove oldest move if player already has 3 active.
  3. Place new move.
  4. Update active queue.
  5. Evaluate win (calls `WinChecker`).
  6. Switch player **only if** game continues.
- Unit tests covering: rotation correctness, no-rotation case (< 3 marks), win on 3rd move, win immediately after rotation, occupied cell rejection, post-win input rejection, turn alternation, restart.

**Scope Out:**

- Animation timing (UI concern).
- Input locking (Phase 15).
- AI opponent.

**Touch Scope:** `lib/features/game/domain/logic/game_engine.dart`, optional `game_snapshot.dart`, `test/game_engine_test.dart`.

**Deliverables:**

```text
lib/features/game/domain/logic/game_engine.dart
lib/features/game/domain/logic/game_snapshot.dart
test/game_engine_test.dart
```

**Acceptance Criteria:**

- [ ] All assertions in `rules.md §Turn Flow` hold under tests.
- [ ] Engine never returns a snapshot with > 3 marks per player.
- [ ] Win is evaluated **after** rotation, never during.
- [ ] No `flutter/...` imports — engine is pure Dart.
- [ ] **≥ 15 unit tests**, all green.

**Dependencies:** Phases 3, 4.

**Risks:**

- Off-by-one in `turnIndex`. **Mitigation:** test asserts on `turnIndex` progression.
- Win check called before rotation. **Mitigation:** test "win-after-rotation".

---

## Phase 6 — Game State + Cubit

**Goal:** Bridge the engine to the UI via Cubit. Cubit **coordinates**; it does **not** compute gameplay.

**Scope In:**

- `GameState` (Equatable):
  - `GameSnapshot snapshot`
  - `bool inputLocked` (UI-level lock, not gameplay)
  - `Position? lastPlacedPosition` (for animation hooks)
  - `Position? lastRemovedPosition` (for animation hooks)
  - `int matchDurationMs` (optional, for win dialog stats)
- `GameCubit extends Cubit<GameState>`:
  - `void onCellTapped(Position p)` → calls `GameEngine.attemptMove`, emits new state, manages `inputLocked` for `game_constants.inputLockMs`.
  - `void restart()` → resets via `GameEngine.restart()`.
  - `void clearLastEventMarkers()` → clears `lastPlacedPosition` / `lastRemovedPosition` after animations consume them.
- Tests using `bloc_test` style (manual `emit` checks; we don't add `bloc_test` package yet):
  - Verify tap on empty cell emits new snapshot.
  - Verify tap on occupied cell is no-op.
  - Verify rapid taps respect input lock.
  - Verify restart returns to initial snapshot.

**Scope Out:**

- UI binding (Phase 7).
- Persistence.
- Multiple cubits / coordinators.

**Touch Scope:** `lib/features/game/presentation/state/*`, `test/game_cubit_test.dart`.

**Deliverables:**

```text
lib/features/game/presentation/state/game_state.dart
lib/features/game/presentation/state/game_cubit.dart
test/game_cubit_test.dart
```

**Acceptance Criteria:**

- [ ] `GameCubit` contains **zero** win/FIFO logic — only calls the engine.
- [ ] `GameState` is immutable; updates via `copyWith`.
- [ ] Input lock toggles correctly around moves.
- [ ] ≥ 6 cubit tests, all green.

**Dependencies:** Phase 5.

**Risks:**

- Business logic creeping into cubit. **Mitigation:** code review against principle P3.

---

## Phase 7 — Gameplay Screen (First Playable)

**Goal:** Build the hero screen. After this phase, the game is **end-to-end playable**.

**Scope In:**

- `GameplayScreen` (StatelessWidget) hosting a `BlocProvider<GameCubit>` and a `BlocBuilder` over `GameState`.
- Layout from `design.md §10 GAMEPLAY SCREEN`:
  - Top header (back · infinity logo · restart).
  - Turn section (`PlayerTurnIndicator`).
  - Move counter pill.
  - Centered `GameBoard` (responsive, capped via `min(0.82.sw, 420.w)`).
  - Bottom `PlayerPanel × 2` (X left, O right).
- `GameBoard` widget — 3×3 grid of `BoardCell`s, fed by the snapshot.
- `BoardCell` widget — empty / active / **faded oldest** rendering. Tap → `context.read<GameCubit>().onCellTapped(p)`.
- `PlayerTurnIndicator` — animated turn label.
- `PlayerPanel` — X/O card with active glow when their turn.
- Faded-mark logic: only the **current player's** oldest mark is rendered at `fadedMarkOpacity`.

**Scope Out:**

- Win dialog (Phase 8).
- Pause bottom sheet (Phase 8).
- Rich animations (Phase 14) — basic implicit `AnimatedOpacity` / `AnimatedScale` allowed for tactility.
- Sounds (Phase 16).

**Touch Scope:** `lib/features/game/presentation/screens/gameplay_screen.dart`, `lib/features/game/presentation/widgets/*`, update `app_router.dart` to wire `/game`.

**Deliverables:**

```text
lib/features/game/presentation/screens/gameplay_screen.dart
lib/features/game/presentation/widgets/game_board.dart
lib/features/game/presentation/widgets/board_cell.dart
lib/features/game/presentation/widgets/player_turn_indicator.dart
lib/features/game/presentation/widgets/player_panel.dart
```

**Acceptance Criteria:**

- [ ] A user can play a full match: place marks → see oldest fade → place 4th mark → oldest disappears → win → see win state (frozen board even before Phase 8 dialog).
- [ ] Faded mark is visible **only** for the player whose turn it is.
- [ ] Tapping an occupied cell does nothing (no crash, no state mutation).
- [ ] Board is centered, square, and bounded by `min(0.82.sw, 420.w)`.
- [ ] Background = Warm Ivory; X = Soft Coral; O = Teal.
- [ ] No widget reads or mutates `GameSnapshot.xMoves/oMoves` directly — only via cubit state and helpers.

**Dependencies:** Phase 6 (and transitively all prior).

**Risks:**

- Board cell rebuilding too aggressively. **Mitigation:** use `const` constructors + `BlocSelector` where it helps.

---

## Phase 8 — Win Dialog & Pause Bottom Sheet

**Goal:** Close the gameplay loop with a calm, premium win celebration and a pause menu.

**Scope In:**

- `WinDialog` widget — modal route:
  - Large winner symbol (X coral / O teal).
  - Title "X Wins!" / "O Wins!".
  - Optional stats: total moves, match duration.
  - Primary CTA: **Play Again** → calls `cubit.restart()` and pops.
  - Secondary CTA: **Back to Home** → pops to `/home`.
- `PauseBottomSheet` widget — bottom sheet from the header (restart button can long-press or settings icon can open it; for MVP we wire it to the header settings icon if present, otherwise restart-icon long-press):
  - Resume · Restart Match · How to Play · Settings · Exit to Home.
- Gameplay screen subscribes to `GameStatus.won` transitions and triggers `WinDialog` once per match.

**Scope Out:**

- Confetti / particle effects (out of scope for MVP per `design.md §Win Dialog Effects`).
- Persisting match stats.

**Touch Scope:** `lib/features/game/presentation/widgets/win_dialog.dart`, `pause_bottom_sheet.dart`, edits in `gameplay_screen.dart`.

**Deliverables:**

```text
lib/features/game/presentation/widgets/win_dialog.dart
lib/features/game/presentation/widgets/pause_bottom_sheet.dart
```

**Acceptance Criteria:**

- [ ] Dialog appears **once** per win, never on restart, never during animation.
- [ ] "Play Again" returns to a fresh `idle → playing` state.
- [ ] "Back to Home" navigates to `/home` (or placeholder if Home not built yet).
- [ ] Bottom sheet items all navigate or no-op cleanly (no dead links).

**Dependencies:** Phase 7.

**Risks:**

- Double-firing dialog. **Mitigation:** show dialog inside a `BlocListener` and guard with a local boolean or use `previous.status != current.status`.

---

## Phase 9 — Home Screen

**Goal:** Replace the home placeholder with the real central hub.

**Scope In:**

- `HomeScreen` per `design.md §Home Screen`:
  - Top: small infinity logo, "ShiftTac", subtitle "Offline Multiplayer Strategy Game".
  - Primary CTA: **Play Local Multiplayer** → navigates to `/game`.
  - Secondary CTA: **Play vs AI** → disabled state with "Coming Soon" label.
  - Buttons: **How to Play** → `/how-to-play`, **Settings** → `/settings`.
  - Bottom: version + credits.
- `HomeActionCard` reusable widget.

**Scope Out:**

- Real AI gameplay.
- Profile / accounts.

**Touch Scope:** `lib/features/home/presentation/*`, edit `app_router.dart`.

**Deliverables:**

```text
lib/features/home/presentation/screens/home_screen.dart
lib/features/home/presentation/widgets/home_action_card.dart
```

**Acceptance Criteria:**

- [ ] Layout matches `design.md §Home Screen`.
- [ ] All CTAs route correctly (placeholders fine for not-yet-built screens).
- [ ] "Play vs AI" is visually disabled, with "Coming Soon" badge.
- [ ] Background = Warm Ivory; CTAs use Teal primary.

**Dependencies:** Phase 2, Phase 7 (for `/game` to be a real destination).

**Risks:**

- Overstyling. **Mitigation:** Section 1 principle — board is the hero, home is calm.

---

## Phase 10 — Splash Screen

**Goal:** Brand intro, 2–3 seconds, with the infinity logo animation.

**Scope In:**

- `SplashScreen`:
  - Center: animated `InfinityLogo` (slow rotation OR flowing infinity motion).
  - Title: "ShiftTac".
  - Subtitle: "The board never fills.".
  - Background: Warm Ivory with faded X/O shapes.
  - Auto-advance to `/onboarding` (first-launch heuristic deferred; for MVP always show onboarding once via `SharedPreferences` is **out** — see Backlog. For MVP, splash always goes to `/home` and the user can revisit onboarding via "How to Play"). Decision locked: **splash → home** for MVP.
- Enhance `InfinityLogo` with optional `animate: true` parameter, using a slow `AnimationController` (4–6s rotation).

**Scope Out:**

- First-launch detection / persistence.
- Loading real assets.

**Touch Scope:** `lib/features/splash/presentation/screens/splash_screen.dart`, update `infinity_logo.dart` to support animation, update `app_router.dart`.

**Deliverables:**

```text
lib/features/splash/presentation/screens/splash_screen.dart
```

**Acceptance Criteria:**

- [ ] Splash holds for 2.5s (constant), then `pushReplacementNamed('/home')`.
- [ ] Logo animates smoothly; no jank on a mid-range device.
- [ ] App entry point in `main.dart` lands on `/splash`.

**Dependencies:** Phase 2, Phase 9.

**Risks:**

- Hard-coded delay feeling sluggish. **Mitigation:** keep at 2.5s; expose constant in `app_constants.dart`.

---

## Phase 11 — Onboarding (3 Screens)

**Goal:** Teach the FIFO + faded-mark mechanic in under 30 seconds.

**Scope In:**

- `OnboardingScreen` hosting a `PageView` of 3 pages:
  - **Page 1 — "Looks familiar?"** — classic 3×3 board static image.
  - **Page 2 — "Only 3 marks stay active"** — animated mini-board showing the rotation.
  - **Page 3 — "Watch the faded mark"** — mini-board with the faded oldest mark highlighted.
- `OnboardingPage` widget (title, description, visual slot, page index).
- `MiniBoardPreview` widget — reusable 3×3 preview for onboarding & how-to-play, with optional pre-baked animation steps.
- Progress indicator + Next / Back / **Start Playing** (final page).

**Scope Out:**

- Skip-once logic (Backlog).
- Detecting whether onboarding was seen before.

**Touch Scope:** `lib/features/onboarding/presentation/*`, update `app_router.dart`.

**Deliverables:**

```text
lib/features/onboarding/presentation/screens/onboarding_screen.dart
lib/features/onboarding/presentation/widgets/onboarding_page.dart
lib/features/onboarding/presentation/widgets/mini_board_preview.dart
```

**Acceptance Criteria:**

- [ ] All 3 pages render and swipe smoothly.
- [ ] Page 2's animation visibly shows the oldest mark being removed when the 4th is placed.
- [ ] Page 3 clearly fades the oldest mark at `fadedMarkOpacity`.
- [ ] "Start Playing" navigates to `/game`.

**Dependencies:** Phase 2, Phase 7 (so MiniBoardPreview can share visual language with the real board).

**Risks:**

- Onboarding visuals diverging from gameplay. **Mitigation:** `MiniBoardPreview` reuses `BoardCell`'s visual style or shares helpers.

---

## Phase 12 — How to Play Screen

**Goal:** Visual-first reference doc inside the app for players who skipped or forgot onboarding.

**Scope In:**

- `HowToPlayScreen` with 5 stepped sections per `design.md §How to Play`:
  1. Classic board
  2. 3 active marks only
  3. Oldest mark fades
  4. 4th move removes oldest
  5. Get 3 in a row to win
- `HowToPlayStep` widget — step number, mini visual (`MiniBoardPreview`), short caption.

**Scope Out:**

- Long-form text walls (forbidden by `design.md`).

**Touch Scope:** `lib/features/how_to_play/presentation/*`, update `app_router.dart`.

**Deliverables:**

```text
lib/features/how_to_play/presentation/screens/how_to_play_screen.dart
lib/features/how_to_play/presentation/widgets/how_to_play_step.dart
```

**Acceptance Criteria:**

- [ ] All 5 steps render with their mini-board visuals.
- [ ] Reachable from Home and from Pause bottom sheet.
- [ ] No paragraph exceeds 2 short lines.

**Dependencies:** Phase 11 (`MiniBoardPreview`).

**Risks:** Low.

---

## Phase 13 — Settings Screen

**Goal:** Lightweight settings UI wired to the **shared in-memory** `AppSettingsController` so toggles affect gameplay/audio/haptics **in-session** without persistence.

**Scope In:**

- Create `AppSettingsController` (`lib/core/settings/app_settings_controller.dart`): in-memory only; holds `soundEffectsEnabled`, `musicEnabled`, `vibrationEnabled` (each exposed via `ChangeNotifier` / `ValueNotifier` / `Listenable` — pick one pattern and use it consistently); sensible defaults (e.g. all on); **no** repositories, services, or DI packages.
- Provide **one** controller instance at the app root (e.g. `MaterialApp.builder` + `InheritedNotifier` / `ListenableBuilder` / similar **built-in** Flutter wiring from `lib/app.dart`) so any route can read the same instance — **not** a global mutable singleton anti-pattern beyond this single documented root holder.
- `SettingsScreen` per `design.md §Settings`:
  - **Theme** (Light / Dark — Dark disabled with "Coming Soon").
  - **Audio**: Sound effects toggle, Music toggle — each **writes** to `AppSettingsController` (`soundEffectsEnabled` / `musicEnabled`). Music remains no-op until Post-MVP (Backlog); toggle still updates the controller for forward compatibility.
  - **Gameplay**: Vibration toggle — **writes** `vibrationEnabled`.
  - **About**: Version, Credits.
- `SettingsTile` reusable row widget (label + control).

**Scope Out:**

- Persisting toggles across app launches (Backlog — `SharedPreferences`).
- Real audio output (Phase 16).
- Real dark theme.
- Per-screen duplicate toggle state (`ValueNotifier` only inside `SettingsScreen` is **out** — all toggles bind to `AppSettingsController`).

**Touch Scope:** `lib/core/settings/app_settings_controller.dart`, `lib/app.dart`, `lib/features/settings/presentation/*`, update `app_router.dart`.

**Deliverables:**

```text
lib/core/settings/app_settings_controller.dart
lib/features/settings/presentation/screens/settings_screen.dart
lib/features/settings/presentation/widgets/settings_tile.dart
```

**Acceptance Criteria:**

- [ ] Settings toggles update the **shared** `AppSettingsController` (same instance across routes).
- [ ] Toggles affect in-session behavior **where already wired** in later phases (P15 haptics reads `vibrationEnabled`; P16 SFX reads `soundEffectsEnabled`).
- [ ] Values **do not** persist after app restart (cold start returns defaults).
- [ ] Dark mode toggle is visibly disabled with "Coming Soon".
- [ ] Reachable from Home and Pause sheet.

**Dependencies:** Phase 2.

**Risks:** Scope creep into persistence. **Mitigation:** Backlog reference is explicit.

---

## Phase 14 — Animations & Motion Polish

**Goal:** Make the gameplay feel *tactile, calm, premium* per `design.md §Motion System`.

**Scope In:**

- `shared/animations/app_motion.dart` — curves and durations from `game_constants.dart`.
- `shared/animations/fade_scale_transition.dart` — reusable transition.
- Implement per-element motion in gameplay:
  - **New mark placement:** scale pop + slight bounce (`movePlacementMs`).
  - **Removed mark:** dissolve fade + subtle shrink (`fadeRemovalMs`).
  - **Faded oldest mark:** animated opacity transition when ownership of "oldest" changes.
  - **Turn switch:** `PlayerTurnIndicator` label slide + card glow on the active `PlayerPanel`.
  - **Winning line:** soft pulse + glow on the 3 winning cells.
- Tap feedback: `InkResponse` or custom `AnimatedScale` (~`tapFeedbackMs`).
- Invalid tap on occupied cell: subtle horizontal shake.

**Scope Out:**

- Sounds (Phase 16).
- Explosive / confetti effects (forbidden).

**Touch Scope:** `lib/shared/animations/*`, edits in `game_board.dart`, `board_cell.dart`, `player_turn_indicator.dart`, `player_panel.dart`, `win_dialog.dart`.

**Deliverables:**

```text
lib/shared/animations/app_motion.dart
lib/shared/animations/fade_scale_transition.dart
```

**Acceptance Criteria:**

- [ ] All motion durations come from `game_constants.dart` — zero magic numbers.
- [ ] Animations never block state updates (principle P6).
- [ ] No animation exceeds 320 ms (dialog entrance ceiling).
- [ ] Visually smooth on a mid-range device (subjective QA).

**Dependencies:** Phases 7, 8.

**Risks:**

- Over-animating. **Mitigation:** keep curves to `Curves.easeOut` / `easeOutCubic`; avoid bouncy springs.

---

## Phase 15 — Haptics & Input Lock Hardening

**Goal:** Sharpen the rapid-tap and animation-overlap edge cases.

**Scope In:**

- Add `HapticFeedback.selectionClick()` on valid moves; `HapticFeedback.lightImpact()` on invalid taps — **only when** `AppSettingsController.vibrationEnabled` is true (read the shared controller from `lib/core/settings/app_settings_controller.dart`; provide access via `InheritedNotifier`, `context` lookup, or constructor parameter from parent — **no** DI package).
- Reaffirm input lock window (`inputLockMs = 140 ms`) and verify with stress test (rapid taps).
- Ensure restart during transition cannot corrupt state — extend `GameCubit.restart()` to clear `inputLocked` and any pending markers.

**Scope Out:**

- Persisting the vibration setting (Backlog).

**Touch Scope:** edits in `game_cubit.dart`, `board_cell.dart`, `gameplay_screen.dart` (whichever layer fires haptics; must read `AppSettingsController`).

**Deliverables:** No new files (edits only).

**Acceptance Criteria:**

- [ ] Pressing the same cell 10× in rapid succession produces **exactly one** state change.
- [ ] Restart during the fade-out animation does not leave a ghost mark.
- [ ] Vibration toggle affects haptic behavior **in-session** via the shared `AppSettingsController` (off = no haptics from gameplay paths; on = haptics as specified).

**Dependencies:** Phases 13, 14.

**Risks:** None significant.

---

## Phase 16 — Audio Layer

**Goal:** Soft, tactile sound effects per `design.md §Audio Direction`.

**Scope In:**

- Add `audioplayers` (or `just_audio` — pick one; lock here as `audioplayers`).
- `core/audio/` (roadmap-approved folder; see Section 2.1):
  - `app_audio.dart` — thin wrapper exposing `playPlacement()`, `playRemoval()`, `playWin()`. Before each play, consult **`AppSettingsController.soundEffectsEnabled`** (pass the same root instance used in P13 — **no** separate `muted` flag on `AppAudio`; the controller is the single source of truth for whether SFX run).
- Wire playback triggers from `GameplayScreen` (e.g. `BlocListener` on `GameCubit`) so SFX align with resolved game events.
- Bundle 3 small audio assets under `assets/sounds/` and register in `pubspec.yaml`.

**Scope Out:**

- Background music playback (Backlog — `musicEnabled` may exist on the controller for UI parity only until a future phase).
- Per-event volume sliders.
- `SharedPreferences` or any persistence for audio preferences.

**Touch Scope:** `pubspec.yaml`, `lib/core/audio/app_audio.dart`, edits in `gameplay_screen.dart` (optional: `AppAudio` constructor receives `AppSettingsController` — **no** duplicate mute state).

**Deliverables:**

```text
lib/core/audio/app_audio.dart
assets/sounds/place.wav
assets/sounds/remove.wav
assets/sounds/win.wav
```

**Acceptance Criteria:**

- [ ] Three SFX play at the correct moments **only when** `soundEffectsEnabled` is true on `AppSettingsController`.
- [ ] When `soundEffectsEnabled` is false, no placement/removal/win SFX fire (controller is authoritative; `AppAudio` does not maintain a parallel mute flag).
- [ ] No audio plays when the app is backgrounded.

**Dependencies:** Phases 13, 14, 15.

**Risks:**

- Loud / harsh samples. **Mitigation:** select samples that are short (≤ 300 ms) and soft.

---

## Phase 17 — App Icon & Splash Polish

**Goal:** Brand the final binary.

**Scope In:**

- Generate an app icon per `design.md §16 App Icon`: minimal infinity symbol on warm ivory or subtle gradient.
- Use `flutter_launcher_icons` (dev_dependency) to generate Android + iOS icons.
- Native splash (warm ivory background) via `flutter_native_splash` (dev_dependency).
- Final polish on the in-app `SplashScreen` (timing tweaks, fade-out into home).

**Scope Out:**

- App store screenshots (Phase 20).

**Touch Scope:** `pubspec.yaml` (dev_deps), `assets/icons/`, generated native files.

**Deliverables:**

```text
assets/icons/app_icon.png
assets/icons/splash_logo.png
flutter_launcher_icons config (in pubspec.yaml)
flutter_native_splash config (in pubspec.yaml)
```

**Acceptance Criteria:**

- [ ] Icon renders correctly on Android home screen and iOS springboard at all sizes.
- [ ] Native splash background matches Warm Ivory exactly.
- [ ] In-app splash transitions seamlessly from native splash.

**Dependencies:** Phase 10.

**Risks:**

- Visual seam between native splash and in-app splash. **Mitigation:** same background color and centered logo.

---

## Phase 18 — Edge Case Tests & Responsive QA

**Goal:** Validate every edge case enumerated in `rules.md §Edge Cases` and `implementation-rules.md §9`.

**Scope In:**

- Engine tests for:
  - Occupied cell selection.
  - Rapid consecutive taps.
  - Mark removal from a *potential* winning line (does NOT win).
  - Win occurring immediately after rotation.
  - Win occurring on a player's 3rd-ever move.
  - Restart during transition states (cubit-level).
- Manual responsive QA pass on:
  - Small phone (e.g., 360 × 640).
  - Standard phone (390 × 844, our design size).
  - Large phone (e.g., 430 × 932).
  - 7" tablet (e.g., 600 × 960).
- Document QA results in `docs/qa-checklist.md` (only file created outside the four spec docs — explicitly allowed here).

**Scope Out:**

- Automated golden tests (Backlog).

**Touch Scope:** `test/`, `docs/qa-checklist.md`.

**Deliverables:**

```text
test/edge_cases_test.dart
docs/qa-checklist.md
```

**Acceptance Criteria:**

- [ ] All edge case unit tests green.
- [ ] All 4 device sizes pass visual QA (board centered, readable labels, large tap targets).
- [ ] `docs/qa-checklist.md` filled in with date and tester initials.

**Dependencies:** Phases 5, 6, 7, 14.

**Risks:** None significant.

---

## Phase 19 — Accessibility Pass

**Goal:** Meet the accessibility requirements in `design.md §14`.

**Scope In:**

- Semantics labels on every `BoardCell` ("Row 1 Column 2, empty" / "Row 2 Column 2, X").
- Semantics labels on header buttons (Back, Restart, Settings).
- Verify contrast ratios: Ink Navy on Warm Ivory ≥ 4.5:1 for body, X & O marks readable.
- Add a fallback shape distinction so X and O are distinguishable for users with color-vision differences (X uses a distinct cross shape, O uses a distinct circle — already the case visually; verify shapes carry meaning independent of color).
- Increase minimum tap target to 48×48 logical px everywhere.

**Scope Out:**

- Screen-reader-only flows (Backlog).
- Multi-language localization (Backlog).

**Touch Scope:** edits across existing widgets.

**Deliverables:** No new files (annotations and adjustments only).

**Acceptance Criteria:**

- [ ] TalkBack / VoiceOver announces cells and buttons meaningfully.
- [ ] Every tappable element is ≥ 48 × 48 logical px.
- [ ] X and O remain distinguishable in a grayscale screenshot.

**Dependencies:** All UI phases.

**Risks:** None significant.

---

## Phase 20 — Release Prep

**Goal:** Make the build shippable.

**Scope In:**

- Final `README.md` rewrite: install, run, test, contribute, license.
- Versioning: bump `pubspec.yaml` to `1.0.0+1` (already there) and verify build numbers in Android and iOS.
- Android: app id, signing config notes (don't commit keys), min/target SDK check.
- iOS: bundle id, display name, deployment target.
- License file (MIT recommended unless user specifies otherwise — confirm at this phase).
- Smoke build: `flutter build apk --release` and `flutter build ios --no-codesign`.

**Scope Out:**

- Actual store submission.
- Crashlytics / analytics (Backlog).

**Touch Scope:** root files, `android/`, `ios/`, `README.md`.

**Deliverables:**

```text
README.md  (final)
LICENSE
android/app/build.gradle    (id, version)
ios/Runner/Info.plist       (display name, version)
```

**Acceptance Criteria:**

- [ ] `flutter build apk --release` succeeds.
- [ ] `flutter build ios --no-codesign` succeeds on a Mac (skip if Windows-only — manual note in README).
- [ ] README documents setup, run, and test commands.
- [ ] App version is 1.0.0+1.

**Dependencies:** All prior phases.

**Risks:**

- Windows-only contributor unable to build iOS. **Mitigation:** documented in README; CI not required for MVP.

---

## CROSS-CUTTING

### 5. State Shape Contract (Frozen)

This shape is the **frozen API** between the engine, cubit, and UI. Adding or removing a field requires amending this document first.

```text
GameSnapshot
├── Queue<Move> xMoves          (max 3)
├── Queue<Move> oMoves          (max 3)
├── Player currentPlayer        (default: Player.x)
├── int turnIndex               (monotonically increases from 0)
├── GameStatus status           (idle | playing | won)
├── List<Position>? winningLine
└── Player? winner

GameState (wraps GameSnapshot for UI)
├── GameSnapshot snapshot
├── bool inputLocked            (UI-only, defaults false)
├── Position? lastPlacedPosition
├── Position? lastRemovedPosition
└── int matchDurationMs         (optional; for win dialog stats)
```

### 6. File-Ownership Map

| Folder | Owning Phase(s) | Mutability after own phase |
|--------|-----------------|----------------------------|
| `lib/core/theme/` | P1 | Stable; rarely edited |
| `lib/core/constants/` | P1 | Stable |
| `lib/core/routing/` | P2 | Edited by every screen-introducing phase |
| `lib/core/widgets/` | P2 | Stable; new shared widgets only with strong justification |
| `lib/features/game/domain/` | P3–P5 | Frozen after P5 except for tested bug fixes |
| `lib/features/game/presentation/state/` | P6 | Frozen after P15 |
| `lib/features/game/presentation/widgets/` | P7, P8 | Polished in P14, P19 |
| `lib/features/home/` | P9 | Stable |
| `lib/features/splash/` | P10 | Stable |
| `lib/features/onboarding/` | P11 | Stable |
| `lib/features/how_to_play/` | P12 | Stable |
| `lib/features/settings/` | P13 | Stable; toggles read/write `AppSettingsController` only |
| `lib/core/settings/` | P13 (create `app_settings_controller.dart`) | In-memory only for MVP; consumed by P15 (haptics), P16 (SFX); **no** persistence |
| `lib/shared/animations/` | P14 | Stable |
| `lib/core/audio/` | P16 | Roadmap-approved folder (Section 2.1); stable after P16 |

### 7. Forbidden Patterns (Across All Phases)

Per `implementation-rules.md §2 Avoid Premature Complexity`:

- ❌ Repositories.
- ❌ Dependency injection containers (`get_it`, `riverpod` providers, `injectable`).
- ❌ Use case classes.
- ❌ Service layers.
- ❌ Data sources / API wrappers.
- ❌ Multiple cubits for the same feature.
- ❌ Hardcoded colors, durations, opacities, or sizes outside the `core/theme` / `core/constants` files.
- ❌ Importing `flutter/material.dart` inside `domain/`.
- ❌ Undocumented mutable global / service-locator patterns (exception: **one** root-scoped `AppSettingsController` per **D7** — not a repository, not DI).
- ❌ `setState` inside any widget that already lives under a `BlocBuilder` for the same data.

### 8. Required Patterns

- ✅ `const` constructors wherever possible.
- ✅ `Equatable` on every value object and state.
- ✅ `copyWith` on every state-bearing model.
- ✅ Named routes from `AppRoutes` (no magic strings).
- ✅ `flutter_screenutil` extensions (`.w / .h / .r / .sp`) for responsive sizing.

---

## 9. Testing Strategy

| Layer | Phase Introduced | Test File | Min. Test Count |
|-------|------------------|-----------|-----------------|
| WinChecker | P4 | `test/win_checker_test.dart` | 10 |
| GameEngine | P5 | `test/game_engine_test.dart` | 15 |
| GameCubit | P6 | `test/game_cubit_test.dart` | 6 |
| Edge cases | P18 | `test/edge_cases_test.dart` | 8 |

> **Rule:** A test file is required *in the same phase* as the code it tests. No "we'll add tests later".

---

## 10. Risk Register

| Risk | Likelihood | Impact | Phase Surfaced | Mitigation |
|------|-----------|--------|----------------|------------|
| FIFO + win-check order regressed | Medium | High | P5 | Unit test `win-after-rotation` |
| Faded-mark visual confusion | Medium | High | P7 | Onboarding P11 + How-to-Play P12 reinforce it |
| Animation blocking state | Low | High | P14 | Principle P6, code review |
| Settings reset on cold start (expected MVP — no persistence) | Confirmed | Low | P13 | Post-MVP: Section 19 — Deferred Backlog (`SharedPreferences`) |
| iOS build on Windows-only host | High | Low | P20 | README documents Mac requirement |
| Scope creep into AI / online modes | High | High | All | This document's Section 0.1 |

---

## 11. Done = Shippable Criteria (Project-Level)

The MVP ships when all of the following are true:

- [ ] All 21 phases (P0–P20) are marked Done.
- [ ] `flutter analyze` returns 0 errors / 0 warnings across the project.
- [ ] All test files green.
- [ ] A full match can be played, won, restarted, and replayed on a real Android device.
- [ ] Home, Splash, Onboarding, How-to-Play, Settings all reachable and visually polished.
- [ ] App icon + native splash applied.
- [ ] README, LICENSE present.
- [ ] No items in `docs/qa-checklist.md` are red.

---

## 12. Implementation Sequence (Quick Reference)

```text
P0  Foundation & cleanup
P1  Theme tokens
P2  App shell + routing + shared widgets
P3  Domain models               ┐
P4  Win checker                 │ Game brain
P5  Game engine                 ┘
P6  Cubit + state
P7  Gameplay screen      ◄── FIRST PLAYABLE
P8  Win dialog + pause sheet
P9  Home
P10 Splash
P11 Onboarding (3 screens)
P12 How to Play
P13 Settings
P14 Animations
P15 Haptics + input lock
P16 Audio
P17 App icon + splash polish
P18 Edge tests + responsive QA
P19 Accessibility
P20 Release prep         ◄── SHIPPABLE
```

---

## 13. Dependency Graph

```text
P0
└─► P1 ──► P2 ──► P3 ──► P4 ──► P5 ──► P6 ──► P7 ──► P8 ─┬─► P9  ─┐
                                                         ├─► P10 ─┤
                                                         ├─► P11 ─┼─► P14 ─► P15 ─► P16 ─► P17 ─► P18 ─► P19 ─► P20
                                                         ├─► P12 ─┤
                                                         └─► P13 ─┘
```

- P9–P13 can be executed in any order (they only depend on P2, P7, P8).
- P14 onward depends on the full screen surface being in place.

---

## 14. Change Control

To amend this roadmap:

1. Open a section in this file titled `## Amendment YYYY-MM-DD — <short title>`.
2. State the **trigger** (what changed), the **decision**, and the **impacted phases**.
3. Update the affected phase blocks inline.
4. Do **not** silently edit phases without an amendment entry — the roadmap is the contract.

---

## 15. Out-of-Scope Confirmations (MVP)

These are explicitly **not** in MVP scope. They live in the Backlog.

- AI opponent.
- Online multiplayer.
- Match history / stats persistence.
- Dark theme implementation.
- Multi-language localization.
- Account systems.
- Leaderboards / ranking.
- Replay system.
- Undo functionality.
- Background music.
- Analytics / crash reporting.
- Cloud save.

---

## 16. Naming Conventions

- **Files:** `snake_case.dart`.
- **Classes:** `UpperCamelCase`.
- **Methods/variables:** `lowerCamelCase`.
- **Constants:** `lowerCamelCase` inside a class (`AppColors.warmIvory`, not `WARM_IVORY`).
- **Routes:** kebab-case strings (`/how-to-play`, `/onboarding`).
- **Test files:** `<unit_under_test>_test.dart`.

---

## 17. Per-Phase Output Quality Bar

Before marking any phase Done, run this 5-point self-check:

1. **Spec alignment** — does the result match the relevant section of `design.md` / `rules.md`?
2. **Architectural alignment** — does it respect `implementation-rules.md` and `structure.md`?
3. **Scope boundary** — did anything outside `Scope In` get touched?
4. **Token alignment** — are all visual values from `core/theme` and `core/constants`?
5. **Tests** — are required tests written and passing?

If any answer is "no", the phase is **not** Done.

---

## 18. Decision Log Anchors

Decisions locked by this roadmap (overrides anywhere else):

- **D1** — Splash always navigates to `/home`. Onboarding is reached from Home / How-to-Play, not auto-shown. (P10)
- **D2** — User preferences for MVP are **only** in-memory on the shared `AppSettingsController` (`soundEffectsEnabled`, `musicEnabled`, `vibrationEnabled`); they reset on cold start. **No** settings persistence until Post-MVP (Backlog). (P13)
- **D3** — Audio engine is `audioplayers`. (P16)
- **D4** — No `go_router` for MVP — named `Navigator` routes only. (P2)
- **D5** — Roadmap-approved `lib/` paths beyond `structure.md` are limited to **Section 2.1** (includes `lib/core/settings/` from P13 and `lib/core/audio/` from P16, plus domain/test/doc paths listed there).
- **D6** — Engine is pure Dart; no Flutter imports inside `features/game/domain/`. (P3–P5)
- **D7** — Exactly **one** `AppSettingsController` instance is created at the app root and exposed without DI packages; screens/features read it for in-session behavior only. (P13)

---

## 19. Deferred Backlog (Post-MVP)

Captured here so they don't pollute MVP phases:

- AI opponent (single-player vs. CPU with difficulty levels).
- Online multiplayer (matchmaking, real-time sync).
- Match stats persistence (`SharedPreferences` → later cloud).
- Dark theme implementation.
- Settings persistence (`SharedPreferences`).
- First-launch detection for auto-onboarding.
- Replay system + move history.
- Undo (would conflict with FIFO — design decision needed).
- Background music + per-event volume.
- Multi-language localization.
- Analytics (Firebase Analytics) + Crashlytics.
- Golden / widget tests.
- Achievements / leaderboards.
- Themed boards (skins).
- Accessibility: screen-reader-optimized flows.

---

## 20. Final Reminder

> ShiftTac is meant to feel like a **beautifully crafted strategy object**.
> The roadmap exists so the codebase feels the same way:
> *elegant · calm · structured · intentional · easy to evolve.*

Every move on this roadmap, like every move on the board, should change the project — for the better.
