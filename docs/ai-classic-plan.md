# AI Classic Mode Implementation Plan

## Purpose

AI classic mode adds a solo opponent for traditional 3x3 Tic Tac Toe while preserving the current clean game architecture.

The implementation should reuse the existing classic rules engine, board UI, result dialog, timer, audio/haptics, pause/restart lifecycle, route shell, and design system. The AI should not become a second source of gameplay truth. It should only choose a legal position, then let `ClassicGameEngine` apply the move.

## Expected User Flow

1. User taps the existing home-screen `Play vs AI` card.
2. A mode-selection dialog opens.
3. The dialog shows:
   - `Classic` as the enabled option.
   - `ShiftTac` as a disabled or non-selectable option with a `Coming Soon` label.
4. User taps `Classic`.
5. A difficulty-selection dialog opens.
6. User chooses:
   - `Easy`
   - `Intermediate`
   - `Hard`
7. App starts a classic match against the bot.
8. Human plays as X by default; bot plays as O.
9. Bot moves are delayed slightly so they feel intentional and readable.

The dialogs should follow the existing system design: warm surfaces, rounded cards, app typography, existing spacing tokens, muted secondary states, existing audio feedback, and no visual style that feels separate from the rest of the app.

## Current Baseline

The current codebase already has the main pieces AI classic mode should build on:

- `ClassicGameEngine` owns classic 3x3 rules.
- `GameRules` abstracts ShiftTac and classic rules.
- `GameCubit` coordinates timer, pause/resume, restart, input lock, and move application.
- `GameSnapshot` stores marks, current player, status, winner, winning line, and turn index.
- `WinChecker` detects all 8 winning lines.
- `GameplayScreen` can launch ShiftTac or classic via `GameMode`.
- `HomeScreen` already has a `Play vs AI` card placeholder.
- `MatchResultDialog` already supports X win, O win, and draw.

## Product Decisions

- AI mode uses classic rules first.
- ShiftTac AI is intentionally out of scope and is shown as `Coming Soon`.
- Human is `Player.x` by default.
- Bot is `Player.o` by default.
- Starting player policy should be explicit for AI mode:
  - Preferred launch behavior: human starts for the first shipped AI version.
  - Future enhancement: allow "Play as X/O" or randomized starter.
- Bot move delay should be short enough to keep the game fast and long enough to show the player's move first.
  - Target: 450-700 ms.
- AI logic must be pure Dart and testable without Flutter.
- Difficulty behavior should be understandable:
  - Easy: casual/random.
  - Intermediate: tactical but beatable.
  - Hard: optimal/unbeatable classic Tic Tac Toe.
- Bot selection must never bypass `ClassicGameEngine`.
- Game result copy and visuals should keep using the existing match result flow.
- No persisted stats, online play, or account features in this work.

## Target Architecture

```text
lib/features/game/
+-- domain/
|   +-- models/
|   |   +-- bot_difficulty.dart
|   |   +-- bot_opponent_config.dart
|   |   +-- game_session_config.dart
|   |   +-- game_mode.dart
|   |   +-- player.dart
|   |   +-- position.dart
|   +-- logic/
|       +-- classic_bot_strategy.dart
|       +-- classic_easy_bot_strategy.dart
|       +-- classic_intermediate_bot_strategy.dart
|       +-- classic_hard_bot_strategy.dart
|       +-- classic_bot_helpers.dart
|       +-- classic_game_engine.dart
|       +-- game_rules.dart
+-- presentation/
    +-- state/
    |   +-- game_cubit.dart
    |   +-- game_state.dart
    +-- widgets/
    |   +-- ai_mode_selection_dialog.dart
    |   +-- ai_difficulty_dialog.dart
    +-- screens/
        +-- gameplay_screen.dart
lib/features/home/
+-- presentation/
    +-- screens/
        +-- home_screen.dart
```

The exact file names can change during implementation, but the boundary should remain:

- `ClassicGameEngine` decides whether a move is legal and what the next game state is.
- `ClassicBotStrategy` decides which legal position the bot wants to play.
- `GameCubit` coordinates whose turn it is, timers, locks, delays, and applying moves through rules.
- Home/dialog widgets collect user intent and create a session config.

## Core Domain Shape

### Difficulty

```dart
enum BotDifficulty {
  easy,
  intermediate,
  hard,
}
```

### Bot Config

```dart
class BotOpponentConfig {
  const BotOpponentConfig({
    required this.difficulty,
    required this.botPlayer,
  });

  final BotDifficulty difficulty;
  final Player botPlayer;
}
```

### Session Config

