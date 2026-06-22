# Tiki-Taka Feature Module

Dedicated Flutter feature for **Tiki-Taka-Toe — 1 Player Mode**. This module is separate from Classic and Shift tic-tac-toe.

## Why a separate feature?

`GameplayScreen` and `GameCubit` are built for Classic/Shift:

- X/O marks and turn switching
- Move counter and player turn indicator
- AI session config (`GameSessionConfig`, bot strategies)
- Pause/result flows tied to two-player or AI matches

Tiki-Taka 1P uses different state: hearts, timer, player search, DB validation, and football attribute headers. Forcing it through `GameCubit` would leak turn-system and X/O concepts.

**Do not route Tiki-Taka through `GameCubit` or `GameplayScreen`.**

## Directory layout

```text
lib/features/tiki_taka/
├── data/
│   ├── local/          # SQLite access (G5/T1), DAOs (T2+)
│   │   └── daos/
│   └── models/         # Typed DB rows (T2+)
├── domain/
│   ├── logic/          # Match engine, win/completion checks (T3+)
│   └── services/       # Asset manifest, attribute icons (T5+)
└── presentation/
    ├── screens/        # Tiki-Taka gameplay screen (T6+)
    ├── state/          # Cubit/bloc for 1P match (T4+)
    └── widgets/        # Board, hearts, timer, search dialog (T6–T8+)
```

## Reuse from shared / Classic modules

| Piece | Location | Use in Tiki-Taka |
| --- | --- | --- |
| Win line detection | `lib/features/game/domain/logic/win_checker.dart` | 3-in-a-row after cells filled |
| App theme / constants | `lib/core/` | Colors, typography, spacing |
| Routing patterns | `lib/core/routing/` | `AppRoutes.tikiTaka` + `TikiTakaEntryScreen` (Phase T9) |
| Audio | `lib/core/audio/` | SFX for correct/wrong guess |
| Main shell / scaffold | `lib/features/home/` | Entry from home in Phase T9 |
| Dialog patterns | Shared widgets | Result / exit dialogs (adapted copy) |

## Do not reuse (Classic/Shift leakage)

| Piece | Reason |
| --- | --- |
| `GameCubit` / `GameState` | Turn-based X/O engine |
| `GameplayScreen` | X/O board, turn UI, AI hooks |
| `PlayerTurnIndicator` | No turns in 1P mode |
| Move counter UI | Not part of Tiki-Taka rules |
| `GameSessionConfig` / bot factories | No AI in v1 |
| `BoardCell` X/O rendering | Tiki-Taka cells show player names |

## Implementation phases

See [docs/dataset-plan2.md](../../../docs/dataset-plan2.md):

- **G5** — DB contract in `data/local/`
- **T1** — `DefaultTikiTakaDatabase` (copy-on-first-use, read-only open)
- **T2** — `BoardDao`, `PlayerSearchDao`, `ValidationDao` + models
- **T3** — `TikiTakaGameEngine`, `AnswerValidator`, domain models (`TikiGameState`, hearts, win/completion)
- **T4** — `TikiTakaCubit` (board load, search, validation, timer, hearts, lifecycle)
- **T5** — `TikiAttributeHeader`, `TikiAttributeIcon`, `TikiBoardFrame`, `TikiAttributeAssetManifest` (G2 manifest SVG headers, position text, fallbacks, semantics)
- **T6** — `TikiTakaGameplayScreen`, `TikiTakaBoard`, `TikiTakaCell`, `TikiTakaHud` (SQLite board skeleton, headers, hearts, timer)
- **T7** — `PlayerSearchDialog`, `PlayerSearchResultTile` (DB search, attribute context, selection-only answers, invalid feedback)
- **T8** — `TikiTakaFirstWinDialog`, `TikiTakaCompletionDialog`, `TikiTakaLostDialog`, `TikiTakaPauseSheet` (outcome flows, pause, restart, exit)
- **T9** — `AppRoutes.tikiTaka`, `TikiTakaEntryScreen`, home card (routing and home entry; dedicated route, not `GameMode`)
- **T10** — `HowToPlayTikiTakaSection`, static rules copy in How to Play tab
- **T11** — integration/regression pack: DAO + engine/cubit game flows, widget regression (`tiki_taka_widget_test_support.dart`, HUD/board/header tests), D12 ETL validation, T6+ test hygiene audit
- **T12** — release readiness: size/latency budgets, controlled error/retry UI, corrupt DB recovery, offline release smoke, `tool/release/check_tiki_taka_release_budgets.py`
- **Runtime boards** — `TikiRandomBoardGenerator` composes fresh 3×3 headers on every entry/restart using `attribute_pair_stats` (cross-type plus **club×club** and **league×league** same-type pairs). At most one nation and one league per header; nation on at most one axis. Templates include full **3 clubs × 3 clubs** boards, **league×league** cells, and club-heavy mixed headers.

