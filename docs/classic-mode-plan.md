# Classic Mode Implementation Plan

## Purpose

Classic mode adds traditional local 3x3 Tic Tac Toe alongside the existing ShiftTac local mode.

The implementation should reuse the current gameplay UI, board widgets, audio/haptics plumbing, pause flow, restart flow, win-line reveal, and route shell wherever possible. The main differences live in the game rules:

- Marks never rotate away.
- The board can become full.
- A full board with no winning line ends in a draw.
- The draw result needs a polished dialog that follows the existing design system.

## Current Baseline

The current game stack is already layered well for a second rule set:

- `lib/features/game/domain/logic/game_engine.dart` owns ShiftTac FIFO rules.
- `lib/features/game/domain/logic/game_snapshot.dart` stores per-player move lists, turn, status, winner, and winning line.
- `lib/features/game/domain/logic/win_checker.dart` is reusable for both ShiftTac and classic mode.
- `lib/features/game/presentation/state/game_cubit.dart` owns UI lifecycle state and delegates rules to the engine.
- `lib/features/game/presentation/widgets/game_board.dart` maps a snapshot to board visuals.
- `lib/features/game/presentation/screens/gameplay_screen.dart` already contains timer, pause, restart, board, panels, and win dialog orchestration.
- `lib/features/home/presentation/screens/home_screen.dart` already has a disabled `Play Classic` entry point.

The plan below keeps the game logic pure, keeps mode-specific behavior explicit, and avoids branching across many widgets.

## Product Decisions

- Classic mode is local multiplayer on the same device.
- Classic mode uses the same 3x3 board and same X/O players.
- Classic mode shares ShiftTac's random starting-player behavior.
- Classic mode has a draw terminal state.
- ShiftTac mode keeps its "no draw" behavior.
- The draw result should use the same result dialog component used for X and O wins, not a visually separate modal pattern.
- The draw result should use `assets/icons/draw.svg`.
- The draw result should use shades of grey in the same role that X uses red shades and O uses green shades: symbol color, symbol glow, ambient glow, muted secondary-button icon color, and any draw-state accents.
- The draw result should feel calm and neutral, not celebratory. It should avoid confetti and excessive animation.

## Target Architecture

```text
lib/features/game/
+-- domain/
|   +-- models/
|   |   +-- game_mode.dart
|   |   +-- game_status.dart
|   |   +-- move.dart
|   |   +-- player.dart
|   |   +-- position.dart
|   +-- logic/
|       +-- classic_game_engine.dart
|       +-- game_engine_result.dart
|       +-- game_rules.dart
|       +-- game_snapshot.dart
|       +-- shift_game_engine.dart
|       +-- win_checker.dart
+-- presentation/
    +-- state/
    |   +-- game_cubit.dart
    |   +-- game_state.dart
    +-- widgets/
    |   +-- match_result_dialog.dart
    |   +-- game_board.dart
    |   +-- ...
    +-- screens/
        +-- gameplay_screen.dart
```

The exact file split can be adjusted during implementation, but the rule-set boundary should remain clear:

- ShiftTac rules belong in a Shift engine.
- Classic rules belong in a Classic engine.
- Shared UI lifecycle belongs in `GameCubit` and `GameplayScreen`.
- Shared win detection stays in `WinChecker`.

## Phase 0 - Planning Lock And Baseline Audit

**Goal:** Confirm the intended implementation shape before changing production code.

**Scope In:**

- Review the current game logic, game state, board rendering, routing, dialogs, and tests.
- Confirm all existing ShiftTac behavior that must remain unchanged.
- Confirm the implementation preserves the decided random starting-player behavior.
- Confirm draw result copy while keeping the shared result dialog design and grey palette fixed.
- Confirm whether `GameEngine` should be renamed to `ShiftGameEngine` in this work or kept as a compatibility wrapper.

**Scope Out:**

- No code changes beyond planning updates.
- No UI build-out.
- No tests yet.

**Key Checks:**

- Existing ShiftTac tests pass before implementation begins.
- Existing gameplay route still defaults to ShiftTac mode if no mode argument is passed.
- Any route changes remain backwards compatible with existing `AppRoutes.game` usage.

**DoD:**

