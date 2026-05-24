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
- Classic mode should start with Player X unless the project intentionally chooses random starts for all local modes.
- Classic mode has a draw terminal state.
- ShiftTac mode keeps its "no draw" behavior.
- The draw dialog should use the same modal foundation as `WinDialog` and `ExitGameDialog`: `ModalBackdrop`, `Dialog`, `AppSpacing`, `AppTextStyles`, `PrimaryButton`, `SecondaryButton`, and `AppColors`.
- The draw dialog should feel calm and neutral, not celebratory. It should avoid winner-colored accents and excessive animation.

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
    |   +-- draw_dialog.dart
    |   +-- game_board.dart
    |   +-- win_dialog.dart
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
- Confirm whether classic mode starts with X or follows the current random starter behavior.
- Confirm draw dialog copy and tone.
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

- [ ] Implementation direction is agreed: shared rules contract or minimal mode branch.
- [ ] Classic starting-player behavior is decided.
- [ ] Draw dialog title, body copy, button labels, and stats are decided.
- [ ] Existing tests are run and current failures, if any, are documented before changes.
- [ ] Commit and push phase changes to GitHub.

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
- Draw dialog.

**Implementation Notes:**

- `oldestPositionFor` can return `null` in classic mode.
- The rule contract should not import Flutter.
- `GameMode` belongs in domain models, not routing or UI.
- `GameStatus.draw` should be handled in switches immediately, even if the draw path is not reachable until Phase 3.

**Tests:**

- Update existing tests that exhaustively switch on `GameStatus`.
- Add small model tests only if the project has coverage expectations for enums or initial state.

**DoD:**

- [ ] `GameMode` exists in the domain layer.
- [ ] `GameStatus.draw` exists and all Dart switches compile.
- [ ] A mode/rules boundary exists and is pure Dart.
- [ ] Existing ShiftTac engine behavior remains unchanged.
- [ ] `flutter analyze` is clean.
- [ ] Existing tests pass.
- [ ] Commit and push phase changes to GitHub.

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

- [ ] Current FIFO behavior lives in `ShiftGameEngine` or an equivalent clearly named rule class.
- [ ] Current ShiftTac tests are updated and passing.
- [ ] Any temporary compatibility wrapper is documented and scheduled for removal if not intended long term.
- [ ] No classic logic is mixed into the ShiftTac engine.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

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
- Classic initial state should use the decided starting-player policy.

**Scope Out:**

- Draw dialog UI.
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

- [ ] `ClassicGameEngine` exists and is pure Dart.
- [ ] Classic mode supports win, draw, invalid move, and terminal-state rejection.
- [ ] Draw detection cannot override a ninth-move win.
- [ ] Classic engine tests cover all core rule paths.
- [ ] Existing ShiftTac tests still pass.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

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

- [ ] `GameCubit` can run ShiftTac and classic without duplicating lifecycle code.
- [ ] Restart preserves the active mode.
- [ ] Input locking behavior is unchanged.
- [ ] Classic cubit tests cover accepted, rejected, draw, and restart paths.
- [ ] ShiftTac cubit tests still pass.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

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
- Draw dialog implementation.
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

- [ ] `GameplayScreen` can be constructed for ShiftTac or classic mode.
- [ ] Classic board visuals do not show ShiftTac fade/oldest preview.
- [ ] ShiftTac board visuals are unchanged.
- [ ] Won and draw terminal states both freeze board input.
- [ ] Indicator and player panels render draw state cleanly.
- [ ] `flutter analyze` is clean.
- [ ] Relevant widget/unit tests pass.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 6 - Draw Dialog Following The Design System

**Goal:** Add a polished draw result dialog that matches the existing modal system without feeling like a winner celebration.

**Scope In:**

- Add `DrawDialog` or replace `WinDialog` with a generalized `MatchResultDialog`.
- The preferred path is a generalized dialog if it reduces duplication without making the code harder to read:
  - winner result: current winner symbol, winner accent, "X Wins!" / "O Wins!"
  - draw result: neutral symbol/treatment, neutral accent, "It's a Draw!" or "Draw Game"