```dart
class GameSessionConfig {
  const GameSessionConfig({
    required this.mode,
    this.bot,
    this.startingPlayer,
  });

  final GameMode mode;
  final BotOpponentConfig? bot;
  final Player? startingPlayer;
}
```

`GameSessionConfig` should be accepted by routing while `GameMode` route arguments remain supported for backwards compatibility.

### Bot Strategy

```dart
abstract interface class ClassicBotStrategy {
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  });
}
```

The strategy should throw or fail loudly in tests if called with:

- a non-playing snapshot
- a snapshot where it is not the bot's turn
- a full board
- a ShiftTac session

Production code should avoid calling the strategy in those states.

## Difficulty Behavior

### Easy

Easy should choose a random available position.

Goals:

- Always legal.
- Fast.
- Weak enough for new players to beat.
- No lookahead.

### Intermediate

Intermediate should use tactical priorities:

1. Win immediately if possible.
2. Block the human's immediate win.
3. Take center.
4. Take a corner.
5. Take a side.
6. Fall back to the first available move if needed.

Goals:

- Feels smart.
- Avoids obvious one-move losses.
- Still allows traps and forks from stronger human players.

### Hard

Hard should use minimax over the classic 3x3 game tree.

Scoring:

- Bot win: `10 - depth`
- Human win: `depth - 10`
- Draw: `0`

Rules:

- Use `ClassicGameEngine.instance.attemptMove(...)` to simulate every candidate move.
- Maximize when `snapshot.currentPlayer == botPlayer`.
- Minimize when `snapshot.currentPlayer == botPlayer.opponent`.
- Prefer faster wins and slower losses through depth-adjusted scoring.
- Use a stable tie-break order so tests are deterministic.

Hard mode should be unbeatable. The worst result against perfect human play should be a draw.

## UI And Design Requirements

### Home Entry

The existing `Play vs AI` card becomes tappable.

Required behavior:

- Play existing tap audio.
- Open mode-selection dialog.
- Do not navigate directly to gameplay.

### Mode Selection Dialog

Content:

- Title: `Play vs AI`
- Body/helper copy: concise explanation that AI is currently available for classic mode.
- Option 1: `Classic`
  - Enabled.
  - Subtitle: `Traditional 3x3 against the bot.`
- Option 2: `ShiftTac`
  - Disabled or non-selectable.
  - Badge: `Coming Soon`
  - Subtitle: `AI for shifting marks will arrive later.`

Design:

- Use existing modal surface patterns where possible.
- Use `ModalBackdrop`, app text styles, spacing tokens, and app colors.
- Disabled ShiftTac option should look intentional, not broken.
- Support barrier dismissal only if consistent with existing app modal behavior.

### Difficulty Dialog

Content:

- Title: `Choose Difficulty`
- Options:
  - `Easy`
  - `Intermediate`
  - `Hard`
- Each option should include short helper copy:
  - Easy: `Random moves for relaxed practice.`
  - Intermediate: `Blocks threats and takes wins.`
  - Hard: `Optimal classic Tic Tac Toe.`

Behavior:

- Tapping a difficulty navigates to `AppRoutes.game` with a `GameSessionConfig`.
- Dialog closes cleanly before or during navigation, avoiding double overlays.
- Back/cancel returns to Home without side effects.

### Gameplay Indicators

Minimum viable implementation can keep the existing player panels and turn indicator, but it should be clear enough that one side is the bot.

Preferred behavior:

- Player O label or supporting text indicates `AI`.
- During bot turn, board input is blocked.
- Optional waiting dots may be reused to communicate that the bot is thinking.

## Phase 0 - Planning Lock And Baseline Audit

**Goal:** Confirm scope, baseline behavior, and integration boundaries before production changes.

**Scope In:**

- Review existing classic mode implementation.
- Review home card and current modal patterns.
- Confirm whether `Play vs AI` should be classic-only for first release.
- Confirm route compatibility requirements.
- Confirm starting-player behavior for AI sessions.
- Record current test/analyze baseline.

**Scope Out:**

- No production code changes beyond this plan.
- No bot implementation.
- No UI implementation.

**Implementation Notes:**

- Treat ShiftTac AI as out of scope.
- Do not redesign classic mode.
- Do not add persistence or stats.
- Keep all future phase changes small enough to review.

**Tests:**

- Run `flutter analyze`.
- Run `flutter test`.
- Document any pre-existing failures before starting implementation.

**DoD:**

- [x] AI classic scope is documented.
- [x] Starting-player behavior for AI sessions is confirmed.
- [x] Current tests/analyze baseline is recorded.
- [x] Existing architecture touch points are identified.
- [x] Commit and push phase changes to GitHub.

### Phase 0 Completion — 2026-05-29