- [x] Implementation direction is agreed: shared rules contract or minimal mode branch.
- [x] Classic starting-player behavior shares ShiftTac's random starter.
- [x] Draw result title, body copy, button labels, stats, `assets/icons/draw.svg`, and grey palette roles are documented.
- [x] Existing tests are run and current failures, if any, are documented before changes.
- [x] Commit and push phase changes to GitHub.

### Phase 0 Completion — 2026-05-29

#### Locked implementation direction

Use the **shared `GameRules` contract** (not ad-hoc `if (classic)` branches in widgets or the cubit). Each mode gets a pure-Dart engine implementing the contract; `GameCubit` and `GameplayScreen` delegate move/restart logic to the injected rules object.

| Layer | Current baseline | Classic-mode change |
| --- | --- | --- |
| Domain rules | `GameEngine` (static FIFO) | `ShiftGameEngine` + `ClassicGameEngine` via `GameRules` |
| Snapshot | FIFO queues in `GameSnapshot` | Same struct; comments updated; classic uses full move lists |
| Win detection | `WinChecker` | Unchanged — shared by both modes |
| Cubit lifecycle | `GameCubit` → `GameEngine` | `GameCubit({required GameRules rules})` |
| Board visuals | `_appearanceFor` fade preview | Mode-aware mapper; classic never fades |
| Result UI | `WinDialog` (X/O only) | `MatchResultDialog` with win + draw variants |
| Routing | `AppRoutes.game` → `GameplayScreen()` | Same route; optional `GameMode` in `settings.arguments` |

**`GameEngine` rename decision:** Rename to `ShiftGameEngine` in Phase 2. Do **not** keep a long-term `GameEngine` alias — update call sites and tests in the same phase. A temporary re-export is acceptable only if it reduces churn within a single PR and is removed before Phase 9.

#### Starting-player behavior (locked)

Classic mode **shares ShiftTac's random starter**. Both engines call `GameSnapshot.initial()` which uses `Random().nextBool() ? Player.x : Player.o` when no explicit starter is passed (`game_snapshot.dart`). Classic must not force Player X.

#### Draw result copy and palette (locked)

| Element | Value |
| --- | --- |
| Symbol asset | `assets/icons/draw.svg` (file exists; add `IconConstant.draw` in Phase 6) |
| Title | `It's a Draw!` |
| Body | `No winner this round. Try another match.` |
| Stat row 1 label | `Total moves` |
| Stat row 2 label | `Match time` |
| Primary action | `Play Again` (with restart icon) |
| Secondary action | `Back to Home` (with home icon) |
| Animation duration | 300 ms (matches current `WinDialog`; within design.md 250–320 ms) |
| Barrier | Non-dismissible (same as win dialog) |
| Celebration | No confetti; calm neutral entrance only |

**Grey palette roles** — mirror `_WinnerPalette` in `win_dialog.dart`, substituting grey for winner accent:

| Role | X win (reference) | O win (reference) | Draw (locked) |
| --- | --- | --- | --- |
| Accent base | `AppColors.softCoral` | `AppColors.primary` | `AppColors.outline` |
| Symbol color | accent @ 0.88 α | accent @ 0.88 α | accent @ 0.88 α |
| Symbol glow | accent @ 0.12 α | accent @ 0.12 α | accent @ 0.12 α |
| Ambient glow (orbs) | accent @ 0.05 α | accent @ 0.05 α | accent @ 0.05 α |
| Muted secondary icon | accent @ 0.75 α | accent @ 0.75 α | accent @ 0.75 α |

Draw must not use red/coral or green/teal winner accents anywhere in the result dialog.

#### Test baseline (pre-implementation)

Run: `flutter test` on 2026-05-29.

| Result | Detail |
| --- | --- |
| **52 / 52 passed** | No failures |
| `game_engine_test.dart` | 18 tests — FIFO, wins, validation, restart |
| `game_cubit_test.dart` | 14 tests — taps, lock, restart, pause, markers |
| `win_checker_test.dart` | 8 tests |
| `app_settings_*` | 7 tests |
| `widget_test.dart` | 1 test |

No known flaky or skipped tests. This is the green baseline for Phases 1–9.

#### Baseline audit — ShiftTac behavior to preserve unchanged

**Domain (`GameEngine`):**

