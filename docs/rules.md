# ShiftTac — Local Multiplayer Rules

ShiftTac ships two **offline, same-device** modes. They share the same 3×3 board, X/O players, and win detection, but the rules differ.

| | **ShiftTac mode** | **Classic mode** |
| --- | --- | --- |
| Home entry | Play ShiftTac | Play Classic |
| Marks on board | At most **3 active** per player; oldest is removed on the next placement | **All marks stay** until the match ends |
| Draw | **No** — play continues until someone wins | **Yes** — full board with no line is a draw |
| Tutorial | Rules tab / How to Play (ShiftTac-focused) | Not covered in How to Play |

## Detailed specifications

- [ShiftTac mode rules](./shift-rules.md) — FIFO active-mark limit, shifts, no draw.
- [Classic mode rules](./classic-rules.md) — traditional tic-tac-toe, permanent marks, draws.

## Implementation reference

- Mode selection: `GameMode` passed via `AppRoutes.game` route arguments (`GameMode.classic` or default ShiftTac).
- Engines: `ShiftGameEngine`, `ClassicGameEngine` (see `lib/features/game/domain/logic/`).

For the classic-mode delivery plan and phase history, see [classic-mode-plan.md](./classic-mode-plan.md).