#### Locked scope (AI classic v1)

| Decision | Locked value |
| --- | --- |
| First AI rule set | Classic 3×3 only (`GameMode.classic` + `ClassicGameEngine`) |
| ShiftTac AI | Out of scope; shown as `Coming Soon` in mode-selection dialog |
| Human side | `Player.x` by default |
| Bot side | `Player.o` by default |
| Starting player (AI sessions) | **Human (`Player.x`) always starts** for v1 via `GameSnapshot.initial(startingPlayer: Player.x)` in session config (Phase 1+). Local classic multiplayer keeps random starter unchanged. |
| Bot move delay | 450–700 ms (implemented in Phase 5) |
| Bot move application | `ClassicBotStrategy` chooses `Position`; `ClassicGameEngine.attemptMove` applies it |
| Persistence / stats | None in this feature |
| Result UI | Reuse `MatchResultDialog` (human win, bot win, draw) |

**Play vs AI entry (v1):** The home card opens dialogs only — no direct navigation to gameplay. Flow: `Play vs AI` → mode dialog → `Classic` → difficulty dialog → `AppRoutes.game` with `GameSessionConfig` (Phase 7).

#### Starting-player behavior (confirmed)

- **Local classic** (existing): continues using `GameSnapshot.initial()` random starter (`Random().nextBool()`).
- **AI classic** (new): human (`Player.x`) starts every match so the first interaction is always the player, and bot scheduling is predictable on open.
- **Future enhancement:** optional “Play as O” or random starter — not in v1.

#### Test and analyze baseline (pre-implementation)

Run on **2026-05-29**:

| Command | Result | Detail |
| --- | --- | --- |
| `flutter analyze` | **2 info issues** (no errors) | `test/match_result_dialog_test.dart` — `unnecessary_underscores` (lines 21, 195) |
| `flutter test` | **107 passed, 2 failed** | Failures are pre-existing, unrelated to AI work |

**Failed tests (document before Phase 1):**

| Test file | Test name | Cause |
| --- | --- | --- |
| `test/match_result_dialog_test.dart` | `Back to Home dismisses dialog and invokes callback` | `AppAudioScope not found` when tapping Back to Home without `AppAudioScope` in test harness |
| `test/match_result_dialog_test.dart` | `Back to Home navigates to home route` | Same `AppAudioScope` assertion; navigation expectation never reached |

**Passing suites relevant to AI work:**

| File | Focus |
| --- | --- |
| `test/classic_game_engine_test.dart` | Classic rules, win, draw, validation |
| `test/game_cubit_test.dart` | Cubit lifecycle, input lock, restart, pause |
| `test/app_router_test.dart` | `GameMode` route args, ShiftTac default |
| `test/home_screen_test.dart` | Home cards; `Play vs AI` disabled with `Coming Soon` |
| `test/shift_game_engine_test.dart` | ShiftTac FIFO (must not regress) |
| `test/win_checker_test.dart` | Shared win detection |

No skipped tests observed in this run. Fix or wrap `match_result_dialog_test.dart` in a follow-up if a green baseline is required before Phase 9; not blocking Phase 1 domain work.

#### Architecture touch points

| Layer | Path | Role for AI classic |
| --- | --- | --- |
| Classic rules | `lib/features/game/domain/logic/classic_game_engine.dart` | Sole authority for legal moves, win, draw |
| Rules contract | `lib/features/game/domain/logic/game_rules.dart` | Unchanged; AI sessions still use `ClassicGameEngine` |
| Snapshot | `lib/features/game/domain/logic/game_snapshot.dart` | Board state; `initial({Player? startingPlayer})` for human-first AI |
| Win detection | `lib/features/game/domain/logic/win_checker.dart` | Shared; bot simulation uses engine, not duplicate win logic |
| Cubit | `lib/features/game/presentation/state/game_cubit.dart` | Phase 5: bot timer, turn gate, shared `_applyAcceptedMove` |
| Gameplay UI | `lib/features/game/presentation/screens/gameplay_screen.dart` | Accept `GameSessionConfig`; optional bot labels (Phase 8) |
| Routing | `lib/core/routing/app_router.dart` | Phase 1: parse `GameSessionConfig`; keep `GameMode` fallback |
| Home entry | `lib/features/home/presentation/screens/home_screen.dart` | Phase 6: enable `Play vs AI` (`disabledSecondary` → tappable) |
| Home card widget | `lib/features/home/presentation/widgets/home_action_card.dart` | `disabledSecondary` / `secondary` styles; badge support |
| Modals (reference) | `exit_game_dialog.dart`, `match_result_dialog.dart`, `pause_bottom_sheet.dart` | `showGeneralDialog` + `ModalBackdrop` + 300 ms transitions |
| Modal primitive | `lib/core/widgets/modal_backdrop.dart` | Reuse for AI selection dialogs |
| Audio | `lib/core/audio/app_audio.dart` | Tap/swipe on dialog actions; tests need `AppAudioScope` |
| Result flow | `lib/features/game/presentation/widgets/match_result_dialog.dart` | End-of-match for AI wins/losses/draws |