- Reject moves when `status != playing` or cell occupied (snapshot not mutated).
- FIFO: remove oldest mark when queue length ≥ `GameConstants.maxActiveMarks` (3) before placing.
- Win evaluated on mover's active marks **after** rotation + placement.
- Turn switches only when match continues; `turnIndex` increments on accepted moves.
- `removedMove` / `placedMove` reported in `GameEngineResult`.
- `GameEngine.restart()` → `GameSnapshot.initial()` with random starter.
- No draw state — match ends only at `GameStatus.won` or continues playing.

**Snapshot (`GameSnapshot`):**

- Per-player move lists (oldest → newest); max 3 active marks per player in ShiftTac.
- Random starter via `GameSnapshot.initial()`.

**Cubit (`GameCubit`):**

- Input lock for `GameConstants.inputLockMs` after accepted move.
- `lastPlacedPosition` / `lastRemovedPosition` for board animations.
- Timer, pause/resume, app-background pause sheet, restart clears all markers.
- `CellTapResult` enum values unchanged.

**Board (`GameBoard`):**

- Faded oldest-mark preview when current player has 3 marks and it is their turn.
- Board frozen when `status != playing`.
- Win-line reveal animation shared.

**Routing (`AppRouter`):**

- `AppRoutes.game` builds `const GameplayScreen()` with no arguments → ShiftTac (must remain default after classic ships).
- `Navigator.pushNamed(AppRoutes.game)` from home must keep opening ShiftTac.

**Dialogs / panels:**

- `WinDialog` for X/O wins only today; stats show `turnIndex` as total moves.
- `PlayerTurnIndicator` / `PlayerPanel` handle `idle`, `playing`, `won` — no draw branch yet.
- `Play Classic` on home is disabled with `Coming Soon` badge.

**Assets:**

- `assets/icons/draw.svg` exists and is covered by `pubspec.yaml` `assets/icons/` glob.
- Not yet referenced in `IconConstant`.

#### Route compatibility check

- `AppRoutes.game` has no mode argument today — **confirmed backward compatible**.
- Planned approach: pass `GameMode.classic` via `settings.arguments`; invalid/missing args fall back to ShiftTac.

---

## Phase 1 - Domain Model And Rule Boundary

**Goal:** Add the domain concepts needed for multiple game modes without changing visible gameplay yet.

**Scope In:**

- Add `GameMode` enum:
  - `shift`
  - `classic`
- Extend `GameStatus`:
  - keep `idle`
  - keep `playing`
  - keep `won`
  - add `draw`
- Add a rule contract, for example:

```dart
abstract interface class GameRules {
  GameMode get mode;

  GameSnapshot initial();

  GameEngineResult attemptMove({
    required GameSnapshot snapshot,
    required Position position,
  });

  Position? oldestPositionFor(Player player, GameSnapshot snapshot);
}
```

- Extract `GameEngineResult` into its own file if it improves clarity.
- Update `GameSnapshot` comments so they no longer imply every mode uses FIFO queues.
- Keep `WinChecker` unchanged.

**Scope Out:**

- Classic move implementation.
- Routing changes.
- UI changes.
- Result dialog changes.

**Implementation Notes:**

- `oldestPositionFor` can return `null` in classic mode.
- The rule contract should not import Flutter.
- `GameMode` belongs in domain models, not routing or UI.
- `GameStatus.draw` should be handled in switches immediately, even if the draw path is not reachable until Phase 3.

**Tests:**

- Update existing tests that exhaustively switch on `GameStatus`.
- Add small model tests only if the project has coverage expectations for enums or initial state.

**DoD:**

- [x] `GameMode` exists in the domain layer.
- [x] `GameStatus.draw` exists and all Dart switches compile.
- [x] A mode/rules boundary exists and is pure Dart.
- [x] Existing ShiftTac engine behavior remains unchanged.
- [x] `flutter analyze` is clean.
- [x] Existing tests pass.
- [x] Commit and push phase changes to GitHub.

---

## Phase 2 - Preserve And Rename ShiftTac Engine

**Goal:** Make the current engine explicitly represent ShiftTac rules before adding classic rules.

**Scope In:**

- Rename or wrap current `GameEngine` as `ShiftGameEngine`.
- Preserve the existing public behavior:
  - reject moves when not playing
  - reject occupied cells
  - remove oldest move when active marks reach `GameConstants.maxActiveMarks`
  - place the new move
  - evaluate the mover's winning line after rotation and placement
  - switch turns only if the match continues
