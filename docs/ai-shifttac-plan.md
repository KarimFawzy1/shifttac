# AI ShiftTac Mode Implementation Plan

## Purpose

AI ShiftTac mode adds a solo opponent for the app's signature shifting-mark gameplay while preserving the existing clean game architecture.

The bot must not become a second game engine. It should only choose a legal `Position`, then let `ShiftGameEngine` apply the move, remove the oldest mark when needed, update move queues, evaluate wins, and return the next `GameSnapshot`.

This plan assumes classic AI mode already exists and should be reused where appropriate, but not copied blindly. ShiftTac is strategically different because each player only keeps three active marks, older marks expire, the board never draws, and a strong move depends on what will disappear next.

## Expected User Flow

1. User taps the home-screen `Play vs AI` card.
2. A mode-selection dialog opens.
3. The dialog shows:
   - `Classic` as an enabled option.
   - `ShiftTac` as an enabled option.
4. User taps `ShiftTac`.
5. A difficulty-selection dialog opens.
6. User chooses:
   - `Easy`
   - `Intermediate`
   - `Hard`
7. App starts a ShiftTac match against the bot.
8. Human plays as `Player.x` by default.
9. Bot plays as `Player.o` by default.
10. Starting player is selected by the same AI-session policy used by classic AI unless product direction changes before implementation.
11. Bot moves are delayed slightly so the human can read their own move and the resulting shift before the bot responds.
12. During the bot turn, board input is blocked and existing bot-thinking presentation remains visible.
13. Result dialog shows human win or bot win using the existing AI-aware match result flow.

## Current Baseline

The codebase already has the core pieces ShiftTac AI should build on:

- `ShiftGameEngine` owns ShiftTac move validation, FIFO active-mark rotation, turn switching, and win evaluation.
- `GameRules` abstracts ShiftTac and classic rules.
- `GameSnapshot` stores `xMoves`, `oMoves`, current player, turn index, status, winner, and winning line.
- `Move` stores player, position, and turn index.
- `WinChecker` detects all eight 3x3 winning lines.
- `GameCubit` coordinates input lock, bot move delay, timer, pause/resume, restart, and move application through `GameRules`.
- Classic AI already has `BotDifficulty`, `BotOpponentConfig`, bot strategies, a difficulty dialog, AI presentation polish, and cubit scheduling tests.
- `AiModeSelectionDialog` currently presents ShiftTac AI as disabled/coming soon.

## Product Decisions

- ShiftTac AI uses the existing 3x3 ShiftTac rules.
- Human remains `Player.x` by default.
- Bot remains `Player.o` by default.
- The mode-selection dialog should enable ShiftTac once the full flow is implemented.
- The difficulty list should be shared by classic and ShiftTac unless a future design requires mode-specific copy.
- Bot move delay should use the existing app-level delay unless tests or UX reveal it feels wrong for shifting moves.
- ShiftTac AI must be pure Dart and testable without Flutter.
- ShiftTac AI must always choose a legal empty cell from the current snapshot.
- ShiftTac AI must account for active mark expiration.
- ShiftTac AI must never bypass `ShiftGameEngine`.
- ShiftTac mode has no draw state. Tests and presentation should not expect a draw result for ShiftTac AI.
- No persistence, analytics, online play, player-side selection, or bot personality work is included in this plan.

## Design Principles

- Keep gameplay truth in `ShiftGameEngine`.
- Keep bot strategies side-effect free.
- Keep UI responsible only for collecting user intent and passing a `GameSessionConfig`.
- Keep `GameCubit` mode-agnostic where practical.
- Reuse classic AI presentation and lifecycle behavior.
- Prefer small, focused strategy helpers over large widget or cubit conditionals.
- Make easy and intermediate behavior understandable before introducing hard search complexity.
- Tune hard AI with deterministic tests before doing subjective UX tweaks.

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
|       +-- bot_strategy.dart
|       +-- bot_strategy_factory.dart
|       +-- classic_bot_strategy.dart
|       +-- classic_easy_bot_strategy.dart
|       +-- classic_intermediate_bot_strategy.dart
|       +-- classic_hard_bot_strategy.dart
|       +-- classic_bot_helpers.dart
|       +-- shift_bot_strategy.dart
|       +-- shift_easy_bot_strategy.dart
|       +-- shift_intermediate_bot_strategy.dart
|       +-- shift_hard_bot_strategy.dart
|       +-- shift_bot_helpers.dart
|       +-- classic_game_engine.dart
|       +-- shift_game_engine.dart
|       +-- game_rules.dart
+-- presentation/
    +-- state/
    |   +-- game_cubit.dart
    |   +-- game_state.dart
    +-- screens/
    |   +-- gameplay_screen.dart
    +-- widgets/
        +-- game_board.dart
        +-- match_result_dialog.dart
        +-- player_panel.dart
        +-- player_turn_indicator.dart
