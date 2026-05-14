# Project Structure Hierarchy

```txt
shifttac/
│
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   └── game_constants.dart
│   │   │
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_text_styles.dart
│   │   │   ├── app_theme.dart
│   │   │   └── app_spacing.dart
│   │   │
│   │   ├── routing/
│   │   │   ├── app_router.dart
│   │   │   └── app_routes.dart
│   │   │
│   │   ├── widgets/
│   │   │   ├── primary_button.dart
│   │   │   ├── secondary_button.dart
│   │   │   └── app_scaffold.dart
│   │   │
│   │   └── utils/
│   │       └── extensions.dart
│   │
│   ├── features/
│   │   ├── game/
│   │   │   ├── domain/
│   │   │   │   ├── models/
│   │   │   │   │   ├── player.dart
│   │   │   │   │   ├── position.dart
│   │   │   │   │   ├── cell.dart
│   │   │   │   │   └── game_status.dart
│   │   │   │   │
│   │   │   │   └── logic/
│   │   │   │       ├── game_engine.dart
│   │   │   │       └── win_checker.dart
│   │   │   │
│   │   │   └── presentation/
│   │   │       ├── state/
│   │   │       │   ├── game_cubit.dart
│   │   │       │   └── game_state.dart
│   │   │       │
│   │   │       ├── screens/
│   │   │       │   └── gameplay_screen.dart
│   │   │       │
│   │   │       └── widgets/
│   │   │           ├── game_board.dart
│   │   │           ├── board_cell.dart
│   │   │           ├── player_turn_indicator.dart
│   │   │           ├── player_panel.dart
│   │   │           ├── win_dialog.dart
│   │   │           └── pause_bottom_sheet.dart
│   │   │
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── home_screen.dart
│   │   │       └── widgets/
│   │   │           └── home_action_card.dart
│   │   │
│   │   ├── onboarding/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── onboarding_screen.dart
│   │   │       └── widgets/
│   │   │           ├── onboarding_page.dart
│   │   │           └── mini_board_preview.dart
│   │   │
│   │   ├── how_to_play/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── how_to_play_screen.dart
│   │   │       └── widgets/
│   │   │           └── how_to_play_step.dart
│   │   │
│   │   ├── settings/
│   │   │   └── presentation/
│   │   │       ├── screens/
│   │   │       │   └── settings_screen.dart
│   │   │       └── widgets/
│   │   │           └── settings_tile.dart
│   │   │
│   │   └── splash/
│   │       └── presentation/
│   │           └── screens/
│   │               └── splash_screen.dart
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── app_icon_button.dart
│       │   └── screen_header.dart
│       │
│       └── animations/
│           ├── app_motion.dart
│           └── fade_scale_transition.dart
│
├── assets/
│   ├── images/
│   ├── icons/
│   ├── sounds/
│   └── fonts/
│
├── test/
│   ├── game_engine_test.dart
│   ├── win_checker_test.dart
│   └── game_cubit_test.dart
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
game/domain/logic/
```

should contain the real brain of the game.

The UI should only ask:

```txt
player tapped cell
restart game
show win dialog
```

It should not decide:

```txt
which mark disappears
who wins
whose turn is next
```

## Recommended first implementation order

```txt
1. core/theme
2. game/domain/models
3. win_checker.dart
4. game_engine.dart
5. game_state.dart
6. game_cubit.dart
7. gameplay_screen.dart
8. game_board.dart
9. board_cell.dart
10. win_dialog.dart
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
