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
| Routing patterns | `lib/core/routing/` | New route in Phase T9 only |
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
- **T6–T9** — UI, routing, home entry

Home navigation and routes are **not** added until Phase T9.

## Rules and data contracts

| Doc | Role |
| --- | --- |
| [tiki-taka-toe-rules.md](../../../docs/tiki-taka-toe-rules.md) | Gameplay spec (Section 30, Appendix A) |
| [tiki-taka-database-contract.md](../../../docs/tiki-taka-database-contract.md) | SQLite open strategy |
| [dataset-plan.md](../../../docs/dataset-plan.md) | ETL schema and tables |