**New files (planned, not in repo yet):** `bot_difficulty.dart`, `bot_opponent_config.dart`, `game_session_config.dart`, `classic_bot_strategy.dart`, easy/intermediate/hard strategies, `ai_mode_selection_dialog.dart`, `ai_difficulty_dialog.dart`.

#### Home and modal baseline audit

**`Play vs AI` today (`home_screen.dart`):**

- Style: `HomeActionCardStyle.disabledSecondary`
- `badgeLabel: 'Coming Soon'`
- No `onTap`; `home_screen_test.dart` asserts no `InkWell` ancestor on the card title

**`Play Classic` today:** Enabled (`secondary`), navigates with `arguments: GameMode.classic` — unchanged by AI work except shared route parser extension in Phase 1.

**Modal patterns to mirror:**

- `ExitGameDialog` / `MatchResultDialog`: `showGeneralDialog`, transparent barrier, `ModalBackdrop`, `AppTextStyles`, `AppSpacing`, `PrimaryButton` / `SecondaryButton`
- `ExitGameDialog`: barrier dismissible + `AppAudioScope.read` for swipe
- AI mode dialog: Classic enabled; ShiftTac disabled with `Coming Soon` (can reuse `HomeActionCard`-like row or compact list inside modal sheet)
- AI difficulty dialog: three tappable rows with helper copy from plan §UI

#### Route compatibility (confirmed)

| Arguments | Current behavior | After Phase 1 |
| --- | --- | --- |
| `null` / invalid | `GameMode.shift` | Unchanged |
| `GameMode.shift` | ShiftTac | Unchanged |
| `GameMode.classic` | Local classic | Unchanged |
| `GameSessionConfig` | N/A | Classic AI with `bot` + optional `startingPlayer` |

`Navigator.pushNamed(AppRoutes.game)` from **Play ShiftTac** must continue to open ShiftTac with no args.

#### Classic engine baseline (unchanged by Phase 0)

- Rejects moves when not `playing` or cell occupied
- Appends marks; no FIFO removal (`removedMove` always `null`)
- Win via `WinChecker`; draw when 9 cells filled without winner
- `oldestPositionFor` returns `null` (no fade preview)
- Random starter only when `GameSnapshot.initial()` called without `startingPlayer`

#### ShiftTac / local modes — preserve unchanged

- `ShiftGameEngine` FIFO, no draw
- `GameCubit.shift()` and `GameCubit.classic()` local constructors
- Board fade preview for ShiftTac only
- Existing home navigation for ShiftTac and Classic

---

## Phase 1 - Session Models And Routing Contract

**Goal:** Add explicit session configuration for local multiplayer and AI gameplay without changing visible behavior.

**Scope In:**

- Add `BotDifficulty`.
- Add `BotOpponentConfig`.
- Add `GameSessionConfig`.
- Update route argument parsing to accept:
  - existing `GameMode`
  - new `GameSessionConfig`
  - invalid/missing args falling back to ShiftTac local multiplayer
- Update `GameplayScreen` constructor to receive a session config or equivalent.
- Preserve existing `Navigator.pushNamed(AppRoutes.game)` ShiftTac behavior.
- Preserve existing `Navigator.pushNamed(AppRoutes.game, arguments: GameMode.classic)` classic behavior.

**Scope Out:**

- No bot move logic.
- No home-screen AI card activation.
- No difficulty dialogs.
- No player-label UI changes unless required to compile cleanly.

**Implementation Notes:**

- Keep models in the game domain layer.
- Avoid UI-only fields in domain config.
- Make default local sessions easy to construct.
- Avoid string route arguments for difficulty unless there is a strong reason.

**Tests:**

- Route parser returns ShiftTac local session for null/invalid args.
- Route parser preserves `GameMode.shift`.
- Route parser preserves `GameMode.classic`.
- Route parser accepts `GameSessionConfig` unchanged.

**DoD:**

- [x] Session models exist and are pure Dart.
- [x] Existing game route behavior remains backwards compatible.
- [x] New AI-capable route config compiles and is covered by tests.
- [x] `flutter analyze` is clean.
- [x] Relevant tests pass.
- [x] Commit and push phase changes to GitHub.

