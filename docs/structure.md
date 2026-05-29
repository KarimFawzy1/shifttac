# Project Structure Hierarchy

```txt
shifttac/
│
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/
│   │   ├── audio/
│   │   │   └── app_audio.dart
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── game_constants.dart
│   │   │   └── image_constants.dart
│   │   ├── launch/
│   │   │   └── app_launch_gate.dart
│   │   ├── routing/
│   │   │   ├── app_router.dart
│   │   │   ├── app_routes.dart
│   │   │   └── main_shell_tab.dart
│   │   ├── settings/
│   │   ├── theme/
│   │   └── widgets/
│   │
│   ├── features/
│   │   ├── game/
│   │   │   ├── domain/
│   │   │   │   ├── models/
│   │   │   │   │   ├── game_mode.dart
│   │   │   │   │   ├── game_status.dart
│   │   │   │   │   ├── player.dart
│   │   │   │   │   ├── position.dart
│   │   │   │   │   ├── move.dart
│   │   │   │   │   └── cell.dart
│   │   │   │   └── logic/
│   │   │   │       ├── game_rules.dart
│   │   │   │       ├── shift_game_engine.dart
│   │   │   │       ├── classic_game_engine.dart
│   │   │   │       ├── game_snapshot.dart
│   │   │   │       ├── game_engine_result.dart
│   │   │   │       └── win_checker.dart
│   │   │   └── presentation/
│   │   │       ├── state/
│   │   │       │   ├── game_cubit.dart
│   │   │       │   └── game_state.dart
│   │   │       ├── screens/
│   │   │       │   └── gameplay_screen.dart
│   │   │       └── widgets/
│   │   │           ├── game_board.dart
│   │   │           ├── board_cell.dart
│   │   │           ├── board_appearance_mapper.dart
│   │   │           ├── match_presentation.dart
│   │   │           ├── match_result.dart
│   │   │           ├── match_result_dialog.dart
│   │   │           ├── player_turn_indicator.dart
│   │   │           ├── player_panel.dart
│   │   │           ├── pause_bottom_sheet.dart
│   │   │           └── exit_game_dialog.dart
│   │   │
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   ├── home_screen.dart
│   │   │       │   └── main_shell_screen.dart
│   │   │       └── widgets/
│   │   │           ├── home_action_card.dart
│   │   │           └── main_nav_bar.dart
│   │   │
│   │   ├── how_to_play/
│   │   ├── onboarding/
│   │   ├── settings/
│   │   └── splash/
│   │
│   └── shared/
│
├── docs/
│   ├── rules.md              ← mode comparison (entry point)
│   ├── shift-rules.md        ← ShiftTac mode spec
│   ├── classic-rules.md      ← Classic mode spec
│   ├── classic-mode-plan.md  ← implementation phases
│   ├── design.md
│   └── structure.md
│
├── test/
│   ├── shift_game_engine_test.dart
│   ├── classic_game_engine_test.dart
│   ├── game_cubit_test.dart
│   ├── game_rules_test.dart
│   ├── board_appearance_mapper_test.dart
│   ├── match_presentation_test.dart
│   ├── match_result_dialog_test.dart
│   ├── match_result_test.dart
│   ├── app_router_test.dart
│   ├── home_screen_test.dart
│   └── win_checker_test.dart
│
├── pubspec.yaml
└── README.md
```

## Why this structure is the best fit

The app is split by **features**, not by generic folders only. This keeps the project easy to grow later when you add:

```txt
AI mode
score history
themes
sound settings
online multiplayer
leaderboards
```

But for now, it avoids unnecessary layers like repositories, use cases, data sources, and dependency injection.

## Most important rule

Keep the **game logic outside the UI**.

```txt
features/game/domain/logic/
```

should contain the real brain of the game (`GameRules` implementations for ShiftTac and Classic).

The UI should only ask:

```txt
player tapped cell
restart game
show match result dialog
```

It should not decide:

```txt
which mark disappears
who wins
whose turn is next
whether the match is a draw
```

## Recommended first implementation order

```txt
1. core/theme
2. game/domain/models
3. win_checker.dart
4. shift_game_engine.dart / classic_game_engine.dart
5. game_state.dart
6. game_cubit.dart
7. gameplay_screen.dart
8. game_board.dart
9. board_cell.dart
10. match_result_dialog.dart
```

## Keep these folders empty for now

Do not add them yet:

```txt
data/
repositories/
usecases/
services/
dependency_injection/
```

Add them only when there is a real need.

For your current version, this is the cleanest structure:

> Feature-based + simple domain logic + Cubit state management.