- Implement `GameRules` for the ShiftTac engine.
- Keep a temporary `GameEngine` wrapper only if needed to reduce churn, but prefer clear naming once tests are updated.

**Scope Out:**

- Classic engine.
- Draw behavior.
- Home card changes.

**Implementation Notes:**

- Existing `game_engine_test.dart` can become `shift_game_engine_test.dart`.
- Test names should say "ShiftTac" or "shift" where the FIFO behavior matters.
- `GameConstants.maxActiveMarks` should remain ShiftTac-specific.

**Tests:**

- Existing engine tests must remain green after rename/refactor.
- Add a regression test proving ShiftTac still has no draw state even after many turns.
- Add a regression test proving `oldestPositionFor` still works for fade preview.

**DoD:**

- [x] Current FIFO behavior lives in `ShiftGameEngine` or an equivalent clearly named rule class.
- [x] Current ShiftTac tests are updated and passing.
- [x] Any temporary compatibility wrapper is documented and scheduled for removal if not intended long term.
- [x] No classic logic is mixed into the ShiftTac engine.
- [x] `flutter analyze` is clean.
- [x] Commit and push phase changes to GitHub.

**Phase 2 note:** No `GameEngine` compatibility wrapper was kept; all call sites use `ShiftGameEngine` directly.

---

## Phase 3 - Classic Game Engine

**Goal:** Implement pure classic Tic Tac Toe rules.

**Scope In:**

- Add `ClassicGameEngine` implementing the rule contract.
- Classic move flow:
  1. Reject if `snapshot.status != GameStatus.playing`.
  2. Reject if the target cell is occupied.
  3. Append the move for the current player.
  4. Increment `turnIndex`.
  5. Evaluate `WinChecker.findWinningLine` for the mover.
  6. If won, return `GameStatus.won`, `winner`, and `winningLine`.
  7. If not won and all 9 cells are occupied, return `GameStatus.draw`.
  8. Otherwise switch to `currentPlayer.opponent` and continue playing.
- Ensure `removedMove` is always `null` for classic mode.
- Classic `oldestPositionFor` returns `null`.
- Classic initial state should use the same random starting-player policy as ShiftTac.

**Scope Out:**

- Shared result dialog UI.
- Route/home entry point.
- AI.
- Score history or persisted stats.

**Implementation Notes:**

- Do not use `GameConstants.maxActiveMarks` in classic rules.
- Use `GameConstants.boardRows * GameConstants.boardCols` or a clear `boardCellCount` helper for draw detection.
- Do not add defensive compatibility paths for impossible classic states unless tests prove they are needed.
- Keep the engine immutable: input snapshot in, result snapshot out.

**Tests:**

- Starts with the expected player.
- Accepts valid empty-cell moves.
- Rejects occupied cells without mutating snapshot.
- Alternates turns.
- X can win by row.
- O can win by column.
- Diagonal win works.
- Anti-diagonal win works.
- Draw is detected on a full board with no winner.
- Win on the ninth move wins instead of drawing.
- Moves after win are rejected.
- Moves after draw are rejected.
- `removedMove` is always `null`.
- `oldestPositionFor` always returns `null`.

**DoD:**

- [x] `ClassicGameEngine` exists and is pure Dart.
- [x] Classic mode supports win, draw, invalid move, and terminal-state rejection.
- [x] Draw detection cannot override a ninth-move win.
- [x] Classic engine tests cover all core rule paths.
- [x] Existing ShiftTac tests still pass.
- [x] `flutter analyze` is clean.
- [x] Commit and push phase changes to GitHub.

---

## Phase 4 - Mode-Aware Cubit And State

**Goal:** Let the existing gameplay lifecycle run either ShiftTac or classic rules.

**Scope In:**

- Update `GameCubit` to receive a `GameRules` instance or a `GameMode`.
- Preferred construction:
  - `GameCubit.shift()`
  - `GameCubit.classic()`
  - or `GameCubit({required GameRules rules})`
- Store the active `GameMode` in `GameState` only if widgets need it.
- Delegate all move attempts to the active rules object.
- Restart through the active rules object.
- Keep timer, input locking, pause, resume, app lifecycle, and event marker behavior shared.
- Ensure `lastRemovedPosition` remains available for ShiftTac and remains `null` for classic.

**Scope Out:**