- Draw dialog layout should follow the existing `WinDialog` structure:
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
- Draw dialog visual language:
  - neutral icon or balanced X/O visual
  - no winner-colored symbol
  - no confetti
  - warm, calm glow using low-alpha surface/primary tones
  - dialog entrance between 250ms and 320ms, matching `design.md`
- Draw dialog copy:
  - title: `It's a Draw!` or final approved copy
  - body: short and neutral, for example `No winner this round. Try another match.`
  - stats: `Total moves`, `Match time`
- Hook draw presentation into `GameplayScreen` after board state settles.

**Scope Out:**

- Persistent match history.
- Scoreboard.
- New art assets unless existing assets cannot communicate draw clearly.

**Implementation Notes:**

- Existing design references:
  - `design.md` specifies dialog entrance at 250-320ms.
  - `design.md` specifies win dialog stats and actions.
  - Current `WinDialog` and `ExitGameDialog` already implement the modal foundation.
- If a new asset is needed, add it through the existing icon constants pattern.
- The draw dialog should not use `Player` as required input.
- The dialog should be non-dismissible if win dialog is non-dismissible, keeping terminal result behavior consistent.

**Tests:**

- Draw dialog renders title, body, total moves, match time, Play Again, and Back to Home.
- Play Again dismisses dialog and restarts in classic mode.
- Back to Home dismisses dialog and navigates home.
- Draw dialog does not show a winner-specific X/O winner title.

**DoD:**

- [ ] Draw result is presented through a design-system-compliant modal.
- [ ] Draw dialog matches existing modal tokens, spacing, typography, buttons, backdrop, and animation timing.
- [ ] Draw dialog uses neutral visual treatment and avoids excessive celebration.
- [ ] Play Again restarts classic mode.
- [ ] Back to Home returns to the home route.
- [ ] Draw dialog tests pass.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

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
  - play start audio consistently with `Play Local`
  - navigate to gameplay in classic mode
- Consider renaming existing `Play Local` to `Play ShiftTac` or `Play Shift` to reduce ambiguity.
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
- Existing Play Local card still opens ShiftTac gameplay.

**DoD:**

- [ ] `Play Classic` is enabled on the home screen.
- [ ] `Play Classic` launches classic gameplay.
- [ ] Existing `Play Local` behavior remains intact.
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
  - If no classic tutorial is added yet, avoid implying the ShiftTac tutorial applies to classic.

**Scope Out:**

- Full classic tutorial sequence unless product decides it is required for release.
- Marketing screenshots.

**Implementation Notes:**

- `docs/rules.md` currently says ShiftTac has no draw state. Keep that true and add classic rules separately.
- Avoid overloading "local" to mean both modes unless UI copy is clear.

**DoD:**

- [ ] Rules docs clearly distinguish ShiftTac from classic mode.
- [ ] Structure docs list new files if the project maintains that document manually.
- [ ] Home copy clearly communicates the difference between modes.
- [ ] How To Play copy does not mislead classic players.
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
  - Play Local / ShiftTac can win.
  - ShiftTac still rotates oldest marks.
  - ShiftTac still has no draw.
  - Play Classic can win.
  - Play Classic can draw.
  - Classic board never fades oldest marks.
  - Win dialog still looks correct.
  - Draw dialog matches the design system.
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
- [ ] Draw dialog visually follows the existing modal system.
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
6. Draw dialog.
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

## Open Questions

- Should classic mode always start with X, or should it share ShiftTac's random starter?
- Should the current home card label `Play Local` be renamed to `Play ShiftTac` before classic mode ships?
- Should draw use a new asset, a balanced X/O composition, or an existing neutral icon?
- Should the result dialog be generalized now, or should `DrawDialog` be separate to minimize risk?
- Should How To Play get a small mode selector, or remain ShiftTac-focused for now?