### Phase 1 Completion — 2026-05-29

**Deliverables:**

```text
lib/features/game/domain/models/bot_difficulty.dart
lib/features/game/domain/models/bot_opponent_config.dart
lib/features/game/domain/models/game_session_config.dart
lib/core/routing/app_router.dart
lib/features/game/presentation/screens/gameplay_screen.dart
test/game_session_config_test.dart
test/app_router_test.dart
```

**Routing:** `AppRouter.sessionFromRouteArguments` accepts `GameSessionConfig`, `GameMode`, or invalid/null (ShiftTac default). `gameModeFromRouteArguments` delegates to session.mode.

**Gameplay:** `GameplayScreen` takes `GameSessionConfig session`; `mode` getter preserved for existing tests. Cubit creation unchanged (bot wiring in Phase 5).

**Tests:** `game_session_config_test.dart` (3) + expanded `app_router_test.dart` (session + route widget tests).

---

## Phase 2 - Classic Bot Strategy Foundation

**Goal:** Add pure-Dart bot strategy interfaces and shared board helpers.

**Scope In:**

- Add `ClassicBotStrategy`.
- Add helper functions for:
  - occupied positions
  - available positions
  - applying simulated classic moves
  - checking immediate winning moves
  - stable move ordering
- Add a factory that maps `BotDifficulty` to a strategy.
- Keep random injection possible for deterministic tests.

**Scope Out:**

- No cubit scheduling.
- No UI.
- No minimax yet unless it naturally fits in this phase.

**Implementation Notes:**

- Helpers should not import Flutter.
- Helpers should not duplicate win rules manually when `ClassicGameEngine` can be used.
- Stable ordering should be documented. Recommended order:
  1. center
  2. corners
  3. sides
- Randomness should be isolated to easy mode.

**Tests:**

- Available positions exclude X and O moves.
- Available positions are stable and complete on an empty board.
- Available positions return empty on a full board.
- Strategy factory returns the expected implementation for each difficulty.

**DoD:**

- [x] Bot strategy contract exists.
- [x] Shared helpers are pure Dart and tested.
- [x] Difficulty-to-strategy creation is explicit.
- [x] No gameplay UI behavior changes.
- [x] `flutter analyze` is clean.
- [x] Relevant tests pass.
- [x] Commit and push phase changes to GitHub.

### Phase 2 Completion — 2026-05-29

**Deliverables:**

```text
lib/features/game/domain/logic/classic_bot_strategy.dart
lib/features/game/domain/logic/classic_bot_helpers.dart
lib/features/game/domain/logic/classic_bot_strategy_factory.dart
lib/features/game/domain/logic/classic_easy_bot_strategy.dart
lib/features/game/domain/logic/classic_intermediate_bot_strategy.dart
lib/features/game/domain/logic/classic_hard_bot_strategy.dart
test/classic_bot_helpers_test.dart
test/classic_bot_strategy_factory_test.dart
```

**Helpers:** `occupiedPositions`, `availablePositions` (stable order), `sortPositionsStable`, `simulateClassicMove` (via `ClassicGameEngine`), `findImmediateWin`. `classicStableMoveOrder`: center → corners → sides.

**Factory:** `ClassicBotStrategyFactory.forDifficulty` maps each `BotDifficulty` to its strategy type; `random` is wired for easy (Phase 3). Strategy `chooseMove` bodies are stubs until Phases 3–4.

**Tests:** 11 passing (`classic_bot_helpers_test` + `classic_bot_strategy_factory_test`).

---

## Phase 3 - Easy And Intermediate Bots

**Goal:** Implement the first two difficulty levels with focused, readable behavior.

**Scope In:**

- Implement easy bot:
  - chooses a random available legal position
  - supports injected `Random`
- Implement intermediate bot:
  - takes immediate win
  - blocks immediate human win
  - prefers center
  - prefers corners
  - prefers sides
  - uses deterministic tie-breaks

**Scope Out:**

- Hard/minimax.
- Cubit scheduling.
- UI selection.

**Implementation Notes:**

- Intermediate should simulate candidate moves through `ClassicGameEngine`.
- Do not infer wins with ad-hoc board arrays if existing domain types are enough.
- Keep strategy methods small and easy to test.
- Prefer clear tactical ordering over cleverness.

**Tests:**

- Easy always returns a legal empty cell.
- Easy can be made deterministic with a seeded or fake random source.
- Intermediate takes an immediate winning move.
- Intermediate blocks an immediate human winning move.
- Intermediate chooses center on an empty or suitable board.
- Intermediate chooses a corner before a side.
- Intermediate returns only legal cells.

**DoD:**