- Home card enablement.
- Dialog design.
- Board visual branching unless required for state tests.

**Implementation Notes:**

- Avoid `if (classic)` checks in `onCellTapped`; rule classes should own gameplay differences.
- The cubit should continue to return the same `CellTapResult` values.
- `clearLastEventMarkers` should work for both modes.
- `restart` should preserve the current mode.

**Tests:**

- Existing `GameCubit` tests run against ShiftTac behavior.
- Add classic cubit tests:
  - accepted move updates snapshot
  - occupied tap returns `rejectedInvalid`
  - draw state stops further input
  - restart returns to classic initial snapshot
  - `lastRemovedPosition` remains `null`
- Add a test proving ShiftTac restart still returns a ShiftTac snapshot/rules behavior.

**DoD:**

- [x] `GameCubit` can run ShiftTac and classic without duplicating lifecycle code.
- [x] Restart preserves the active mode.
- [x] Input locking behavior is unchanged.
- [x] Classic cubit tests cover accepted, rejected, draw, and restart paths.
- [x] ShiftTac cubit tests still pass.
- [x] `flutter analyze` is clean.
- [x] Commit and push phase changes to GitHub.

---

## Phase 5 - Board Rendering And Gameplay Screen Reuse

**Goal:** Reuse the current gameplay UI while removing ShiftTac-only fade behavior from classic mode.

**Scope In:**

- Update `GameplayScreen` to accept a mode:

```dart
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key, this.mode = GameMode.shift});

  final GameMode mode;
}
```

- Create the correct cubit for the requested mode.
- Update `GameBoard` appearance mapping:
  - ShiftTac: keep faded oldest-mark preview.
  - Classic: show only empty, X solid, or O solid.
- Keep win-line reveal shared.
- Keep board freeze behavior for won and draw states.
- Update `PlayerTurnIndicator` for draw state.
- Update `PlayerPanel` for draw state:
  - no player is highlighted as winner
  - subtitle can be neutral, for example `DRAW` or `No winner`
- Update move/time counter copy only if needed to clarify mode.

**Scope Out:**

- Home card routing.
- Shared result dialog draw variant.
- AI.

**Implementation Notes:**

- Prefer a small board appearance mapper over mode checks spread through cell widgets.
- `BoardCellTapTarget` should not know which mode is active.
- If `GameState` does not store mode, `GameBoard` can receive mode from constructor or select it from cubit/rules.
- Keep the same board layout, spacing, colors, cell animations, and input feedback.

**Tests:**

- Widget test or focused unit test for classic board appearance mapper: no faded cell is produced.
- Widget test or focused unit test for ShiftTac board appearance mapper: faded oldest mark still appears when appropriate.
- Draw state freezes the board.
- Draw state does not show a winner label.

**DoD:**

- [x] `GameplayScreen` can be constructed for ShiftTac or classic mode.
- [x] Classic board visuals do not show ShiftTac fade/oldest preview.
- [x] ShiftTac board visuals are unchanged.
- [x] Won and draw terminal states both freeze board input.
- [x] Indicator and player panels render draw state cleanly.
- [x] `flutter analyze` is clean.
- [x] Relevant widget/unit tests pass.
- [x] Commit and push phase changes to GitHub.

---

## Phase 6 - Shared Result Dialog With Draw Variant

**Goal:** Extend the existing win-result dialog into one shared result dialog that supports X wins, O wins, and draws through the same design-system component.

**Scope In:**

- Replace or refactor `WinDialog` into a shared result dialog, for example `MatchResultDialog`.
- The same dialog component must render:
  - X win: X symbol, red shades, `X Wins!`
  - O win: O symbol, green shades, `O Wins!`
  - draw: `assets/icons/draw.svg`, grey shades, `It's a Draw!` or final approved copy
- Add the draw SVG to the existing asset constants pattern so UI code references a constant rather than a raw path.
- Result dialog layout should keep the existing `WinDialog` structure:
  - `showGeneralDialog`
  - transparent barrier
  - `ModalBackdrop`
  - `FadeTransition`
  - `ScaleTransition`
  - `Dialog`
  - `AppSpacing.borderRadiusXl`
  - `AppColors.surfaceContainerLowest`
  - `AppTextStyles.displayLg`
  - stats card with total moves and match time
  - `PrimaryButton` for `Play Again`
  - `SecondaryButton` for `Back to Home`