## Test layout (T11)

| Area | Location |
| --- | --- |
| DB smoke | `test/features/tiki_taka/release/tiki_taka_database_smoke_test.dart` |
| DAO integration | `test/features/tiki_taka/data/local/*_dao_test.dart` |
| Engine + validator flows | `test/features/tiki_taka/domain/logic/tiki_taka_game_engine_test.dart` |
| Cubit integration flows | `test/features/tiki_taka/presentation/state/tiki_taka_cubit_test.dart` |
| Widget regression | `test/features/tiki_taka/presentation/widgets/`, `screens/tiki_taka_gameplay_screen_test.dart` |
| Shared test helpers | `test/features/tiki_taka/support/` |
| Release performance + smoke | `test/features/tiki_taka/release/` |

## Search and player avatars (runtime)

### Search gate

- Minimum query length: **3** trimmed characters (`kMinPlayerSearchQueryLength` in `search_query_normalizer.dart`)
- Enforced in `TikiTakaCubit.searchPlayers` and `PlayerSearchDialog`
- Debounce: **300 ms**
- SQL order: `search_rank DESC`, prefix match, then `display_name`

Regression tests: `test/features/tiki_taka/data/legendary_players_smoke_test.dart`, `player_search_dialog_test.dart`.

### Avatars (cosmetic, online optional)

Gameplay is fully offline. Player face images are loaded at runtime from HTTPS Commons URLs in `players.image_url`:

- `PlayerAvatar` + `PlayerAvatarImageQueue` — throttled fetch (max 5 concurrent, 200 ms stagger)
- Shows `CircularProgressIndicator` while loading; falls back to placeholder or `PlayerDiagonalName` on failure
- Does **not** affect search, validation, or board placement

ETL resolves images via Wikidata (including legendary QID fast-path). See [player-image-plan.md](../../../docs/player-image-plan.md).

## Release checks (T12)

```bash
python tool/release/check_tiki_taka_release_budgets.py
powershell -File tool/release/run_tiki_taka_release_checks.ps1
flutter build apk --release
```

Current bundled asset budgets: SQLite **~19.2 MB** / 20 MB cap, attribute SVGs **84 files · 3.0 MB** / 8 MB cap. Gameplay uses no live APIs; avatar images may fetch Commons URLs when online.

Home navigation and routes are added in **Phase T9** via [AppRoutes.tikiTaka](../../../core/routing/app_routes.dart).

## Rules and data contracts

| Doc | Role |
| --- | --- |
| [tiki-taka-toe-rules.md](../../../docs/tiki-taka-toe-rules.md) | Gameplay spec (Section 30, Appendix A) |
| [tiki-taka-database-contract.md](../../../docs/tiki-taka-database-contract.md) | SQLite open strategy |
| [dataset-plan.md](../../../docs/dataset-plan.md) | ETL schema and tables |
| [legendary-players/legendary_players_plan.md](../../../legendary-players/legendary_players_plan.md) | Legendary player ETL (complete) |