- [x] Easy strategy is implemented and tested.
- [x] Intermediate strategy is implemented and tested.
- [x] Intermediate behavior matches documented priority order.
- [x] Strategies do not mutate input snapshots.
- [x] `flutter analyze` is clean.
- [x] Relevant tests pass.
- [x] Commit and push phase changes to GitHub.

### Phase 3 Completion — 2026-05-29

**Deliverables:**

```text
lib/features/game/domain/logic/classic_easy_bot_strategy.dart
lib/features/game/domain/logic/classic_intermediate_bot_strategy.dart
lib/features/game/domain/logic/classic_bot_helpers.dart (findImmediateThreat, firstAvailableInOrder)
test/classic_easy_bot_strategy_test.dart
test/classic_intermediate_bot_strategy_test.dart
```

**Easy:** Random choice among `availablePositions` with injectable `Random`.

**Intermediate:** Win → block (`findImmediateThreat`) → center → corners → sides → stable fallback.

**Tests:** 9 new strategy tests + existing helper tests (16 total in Phase 3 scope).

---

## Phase 4 - Hard Bot With Minimax

**Goal:** Implement an optimal classic Tic Tac Toe bot.

**Scope In:**

- Implement hard bot using minimax.
- Score terminal states:
  - bot win: `10 - depth`
  - human win: `depth - 10`
  - draw: `0`
- Use `ClassicGameEngine` for every simulated move.
- Add deterministic tie-breaking.
- Keep recursion isolated from UI/cubit code.

**Scope Out:**

- Alpha-beta pruning unless needed.
- Difficulty personality changes.
- ShiftTac AI.

**Implementation Notes:**

- Classic 3x3 minimax is small enough without heavy optimization.
- If performance is still a concern, add memoization keyed by board state, current player, and bot player.
- Avoid mutable shared recursion state.
- Make terminal-state scoring easy to review.

**Tests:**

- Hard takes a winning move.
- Hard blocks an immediate loss.
- Hard forces a draw from common opening positions.
- Hard never chooses an occupied cell.
- Hard returns a deterministic move when multiple moves share a score.
- Hard handles a one-cell-left draw.
- Hard handles a one-cell-left win.

**DoD:**

- [x] Hard strategy is implemented with minimax.
- [x] Hard mode is unbeatable under tested scenarios.
- [x] Minimax simulations use `ClassicGameEngine`.
- [x] Tie-break behavior is deterministic.
- [x] `flutter analyze` is clean.
- [x] Relevant tests pass.
- [x] Commit and push phase changes to GitHub.

### Phase 4 Completion — 2026-05-29

**Deliverables:**

```text
lib/features/game/domain/logic/classic_hard_bot_strategy.dart
test/classic_hard_bot_strategy_test.dart
```

**Minimax:** Maximizes on bot turns, minimizes on human turns. Terminal scores: bot win `10 - depth`, human win `depth - 10`, draw `0`. All moves via `simulateClassicMove` → `ClassicGameEngine`.

**Tie-break:** Root and child moves iterate `availablePositions` (stable center → corners → sides order); first move with strictly better score wins.

**Tests:** 8 passing — win, block, optimal opening, legal cells, determinism, one-cell win/draw, full game vs tactical human (bot O never loses).

---

## Phase 5 - GameCubit AI Turn Lifecycle

**Goal:** Let `GameCubit` coordinate human and bot turns while keeping gameplay rules in the engine and move choice in strategies.

**Scope In:**

- Allow `GameCubit` to receive an optional `BotOpponentConfig`.
- Create/select a `ClassicBotStrategy` for AI classic sessions.
- Reject human taps while it is the bot's turn.
- After an accepted human move, schedule a bot move if:
  - session has bot config
  - snapshot is still playing
  - current player is the bot
- Apply bot moves through `_rules.attemptMove`.
- Reuse the same accepted-move state update path for human and bot moves.
- Cancel pending bot timers on:
  - restart
  - close
  - terminal result
  - app background if needed for consistent pause behavior
- Preserve existing ShiftTac and local classic behavior.

**Scope Out:**

- Home dialog UI.
- Bot difficulty selection UI.
- Match result redesign.

**Implementation Notes:**

- Extract a private method for applying accepted `GameEngineResult` so human and bot moves stay consistent.
- Bot delay should not stack if state changes quickly.
- Bot should not move while pause sheet is active.
- Think carefully about `inputLocked`:
  - human move lock still protects animations
  - bot turn should also block user input
  - bot move should not be lost because a human input lock is active
- If starting player is bot in the future, cubit should support scheduling the first bot move after initial build, but first release can force human starts.

**Tests:**