- Result dialog palette model:
  - X uses the current red/coral winner shades.
  - O uses the current green/teal winner shades.
  - Draw uses grey shades in the same palette roles: symbol, symbol glow, ambient glow, muted accent, and secondary action icon color.
- Draw result visual language:
  - `assets/icons/draw.svg` as the large result symbol
  - no red or green winner-colored symbol treatment
  - no confetti
  - calm low-alpha grey glow
  - dialog entrance between 250ms and 320ms, matching `design.md`
- Draw result copy:
  - title: `It's a Draw!` or final approved copy
  - body: short and neutral, for example `No winner this round. Try another match.`
  - stats: `Total moves`, `Match time`
- Hook draw presentation into `GameplayScreen` after board state settles.

**Scope Out:**

- Persistent match history.
- Scoreboard.
- Any result-dialog layout that diverges from the current win dialog structure.

**Implementation Notes:**

- Existing design references:
  - `design.md` specifies dialog entrance at 250-320ms.
  - `design.md` specifies win dialog stats and actions.
  - Current `WinDialog` and `ExitGameDialog` already implement the modal foundation.
- The draw asset is fixed: `assets/icons/draw.svg`.
- The shared result dialog should accept a result type or view model instead of requiring `Player` for every result.
- Do not create a one-off draw modal with separate spacing, typography, or button treatment.
- The dialog should be non-dismissible if win dialog is non-dismissible, keeping terminal result behavior consistent.

**Tests:**

- Shared result dialog still renders X win and O win states correctly.
- Draw result renders `assets/icons/draw.svg`, title, body, total moves, match time, Play Again, and Back to Home.
- Play Again dismisses dialog and restarts in classic mode.
- Back to Home dismisses dialog and navigates home.
- Draw result does not show a winner-specific X/O title or red/green winner palette.

**DoD:**

- [x] X wins, O wins, and draws are presented through the same result dialog component.
- [x] Draw result uses `assets/icons/draw.svg`.
- [x] Draw result uses grey shades for the same visual roles that X and O use red/green shades.
- [x] Result dialog matches existing modal tokens, spacing, typography, buttons, backdrop, and animation timing.
- [x] Draw result avoids excessive celebration.
- [x] Play Again restarts classic mode.
- [x] Back to Home returns to the home route.
- [x] Result dialog tests pass for X win, O win, and draw variants.
- [x] `flutter analyze` is clean.
- [x] Commit and push phase changes to GitHub.

---

## Phase 7 - Routing And Home Entry Point

**Goal:** Enable the `Play Classic` card and route users into classic gameplay.

**Scope In:**

- Add route support for classic mode using one of these approaches:
  - Preferred: keep `AppRoutes.game` and pass `GameMode.classic` in `settings.arguments`.
  - Alternative: add `AppRoutes.classicGame` if explicit routes are preferred.
- Update `AppRouter` to parse the selected mode safely.
- Update `HomeScreen`:
  - remove disabled style from `Play Classic`
  - remove `Coming Soon` badge
  - add `onTap`
  - play start audio consistently with `Play ShiftTac`
  - navigate to gameplay in classic mode
- Consider renaming existing `Play ShiftTac` to `Play ShiftTac` or `Play Shift` to reduce ambiguity.
- Keep `Play vs AI` disabled.

**Scope Out:**

- AI mode.
- Any mode selection modal.
- Deep link work beyond route argument handling.

**Implementation Notes:**

- Existing `Navigator.of(context).pushNamed(AppRoutes.game)` should keep opening ShiftTac mode.
- Classic mode routing should be typed where possible.
- If route arguments are invalid, fallback should be ShiftTac mode rather than crashing user navigation.

**Tests:**

- Router creates ShiftTac gameplay with no args.
- Router creates classic gameplay with `GameMode.classic`.
- Home card tap navigates with classic mode argument.
- Existing Play ShiftTac card still opens ShiftTac gameplay.

**DoD:**

- [ ] `Play Classic` is enabled on the home screen.
- [ ] `Play Classic` launches classic gameplay.
- [ ] Existing `Play ShiftTac` behavior remains intact.
- [ ] Invalid/missing route args are handled safely.
- [ ] `Play vs AI` remains disabled.
- [ ] Relevant navigation/widget tests pass.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 8 - Documentation And Player-Facing Copy

