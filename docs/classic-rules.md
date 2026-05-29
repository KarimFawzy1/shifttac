# Classic Mode — Gameplay Rules

**Classic mode** is traditional 3×3 Tic Tac Toe on the same device. It is separate from ShiftTac mode.

## Overview

- Fixed **3×3** board, two players, alternating turns.
- **Every mark stays on the board** until the match ends — nothing is removed automatically.
- A match ends in a **win** (three in a row) or a **draw** (all nine cells filled with no winner).
- Starting player is chosen **at random** each match (same policy as ShiftTac).

## Turn flow

1. Validate the cell is empty and the match is still in progress.
2. Place the mark.
3. Check whether the mover has three in a row (row, column, or diagonal).
4. If won → match ends (`GameStatus.won`).
5. If all nine cells are occupied and there is no winner → **draw** (`GameStatus.draw`).
6. Otherwise → switch turn and continue.

## Draw

- Classic mode **can draw**. A full board with no winning line is a draw.
- The app shows a neutral result dialog (grey palette, no win celebration SFX).

## What Classic mode does not do

- No FIFO / “shift” of oldest marks.
- No faded “next to disappear” preview on the board.
- No three-active-mark limit.

## Related docs

- [Rules overview (mode comparison)](./rules.md)
- [ShiftTac mode rules](./shift-rules.md) — active-mark limit, no draw