- Human move schedules a bot move when it becomes bot turn.
- Human move does not schedule bot move after win.
- Human move does not schedule bot move after draw.
- Human taps during bot turn are rejected.
- Bot move updates snapshot through classic rules.
- Restart cancels pending bot move.
- Closing cubit cancels pending bot move.
- ShiftTac mode behavior remains unchanged.
- Local classic mode behavior remains unchanged.

**DoD:**

- [x] `GameCubit` supports optional AI classic sessions.
- [x] Bot turns are scheduled and cancelled correctly.
- [x] Human input is blocked during bot turns.
- [x] Rules remain delegated to `ClassicGameEngine`.
- [x] Existing local modes remain unchanged.
- [x] `flutter analyze` is clean.
- [x] Relevant tests pass.
- [x] Commit and push phase changes to GitHub.

### Phase 5 Completion — 2026-05-29

**Deliverables:**

```text
lib/features/game/presentation/state/game_cubit.dart
lib/features/game/presentation/state/game_state.dart
lib/features/game/presentation/screens/gameplay_screen.dart
lib/core/constants/game_constants.dart
test/game_cubit_ai_test.dart
```

**Cubit:** `GameCubit.fromSession` wires `BotOpponentConfig`, `ClassicBotStrategy`, and `startingPlayer` (AI defaults to human `Player.x`). Shared `_applyAcceptedMove`; bot moves after `botMoveDelayMs` (600 ms). Bot timers cancelled on restart, close, pause, and background.

**Gameplay:** `GameplayScreen` creates cubit via `GameCubit.fromSession(session)`.

**Tests:** `game_cubit_ai_test.dart` (11) + existing `game_cubit_test.dart` (unchanged).

---

## Phase 6 - Home Mode Selection Dialog

**Goal:** Activate `Play vs AI` and introduce the first dialog in the selection flow.

**Scope In:**

- Make `Play vs AI` home card tappable.
- Build `AiModeSelectionDialog` or equivalent.
- Show `Classic` as enabled.
- Show `ShiftTac` as disabled or non-selectable with `Coming Soon`.
- On `Classic`, close or advance to the difficulty dialog.
- Preserve existing home card layout and visual hierarchy.

**Scope Out:**

- Starting gameplay directly.
- Implementing ShiftTac AI.
- Changing ShiftTac or classic local cards.

**Implementation Notes:**

- Use existing modal/backdrop/button/card patterns.
- Reuse `HomeActionCard` styling ideas if appropriate, but avoid a large abstraction unless it removes real duplication.
- Disabled ShiftTac should still be accessible/readable.
- Keep copy concise.
- Play existing audio on meaningful taps.

**Tests:**

- `Play vs AI` card is tappable.
- Tapping opens mode-selection dialog.
- Dialog displays enabled Classic option.
- Dialog displays ShiftTac with `Coming Soon`.
- ShiftTac option does not navigate.
- Classic option advances toward difficulty selection.

**DoD:**

- [ ] Home `Play vs AI` card opens mode selection.
- [ ] Mode dialog follows the app design system.
- [ ] Classic option is enabled.
- [ ] ShiftTac option is clearly marked `Coming Soon`.
- [ ] No route starts until difficulty is chosen.
- [ ] `flutter analyze` is clean.
- [ ] Relevant widget tests pass where practical.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 7 - Difficulty Selection Dialog And Navigation

**Goal:** Let the user choose AI difficulty and launch a configured classic AI session.

**Scope In:**

- Build `AiDifficultyDialog` or equivalent.
- Show Easy, Intermediate, and Hard options with helper copy.
- On difficulty tap, navigate to gameplay with:
  - `GameMode.classic`
  - `BotOpponentConfig`
  - human as X
  - bot as O
  - explicit human starting player if that decision is locked
- Ensure dialogs close cleanly around navigation.
- Preserve back/cancel behavior.

**Scope Out:**

- New settings screen controls.
- Persistent difficulty preference.
- Player side picker.

**Implementation Notes:**

- Avoid nested modal bugs by controlling the order of `Navigator.pop` and `Navigator.pushNamed`.
- Difficulty option cards should have a clear selected/tap target area.
- Hard mode copy should be honest without sounding punitive.
- Keep the route argument strongly typed with `GameSessionConfig`.

**Tests:**

- Difficulty dialog shows all three difficulties.
- Tapping Easy navigates with easy config.
- Tapping Intermediate navigates with intermediate config.
- Tapping Hard navigates with hard config.
- Cancel/back does not navigate.
- Route parser receives and preserves bot config.

**DoD:**