**Goal:** Make classic mode understandable in docs and prevent confusion between ShiftTac rules and classic rules.

**Scope In:**

- Add or update rules documentation:
  - classic mode keeps marks permanently
  - classic mode can draw
  - ShiftTac has no draw state
- Update `docs/structure.md` if new files are added.
- Update roadmap/development docs if they track shipped phases.
- Review home card subtitles:
  - Classic: `Traditional 3x3. Every mark stays on the board.`
  - ShiftTac: clarify active-mark shifting if needed.
- Review How To Play entry points:
  - Current how-to-play content teaches ShiftTac mechanics.
  - Keep How To Play ShiftTac-focused for this implementation.
  - Avoid implying the ShiftTac tutorial applies to classic mode.

**Scope Out:**

- Full classic tutorial sequence.
- How To Play mode selector.
- Marketing screenshots.

**Implementation Notes:**

- `docs/rules.md` currently says ShiftTac has no draw state. Keep that true and add classic rules separately.
- Avoid overloading "local" to mean both modes unless UI copy is clear.
- How To Play remains ShiftTac-focused for now; classic mode can be documented in rules/copy without adding a tutorial flow.

**DoD:**

- [ ] Rules docs clearly distinguish ShiftTac from classic mode.
- [ ] Structure docs list new files if the project maintains that document manually.
- [ ] Home copy clearly communicates the difference between modes.
- [ ] How To Play remains ShiftTac-focused and does not mislead classic players.
- [ ] Documentation links and references are accurate.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 9 - Full Regression And Release Polish

**Goal:** Verify both local modes are stable and polished together.

**Scope In:**

- Run the full local quality gate:
  - `flutter analyze`
  - `flutter test`
  - targeted widget tests if not included in `flutter test`
- Manually verify on at least one emulator/device:
  - Play ShiftTac / ShiftTac can win.
  - ShiftTac still rotates oldest marks.
  - ShiftTac still has no draw.
  - Play Classic can win.
  - Play Classic can draw.
  - Classic board never fades oldest marks.
  - Win dialog still looks correct.
  - Draw result uses the shared result dialog, `assets/icons/draw.svg`, and grey palette.
  - Play Again works after win and draw.
  - Back to Home works after win and draw.
  - Pause, resume, restart, and back/exit flows work in both modes.
- Check accessibility basics:
  - dialog content is readable
  - buttons have clear labels
  - board remains usable after mode changes
- Review for cleanup:
  - no unused compatibility wrappers
  - no stale imports
  - no TODOs unless intentionally tracked
  - no debug logs

**Scope Out:**

- New features after classic mode.
- AI mode.
- Match history.

**DoD:**

- [ ] `flutter analyze` is clean.
- [ ] `flutter test` is green.
- [ ] Manual ShiftTac win flow passes.
- [ ] Manual ShiftTac rotation flow passes.
- [ ] Manual classic win flow passes.
- [ ] Manual classic draw flow passes.
- [ ] Draw result visually follows the shared result dialog system and grey palette.
- [ ] No known regressions in home, routing, pause, restart, win, or exit flows.
- [ ] Code review is complete.
- [ ] Commit and push phase changes to GitHub.

---

## Suggested Phase Order For PRs

Each phase can be a separate PR if the team wants small reviewable changes:

1. Domain mode/status/rule boundary.
2. ShiftTac engine rename/refactor.
3. Classic engine and tests.
4. Mode-aware cubit/state.
5. Mode-aware gameplay UI and board visuals.
6. Shared result dialog draw variant.
7. Home/routing enablement.
8. Docs and copy.
9. Final regression polish.

If smaller PRs are too slow, combine Phases 1-3 into one domain PR, Phases 4-7 into one UI integration PR, and keep Phase 9 as final polish.

## Non-Goals

- AI opponent.
- Online multiplayer.
- Persistent scoreboard.
- Saved games.
- Board sizes other than 3x3.
- New design language separate from the current ShiftTac system.

## Resolved Decisions

- Classic mode shares ShiftTac's random starting-player behavior.
- Draw uses `assets/icons/draw.svg`.
- Draw uses the same result dialog component as X and O wins.
- Draw uses grey shades in the same palette roles that X uses red shades and O uses green shades.
- How To Play remains ShiftTac-focused for now.