lib/features/home/
+-- presentation/
    +-- widgets/
        +-- ai_mode_selection_dialog.dart
        +-- ai_difficulty_dialog.dart
```

The exact file names can change during implementation, but the boundary should remain:

- `ShiftGameEngine` decides legality and next state.
- `ShiftBotStrategy` decides which legal position the bot wants.
- `GameCubit` schedules and applies bot moves through the active `GameRules`.
- Home/dialog widgets create the correct `GameSessionConfig`.

## Core Domain Shape

### Generic Bot Strategy

Classic AI currently uses a classic-specific strategy interface. ShiftTac support should introduce a shared interface so `GameCubit` does not care which mode is active.

```dart
abstract interface class BotStrategy {
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  });
}
```

Then classic and ShiftTac strategies can implement this shared interface directly.

If the implementation keeps `ClassicBotStrategy` for compatibility, make it extend `BotStrategy`:

```dart
abstract interface class ClassicBotStrategy implements BotStrategy {}
```

Add the ShiftTac equivalent:

```dart
abstract interface class ShiftBotStrategy implements BotStrategy {}
```

### Strategy Factory

The factory should select by mode and difficulty:

```dart
abstract final class BotStrategyFactory {
  BotStrategyFactory._();

  static BotStrategy forSession({
    required GameMode mode,
    required BotDifficulty difficulty,
    Random? random,
  }) {
    return switch (mode) {
      GameMode.classic => ClassicBotStrategyFactory.forDifficulty(
        difficulty,
        random: random,
      ),
      GameMode.shift => ShiftBotStrategyFactory.forDifficulty(
        difficulty,
        random: random,
      ),
    };
  }
}
```

This lets classic AI keep its existing behavior while ShiftTac gets a separate strategy family.

### Shift AI Session

Add a factory to `GameSessionConfig`:

```dart
factory GameSessionConfig.shiftAi(
  BotDifficulty difficulty, {
  Random? random,
}) {
  final rng = random ?? Random();
  final starter = rng.nextBool() ? Player.x : Player.o;

  return GameSessionConfig(
    mode: GameMode.shift,
    bot: BotOpponentConfig(
      difficulty: difficulty,
      botPlayer: Player.o,
    ),
    startingPlayer: starter,
  );
}
```

The starter policy should match classic AI unless the implementation phase intentionally changes both modes together.

## ShiftTac AI Rules

All ShiftTac bot strategies must obey these rules:

- Only choose from legal currently empty positions.
- Do not choose a position occupied by the bot's oldest mark, even if that mark would be removed during the move, because the current engine validates occupation before FIFO removal.
- Never mutate `GameSnapshot`.
- Simulate moves only through `ShiftGameEngine.instance.attemptMove(...)`.
- Treat `GameStatus.won` as terminal.
- Do not use or expect `GameStatus.draw` in ShiftTac.
- Throw loudly in tests if called when:
  - the snapshot is not playing
  - it is not the bot's turn
  - no legal moves exist
- Production code should avoid calling strategies in those invalid states.

## ShiftTac Helper Behavior

Create `shift_bot_helpers.dart` to keep strategy code readable.

Recommended helpers:

```dart
Set<Position> shiftOccupiedPositions(GameSnapshot snapshot)
List<Position> shiftAvailablePositions(GameSnapshot snapshot)
GameEngineResult simulateShiftMove({
  required GameSnapshot snapshot,
  required Position position,
})
Position? findShiftImmediateWin({
  required GameSnapshot snapshot,
  required Player player,
})
Position? findShiftImmediateThreat({
  required GameSnapshot snapshot,
  required Player threateningPlayer,
})
List<Position> shiftWinningMovesFor({
  required GameSnapshot snapshot,
  required Player player,
})
int countImmediateWinsFor({
  required GameSnapshot snapshot,
  required Player player,
})
bool allowsOpponentImmediateWin({
  required GameSnapshot snapshot,
  required Position candidate,
  required Player botPlayer,
})
Position? firstAvailableInShiftOrder(
  GameSnapshot snapshot,
  List<Position> order,
)
```

Stable move order should be explicit and deterministic:

```dart
const List<Position> shiftStableMoveOrder = [
  Position(row: 1, col: 1),
  Position(row: 0, col: 0),
  Position(row: 0, col: 2),
  Position(row: 2, col: 0),
  Position(row: 2, col: 2),
  Position(row: 0, col: 1),
  Position(row: 1, col: 0),
  Position(row: 1, col: 2),
  Position(row: 2, col: 1),
];
```

This order keeps tests deterministic and gives tactical strategies sensible tie-breaking.

## Difficulty Behavior

### Easy

Easy should choose a random legal empty cell.

Goals:

- Always legal.
- Fast.
- Weak enough for casual players to beat.
- No lookahead.
- Randomized with injectable `Random` for deterministic tests.

Expected algorithm:

1. Assert the snapshot is playing and it is the bot's turn.
2. Compute legal positions from current occupied cells.
3. Throw if no legal positions exist.
4. Return a random legal position.

### Intermediate

Intermediate should be tactical, readable, and beatable.

Expected priority order:

1. Win immediately if the bot has a legal winning move.
2. Block the human's immediate winning move.
3. Avoid moves that allow the human to win immediately on the next turn.
4. Prefer moves that create multiple bot winning threats for a future turn.
5. Prefer moves that keep the bot's active queue useful after rotation.
6. Prefer center, then corners, then sides.
7. Fall back to the first legal stable move.

Important ShiftTac nuance:

- A line is only meaningful if the marks that form it will still exist when the relevant win is evaluated.
- A move that looks strong before FIFO removal may be weak after the bot's oldest mark disappears.
- Blocking must simulate the human's turn with the human as `currentPlayer`, because threats are about what the human could do next.

Intermediate does not need deep minimax. It should be strong enough to punish obvious mistakes while still missing deeper traps.

### Hard

Hard should be the strongest practical ShiftTac bot.

Because ShiftTac has no draw and can cycle indefinitely, hard mode must not use unbounded minimax. Use depth-limited negamax or minimax with alpha-beta pruning and a heuristic evaluation.

Recommended first implementation:

- Use depth-limited negamax with alpha-beta pruning.
- Start with depth 8 plies.
- If performance is excellent, consider depth 10.
- Do not search beyond a fixed depth unless repetition detection is added.
- Use deterministic move ordering.
- Score faster wins higher and faster losses lower.

Terminal scoring:

```text
bot win:    +100000 - depth
human win:  -100000 + depth
```

Heuristic scoring should include:

- Number of bot immediate winning moves.
- Number of human immediate winning moves.
- Bot fork potential.
- Human fork potential.
- Lines with two bot marks and one open cell after rotation.
- Lines with two human marks and one open cell after rotation.
- Center ownership.
- Corner ownership.
- Whether the bot's oldest mark is critical to an active line and about to expire.
- Whether the human's oldest mark is critical and about to expire.
- Mobility, meaning number of legal moves.

Suggested heuristic weights:

```text
bot immediate win threat:       +5000 each
human immediate win threat:     -6000 each
bot fork:                       +1200 each
human fork:                     -1500 each
bot two-in-line:                +250 each
human two-in-line:              -300 each
center ownership:               +60
corner ownership:               +25 each
side ownership:                 +10 each
bot critical oldest penalty:    -200
human critical oldest bonus:    +150
mobility:                       +5 per legal move
```

These numbers are starting points. Tests should verify behavior, not exact score values.

Hard mode acceptance should focus on:

- Never chooses an illegal position.
- Takes immediate wins.
- Blocks immediate losses.
- Avoids simple traps that intermediate can miss.
- Finds a forced win within the selected depth.
- Responds quickly enough for gameplay.

## Performance Guardrails

ShiftTac search is small but can still become expensive if helper functions allocate heavily.

Guardrails:

- Search only legal positions.
- Apply alpha-beta pruning.
- Order moves by tactical priority before search.
- Keep depth fixed.
- Avoid async work inside strategies.
- Avoid logging inside recursive search.
- Add tests or benchmarks for worst-case response time if hard AI feels slow.

Target:

- Easy and intermediate should be effectively instant.
- Hard should complete well below the bot move delay on normal devices.
- Strategy computation should happen synchronously when the bot timer fires, as classic AI currently does.

## UI Flow Changes

### Mode Selection Dialog

Change ShiftTac option from disabled to enabled.

Current copy can become:

- Title: `ShiftTac`
- Subtitle: `Shifting marks against the bot.`
- Badge: none, or optional `New` if desired.

The dialog needs to pass selected mode to the difficulty dialog.

Recommended API:

```dart
AiDifficultyDialog.show(
  context,
  mode: GameMode.shift,
)
```

Classic selection should call:

```dart
AiDifficultyDialog.show(
  context,
  mode: GameMode.classic,
)
```

### Difficulty Dialog

The difficulty dialog should create a session based on mode:

```dart
final session = switch (mode) {
  GameMode.classic => GameSessionConfig.classicAi(difficulty),
  GameMode.shift => GameSessionConfig.shiftAi(difficulty),
};
```

Copy can remain generic:

- Easy: `Random casual opponent.`
- Intermediate: `Tactical bot that can win and block.`
- Hard: `Deep strategy for serious games.`

If mode-specific helper copy is needed, keep it inside the dialog and avoid leaking UI copy into domain models.

## Cubit Changes

`GameCubit` should hold a generic `BotStrategy?`, not `ClassicBotStrategy?`.

Expected changes:

- Replace `_botStrategy` type with `BotStrategy?`.
- Replace `ClassicBotStrategyFactory.forDifficulty(...)` usage with `BotStrategyFactory.forSession(...)`.
- Remove the assert that bots are only supported in classic mode.
- Keep the guard that bot moves only happen when:
  - a bot config exists
  - a strategy exists
  - match is not paused
  - snapshot status is playing
  - current player is the bot
- Keep input lock and bot-thinking behavior unchanged.
- Keep restart behavior consistent with AI sessions.

Test-only constructors should accept `BotStrategy?` so both classic and ShiftTac tests can inject fake strategies.

## Testing Strategy

### Domain Tests

Add tests for each ShiftTac strategy:

- `shift_easy_bot_strategy_test.dart`
- `shift_intermediate_bot_strategy_test.dart`
- `shift_hard_bot_strategy_test.dart`
- `shift_bot_helpers_test.dart` if helpers become non-trivial
- `bot_strategy_factory_test.dart`

Coverage goals:

- Legal move generation excludes occupied cells.
- Easy chooses only legal moves.
- Easy uses injectable randomness.
- Intermediate wins immediately.
- Intermediate blocks immediate human win.
- Intermediate avoids a move that allows immediate human win.
- Intermediate prefers stable strategic order when no tactic exists.
- Hard wins immediately.
- Hard blocks immediate human win.
- Hard finds a deeper forced win within configured depth.
- Hard avoids a deeper forced loss when a safer move exists.
- Hard returns deterministic choices for deterministic snapshots.
- Strategies throw on invalid calls.

### Cubit Tests

Extend AI cubit coverage:

- ShiftTac AI session fixes human/bot players correctly.
- ShiftTac AI can start on bot turn and schedule opening move.
- Human move schedules ShiftTac bot response.
- Bot response uses `ShiftGameEngine` and can remove oldest bot mark.
- Human input is rejected during bot turn.
- Bot move is canceled while paused.
- Bot move resumes after pause.
- Restart preserves ShiftTac AI config and randomizes starter according to existing policy.
- No bot move is scheduled after a terminal ShiftTac win.

### UI Tests

Update and add widget tests:

- Mode dialog shows ShiftTac enabled.
- Tapping ShiftTac opens difficulty dialog.
- Difficulty selection launches `GameSessionConfig.shiftAi(...)`.
- Classic AI flow still launches classic session.
- Gameplay screen shows AI labels in ShiftTac AI.
- Bot thinking indicator appears during ShiftTac AI bot turn.
- Result dialog shows human win.
- Result dialog shows bot win.
- Local ShiftTac multiplayer remains unchanged.

### Regression Tests

Run:

```text
flutter analyze
flutter test
```

Manual smoke tests:

- Home -> Play vs AI -> ShiftTac -> Easy -> play until win.
- Home -> Play vs AI -> ShiftTac -> Intermediate -> verify win/block behavior.
- Home -> Play vs AI -> ShiftTac -> Hard -> verify stronger play.
- Restart during ShiftTac AI game.
- Exit during ShiftTac AI game.
- Pause/background during bot turn.
- Bot starts first.
- Human starts first.
- Human win result.
- Bot win result.

## Phase 1 - Bot Architecture Generalization

**Goal:** Make bot scheduling mode-agnostic while preserving classic AI behavior.

**Scope In:**

- Add shared `BotStrategy` interface.
- Make classic strategies compatible with the shared interface.
- Add `BotStrategyFactory` that routes by `GameMode` and `BotDifficulty`.
- Update `GameCubit` to depend on `BotStrategy`.
- Keep existing classic AI behavior unchanged.
- Keep all public UI flows unchanged.

**Scope Out:**

- ShiftTac AI strategies.
- Enabling ShiftTac in the mode dialog.
- New hard ShiftTac logic.

**Implementation Notes:**

- Keep `ClassicBotStrategyFactory` if it keeps the diff smaller.
- Prefer adapting existing classic strategy files over moving everything at once.
- Update test-only cubit injection types from `ClassicBotStrategy?` to `BotStrategy?`.
- The factory should be the only place that decides which strategy family belongs to which mode.

**Tests:**

- Existing classic AI strategy tests still pass.
- Existing `game_cubit_ai_test.dart` still passes.
- Add factory tests for classic routing if useful.
- `flutter analyze`.

**DoD:**

- [ ] `GameCubit` uses a generic bot strategy type.
- [ ] Classic AI easy/intermediate/hard behavior is unchanged.
- [ ] Bot strategy selection is centralized.
- [ ] Existing classic AI tests pass.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 2 - ShiftTac Session Model

**Goal:** Add a clean ShiftTac AI session configuration without enabling the UI path yet.

**Scope In:**

- Add `GameSessionConfig.shiftAi(...)`.
- Ensure `BotOpponentConfig` works for ShiftTac without mode-specific fields.
- Update route/session tests for ShiftTac AI config.
- Allow `GameCubit.fromSession(...)` to construct a ShiftTac AI cubit.
- Remove or update classic-only bot assertions.

**Scope Out:**

- Real ShiftTac AI strategy behavior beyond temporary wiring needed for tests.
- Mode dialog changes.
- Difficulty dialog navigation changes.

**Implementation Notes:**

- Keep human as `Player.x` and bot as `Player.o`.
- Match classic AI starter policy unless a product decision changes it.
- Any temporary strategy used in tests should be injected, not shipped as production ShiftTac behavior.

**Tests:**

- `GameSessionConfig.shiftAi(...)` sets `mode == GameMode.shift`.
- `GameSessionConfig.shiftAi(...)` sets bot difficulty.
- `GameSessionConfig.shiftAi(...)` sets bot player to `Player.o`.
- `GameCubit.fromSession(...)` accepts ShiftTac AI when a valid strategy is available.

**DoD:**

- [ ] ShiftTac AI session config exists.
- [ ] ShiftTac AI session config is covered by tests.
- [ ] Cubit no longer rejects all non-classic AI sessions.
- [ ] Classic AI session config remains unchanged.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 3 - ShiftTac Bot Helpers

**Goal:** Build the pure helper layer required by all ShiftTac difficulty levels.

**Scope In:**

- Add `shift_bot_helpers.dart`.
- Implement occupied-position detection for ShiftTac snapshots.
- Implement legal-position generation.
- Implement stable move ordering.
- Implement move simulation through `ShiftGameEngine`.
- Implement immediate win and immediate threat helpers.
- Implement simple line/threat counting helpers if needed for intermediate.

**Scope Out:**

- Full strategy classes.
- UI wiring.
- Hard minimax search.

**Implementation Notes:**

- Do not duplicate ShiftTac rule mutation manually.
- All simulations must go through `ShiftGameEngine.instance.attemptMove(...)`.
- Legal move generation must match current engine behavior.
- Helpers should be deterministic.
- Prefer small named helpers with focused tests.

**Tests:**

- Occupied positions include both players' active moves.
- Available positions exclude occupied cells.
- Simulated move removes the mover's oldest mark when they already have three active marks.
- Immediate win detects a win after FIFO removal and placement.
- Immediate threat detects the opponent's next-turn win.
- Stable ordering is deterministic.

**DoD:**

- [ ] ShiftTac helper functions exist and are pure.
- [ ] Helpers use `ShiftGameEngine` for simulated moves.
- [ ] Helper tests cover FIFO-specific behavior.
- [ ] Helper tests cover immediate wins and threats.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 4 - Easy ShiftTac Bot

**Goal:** Add a legal, random, fully testable easy ShiftTac opponent.

**Scope In:**

- Add `ShiftBotStrategy` interface if not already added.
- Add `ShiftEasyBotStrategy`.
- Add `ShiftBotStrategyFactory.forDifficulty(...)` with easy support.
- Route `BotDifficulty.easy` for `GameMode.shift`.
- Add deterministic tests with injected `Random`.

**Scope Out:**

- Intermediate and hard behavior.
- UI enabling.
- Presentation changes.

**Implementation Notes:**

- Easy should be intentionally simple.
- Throw if called in a non-playing state or non-bot turn.
- Throw if no legal moves exist, even though normal ShiftTac play should avoid that state.
- Use stable helper output before random selection so tests remain predictable with seeded randomness.

**Tests:**

- Easy chooses a legal empty cell.
- Easy never chooses an occupied cell.
- Easy works when the bot already has three active marks.
- Easy is deterministic with seeded random.
- Easy throws when called outside bot turn.

**DoD:**

- [ ] Easy ShiftTac strategy exists.
- [ ] Shift strategy factory can return easy strategy.
- [ ] Easy strategy is covered by focused tests.
- [ ] Classic easy strategy remains unchanged.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 5 - ShiftTac AI Cubit Flow

**Goal:** Prove a ShiftTac AI match can run through `GameCubit` using the real easy bot strategy.

**Scope In:**

- Wire `BotStrategyFactory` into `GameCubit.fromSession(...)` for ShiftTac.
- Add cubit tests for ShiftTac AI scheduling.
- Confirm bot move delay, input lock, pause/resume, restart, and terminal behavior.
- Confirm bot moves are applied by `ShiftGameEngine`.

**Scope Out:**

- UI mode selection.
- Intermediate and hard strategy behavior.
- Visual redesign.

**Implementation Notes:**

- Keep existing `isAiSession`, `humanPlayer`, `botPlayer`, and `isBotTurn` semantics.
- Avoid adding mode-specific branches unless the rules truly differ.
- ShiftTac terminal state only includes wins.
- Test a bot move that causes FIFO removal to prove the engine path is used.

**Tests:**

- Bot opening move fires when bot starts.
- Human move schedules bot response.
- Bot response can remove oldest bot mark.
- Human taps are rejected during bot turn.
- Pause cancels pending bot move.
- Resume reschedules pending bot move.
- Restart keeps AI config.
- No move is scheduled after a win.

**DoD:**

- [ ] ShiftTac AI can run through `GameCubit` in tests.
- [ ] Bot move timing and input lock behavior match classic AI expectations.
- [ ] Pause/resume/restart behavior is covered.
- [ ] FIFO removal through bot move is covered.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 6 - Intermediate ShiftTac Bot

**Goal:** Add a tactical ShiftTac bot that can win, block, avoid obvious losses, and use sensible positional choices.

**Scope In:**

- Add `ShiftIntermediateBotStrategy`.
- Route `BotDifficulty.intermediate` for `GameMode.shift`.
- Implement immediate win detection.
- Implement immediate block detection.
- Implement next-turn danger avoidance.
- Implement simple fork/threat preference if helper complexity stays reasonable.
- Use stable center/corner/side fallback ordering.

**Scope Out:**

- Deep minimax.
- Performance tuning for hard mode.
- UI changes.

**Implementation Notes:**

- Keep the algorithm readable and explainable.
- Prefer correct win/block behavior over clever heuristics.
- Do not make intermediate too close to hard.
- Any "avoid losing move" logic should be simulation-based.
- Be careful when creating opponent-turn snapshots for threat detection.

**Tests:**

- Takes immediate winning move.
- Blocks human immediate winning move.
- Avoids a move that gives the human an immediate win.
- Prefers a move that creates stronger next-turn threats.
- Falls back to center/corners/sides in stable order.
- Handles positions where oldest marks disappear.

**DoD:**

- [ ] Intermediate ShiftTac strategy exists.
- [ ] Intermediate strategy is routed by factory.
- [ ] Tactical priority behavior is covered by tests.
- [ ] FIFO-specific tactical cases are covered by tests.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 7 - Hard ShiftTac Bot Search

**Goal:** Add a strong ShiftTac bot using bounded search and heuristic evaluation.

**Scope In:**

- Add `ShiftHardBotStrategy`.
- Route `BotDifficulty.hard` for `GameMode.shift`.
- Implement depth-limited minimax or negamax.
- Add alpha-beta pruning.
- Add deterministic move ordering.
- Add terminal and heuristic scoring.
- Add tests for deeper tactical behavior.

**Scope Out:**

- Online-strength AI guarantees.
- Machine learning.
- Persistent transposition tables unless needed.
- UI changes.

**Implementation Notes:**

- Prefer negamax if it makes player perspective cleaner.
- Keep search depth as a named constant.
- Do not use unbounded recursion.
- Avoid relying on `GameStatus.draw`.
- Consider a local visited-state guard only if tests reveal cycles inside the selected depth cause poor choices.
- Keep heuristic weights private constants so they can be tuned later.
- Tie-break deterministically using stable move order.

**Tests:**

- Hard takes immediate win.
- Hard blocks immediate loss.
- Hard finds a forced win that intermediate misses.
- Hard avoids a forced loss when a safe move exists.
- Hard remains deterministic.
- Hard handles FIFO removal during search.
- Hard never returns occupied cells.

**DoD:**

- [ ] Hard ShiftTac strategy exists.
- [ ] Hard strategy uses bounded search.
- [ ] Hard strategy is routed by factory.
- [ ] Hard strategy is covered by tactical and FIFO-specific tests.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 8 - AI Mode Selection UI

**Goal:** Enable the user-facing ShiftTac AI selection flow.

**Scope In:**

- Enable ShiftTac option in `AiModeSelectionDialog`.
- Pass selected `GameMode` into `AiDifficultyDialog`.
- Launch `GameSessionConfig.shiftAi(...)` for ShiftTac difficulty selections.
- Preserve classic AI navigation behavior.
- Update dialog copy so ShiftTac no longer says coming soon.

**Scope Out:**

- New dialog layout.
- New custom difficulty screen.
- Player side selection.

**Implementation Notes:**

- Keep dialog visuals consistent with the current design system.
- Avoid duplicating difficulty dialog code.
- Keep audio feedback consistent with classic selection.
- Make mode explicit in tests rather than relying only on visible text.

**Tests:**

- Mode dialog shows ShiftTac enabled.
- Tapping ShiftTac opens difficulty dialog.
- Easy launches ShiftTac AI session.
- Intermediate launches ShiftTac AI session.
- Hard launches ShiftTac AI session.
- Classic path still launches classic AI session.
- Cancel/back behavior remains clean.

**DoD:**

- [ ] ShiftTac AI is selectable from `Play vs AI`.
- [ ] Difficulty dialog supports both AI modes.
- [ ] Classic AI flow is not regressed.
- [ ] UI tests cover ShiftTac mode selection.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 9 - Gameplay Presentation Polish

**Goal:** Make ShiftTac AI feel understandable during real play without adding a new visual system.

**Scope In:**

- Verify existing AI labels work for ShiftTac AI.
- Verify bot-thinking indicator works during ShiftTac AI turns.
- Verify board blocks input during bot turn.
- Verify result dialog copy and audio behavior for human win and bot win.
- Review oldest-mark fading during bot and human turns.
- Adjust copy only if it is classic-specific.

**Scope Out:**

- New bot avatars.
- New result dialog design.
- Score history.
- Tutorial overhaul.

**Implementation Notes:**

- Most presentation should already be mode-agnostic through `GameCubit.isAiSession`.
- Avoid threading difficulty through widgets unless the UI needs it.
- ShiftTac has no draw result, so avoid adding draw-specific ShiftTac UI.
- Oldest-mark preview is core to ShiftTac and should remain visible in AI games.

**Tests:**

- ShiftTac AI gameplay shows `You` and `AI` labels.
- Local ShiftTac multiplayer does not show AI labels.
- Bot turn shows thinking state.
- Board rejects human taps during bot turn.
- Human win shows existing AI result flow.
- Bot win shows existing AI result flow.
- Restart preserves ShiftTac AI session.
- Exit works during human turn and bot turn.

**DoD:**

- [ ] ShiftTac AI gameplay clearly identifies the bot side.
- [ ] Bot-thinking/input-blocked state is understandable.
- [ ] Result dialog behavior is correct for ShiftTac AI.
- [ ] Local multiplayer presentation remains unchanged.
- [ ] `flutter analyze` is clean.
- [ ] Commit and push phase changes to GitHub.

## Phase 10 - Full Regression And Release Readiness

**Goal:** Verify ShiftTac AI is stable, clean, and ready to ship.

**Scope In:**

- Run full analyzer.
- Run full test suite.
- Manually test all ShiftTac AI difficulties.
- Manually retest classic AI flow.
- Review code boundaries.
- Review performance of hard strategy.
- Review copy and visual consistency.
- Fix small bugs found during regression.

**Scope Out:**

- New features.
- Major redesign.
- Difficulty persistence.
- Player side selection.

**Implementation Notes:**

- Keep release fixes small and targeted.
- If hard AI tuning needs substantial work, document follow-up tuning separately instead of expanding release scope late.
- Confirm no strategy logic leaked into widgets.
- Confirm no UI code directly mutates game snapshots.
- Confirm generated build artifacts remain out of commits.

**Tests:**

- `flutter analyze`
- `flutter test`
- Manual smoke test on primary local target.
- Optional targeted tests for any release fixes.

**Manual Checklist:**

- Home -> Play vs AI -> ShiftTac -> Easy -> match completes.
- Home -> Play vs AI -> ShiftTac -> Intermediate -> match completes.
- Home -> Play vs AI -> ShiftTac -> Hard -> match completes.
- Home -> Play vs AI -> Classic -> Easy still works.
- Home -> Play vs AI -> Classic -> Intermediate still works.
- Home -> Play vs AI -> Classic -> Hard still works.
- Bot starts first in ShiftTac AI.
- Human starts first in ShiftTac AI.
- Restart during ShiftTac AI.
- Exit during ShiftTac AI.
- Pause/background during ShiftTac AI.
- Human win.
- Bot win.
- Oldest-mark fade remains accurate.

**DoD:**

- [ ] Full `flutter analyze` is clean.
- [ ] Full `flutter test` passes.
- [ ] Manual ShiftTac AI smoke test is complete.
- [ ] Classic AI smoke test is complete.
- [ ] No known critical bugs remain.
- [ ] Code boundaries match the target architecture.
- [ ] Commit and push phase changes to GitHub.

## Out Of Scope For First ShiftTac AI Release

- Online play.
- Player side selection.
- Difficulty persistence.
- Bot personality profiles.
- Bot mistake slider.
- Match history.
- Achievements.
- Analytics.
- Replay mode.
- Tutorial rewrite.
- Custom bot avatars.
- ML-based AI.

## Final Acceptance Criteria

- `Play vs AI` allows choosing `ShiftTac`.
- ShiftTac difficulty selection supports easy, intermediate, and hard.
- ShiftTac AI sessions launch with `GameMode.shift`.
- Human and bot labels are clear.
- Bot turns are delayed and visibly blocked from human input.
- Bot moves are always legal.
- Bot moves are applied only through `ShiftGameEngine`.
- Easy is random and beatable.
- Intermediate wins, blocks, and avoids obvious losses.
- Hard uses bounded search and plays materially stronger than intermediate.
- ShiftTac FIFO behavior is respected by all strategies.
- ShiftTac AI has no draw assumptions.
- Local ShiftTac multiplayer remains unchanged.
- Classic AI remains unchanged.
- `flutter analyze` is clean.
- `flutter test` passes.