- [ ] Difficulty dialog exists and follows the app design system.
- [ ] Easy, Intermediate, and Hard launch classic AI sessions.
- [ ] Route arguments use `GameSessionConfig`.
- [ ] Dialog dismissal and navigation are clean.
- [ ] `flutter analyze` is clean.
- [ ] Relevant tests pass.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 8 - Gameplay AI Presentation Polish

**Goal:** Make AI matches feel intentional and understandable without overhauling gameplay UI.

**Scope In:**

- Add minimal AI-aware player labeling.
- Show that O is the bot in AI sessions.
- Communicate bot thinking state if practical.
- Ensure input feedback during bot turn feels blocked, not broken.
- Ensure result dialog still appears correctly for:
  - human win
  - bot win
  - draw
- Confirm pause/restart/back flows during AI sessions.

**Scope Out:**

- New result-dialog layout.
- Score history.
- Bot avatar customization.
- Animating a complex "thinking" sequence.

**Implementation Notes:**

- Prefer small additions to existing player panel/turn indicator APIs.
- Avoid threading bot difficulty through many widgets unless needed.
- If adding labels, keep local multiplayer labels unchanged.
- Reuse existing waiting dots if they fit naturally.
- Check both light visual contrast and tap target sizes.

**Tests:**

- AI session shows bot identity somewhere visible.
- Local multiplayer sessions do not show bot labels.
- Bot win presents existing result dialog.
- Human win presents existing result dialog.
- Draw presents existing draw result dialog.
- Restart from AI match keeps AI config.
- Back/exit flow works during human turn and bot turn.

**DoD:**

- [ ] AI matches clearly identify the bot side.
- [ ] Bot thinking/input-blocked state is understandable.
- [ ] Result dialog behavior is correct for AI sessions.
- [ ] Pause, restart, and exit flows work in AI sessions.
- [ ] Local multiplayer UI remains unchanged.
- [ ] `flutter analyze` is clean.
- [ ] Relevant tests pass.
- [ ] Commit and push phase changes to GitHub.

---

## Phase 9 - Full Regression, Edge Cases, And Release Readiness

**Goal:** Verify AI classic mode is stable, clean, and ready to ship.

**Scope In:**

- Run full test suite.
- Run analyzer.
- Manually test end-to-end flows:
  - Home -> Play vs AI -> Classic -> Easy -> match
  - Home -> Play vs AI -> Classic -> Intermediate -> match
  - Home -> Play vs AI -> Classic -> Hard -> match
  - Home -> Play vs AI -> ShiftTac Coming Soon
  - Restart during AI game
  - Exit during AI game
  - Pause/background during AI game
  - Human win
  - Bot win
  - Draw
- Review code boundaries:
  - no bot logic in widgets
  - no gameplay rules in bot strategy beyond move selection
  - no AI behavior leaking into local multiplayer
- Review copy and visual consistency.

**Scope Out:**

- New feature work.
- Adding ShiftTac AI.
- Adding analytics or persistence.

**Implementation Notes:**

- Fix bugs found during regression in the owning phase's area where possible.
- Keep release fixes small and focused.
- If a significant design gap appears, document it instead of expanding scope late.

**Tests:**

- `flutter analyze`
- `flutter test`
- Optional targeted golden/widget tests if existing infrastructure supports them.
- Manual smoke test on the primary local target.

**DoD:**

- [ ] Full `flutter analyze` is clean.
- [ ] Full `flutter test` passes.
- [ ] Manual AI classic smoke test is complete.
- [ ] No known critical bugs remain.
- [ ] Code boundaries match the target architecture.
- [ ] Home selection flow matches the expected product flow.
- [ ] Commit and push phase changes to GitHub.

---

## Out Of Scope For First AI Classic Release

- ShiftTac AI opponent.
- Online play.
- Difficulty persistence.
- Player side selection.
- Randomized bot personality.
- Bot mistake slider.
- Match history.
- Achievements.
- Analytics.
- Tutorial changes beyond minimal copy if needed.

## Final Acceptance Criteria

- `Play vs AI` opens a mode-selection dialog.
- Mode-selection dialog offers Classic and shows ShiftTac as `Coming Soon`.
- Classic opens a difficulty-selection dialog.
- Easy, Intermediate, and Hard launch classic AI matches.
- Bot moves are legal and applied through `ClassicGameEngine`.
- Easy is random/casual.
- Intermediate follows tactical priority.
- Hard is minimax-based and unbeatable.
- Human input is blocked during bot turns.
- Restart, pause, background, exit, win, loss, and draw flows work.
- Local ShiftTac and local classic modes are not regressed.
- All relevant code follows existing design system and architecture boundaries.
- `flutter analyze` is clean.
- `flutter test` passes.
