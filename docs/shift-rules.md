# ShiftTac — Gameplay Rules Specification

## Overview

## What is ShiftTac?

**ShiftTac** is a strategic evolution of classic 3×3 Tic Tac Toe.

The board remains fixed at **3×3**, but each player may only maintain **3 active marks** on the board at any time.

When a player places a new move while already owning 3 active marks:

1. Their oldest mark is removed automatically
2. The new mark is placed
3. The board is evaluated for victory

This creates a continuously evolving board state where every move changes the game.

The mechanic eliminates permanent board lock and prevents draw states.

---

## Core Gameplay Principles

ShiftTac is built around four core ideas:

* Simple to learn
* Constantly evolving
* Strategically predictive
* Never static

The player must think not only about:

* current board state
* next move

but also:

* which mark disappears next
* how the board will evolve

---

## Definitions

## Active Mark

A mark currently present on the board and eligible for win detection.

---

## Oldest Mark

The earliest active mark placed by a player that has not yet been removed.

---

## Active Move Rotation

The automatic removal of a player’s oldest active mark when placing a move beyond the 3-mark limit.

Internally, this behavior follows FIFO (First-In-First-Out) queue logic.

---

## Occupied Cell

Any board cell currently containing an active X or O mark.

---

## Final Board State

The resolved board after:

1. oldest mark removal
2. new move placement

Victory conditions are evaluated only against the final board state.

---

## Game Rules

## 1. Board

* Fixed 3×3 grid
* 9 total cells
* No board expansion
* No dynamic resizing

---

## 2. Players

The game contains two players:

* Player X
* Player O

Players alternate turns sequentially.

Player X always starts first unless modified by future game modes.

---

## 3. Active Mark Limit

Each player may only have:

* maximum 3 active marks simultaneously

A player may never own 4 active marks at the same time.

---

## 4. Active Move Rotation System

When a player already owns 3 active marks and places a new move:

1. The oldest active mark is removed
2. The new move is placed
3. The active move queue updates
4. The final board state is evaluated

This process occurs automatically.

---

## 5. FIFO Queue Behavior

Each player maintains a queue of active moves.

The queue always preserves move order.

Example:

## Player X Move Sequence

```text
Move 1 → A
Move 2 → C
Move 3 → E
```

Board now contains:

```text
A, C, E
```

Next move:

```text
Move 4 → G
```

Process:

```text
Remove A
Place G
```

Updated active marks:

```text
C, E, G
```

Next move:

```text
Move 5 → H
```

Process:

```text
Remove C
Place H
```

Updated active marks:

```text
E, G, H
```

The player always retains only their latest 3 active marks.

---

## 6. Win Condition

A player wins when their 3 active marks form:

* horizontal line
* vertical line
* diagonal line

Both diagonal directions are valid.

---

## 7. Win Evaluation Order

Victory evaluation must occur only after the board reaches its final resolved state.

Correct order:

```text
1. Remove oldest mark (if needed)
2. Place new move
3. Evaluate win condition
```

The game must never evaluate victory:

* before mark removal
* during transition states
* during animations

Only the final resolved board state is valid for win detection.

---

## 8. No Draw State

ShiftTac contains no draw condition.

Because active marks continuously rotate:

* the board never permanently fills
* the game always remains solvable

The match continues until one player wins.

---

## Turn Lifecycle

Every turn follows the exact same deterministic sequence.

## Turn Flow

```text
Player Input
↓
Validate Input
↓
Remove Oldest Mark (optional)
↓
Place New Mark
↓
Update Active Queue
↓
Evaluate Win Condition
↓
End Turn
↓
Switch Active Player
```

This order must always remain consistent.

---

## Input Rules

## Valid Move

A move is valid when:

* the selected cell is empty
* the game is still active
* no transition lock is active

---

## Invalid Move

The following actions are ignored:

* tapping occupied cells
* tapping after game completion
* rapid simultaneous taps
* input during animation lock
* duplicate move events

Invalid actions must not modify:

* board state
* move queues
* turn order

---

## Game State Rules

## Ongoing State

The game continues while:

* no player has won

---

## Win State

When a player completes a valid line:

* the game immediately enters WIN state
* board interaction becomes disabled
* no further moves are accepted

---

## Restart State

Restarting the game resets:

* board state
* active move queues
* current player
* move counter
* win state
* animation state

The game returns to initial conditions.

---

## Data Model Recommendations

## Board Representation

Recommended representations:

```text
List<List<Cell>>
```

or

```text
Map<Position, Player>
```

---

## Recommended Move Model

```text
class Move {
    Player player;
    Position position;
    int turnIndex;
}
```

---

## Active Move Queue

Each player maintains:

```text
Queue<Move> activeMoves
```

Maximum queue size:

```text
3
```

---

## Technical Rules

## Deterministic State

The game state must remain deterministic.

At any moment:

* the same input sequence must produce the same board state

---

## Source of Truth

The active move queues should be treated as the authoritative game state.

The board should be derived from queue data rather than maintained independently whenever possible.

This helps prevent:

* desynchronization
* ghost marks
* invalid removals
* duplicate state mutations

---

## Animation Rules

Animations are visual-only.

Animations must never delay:

* logical state updates
* queue updates
* win evaluation
* turn switching

---

## Input Lock Recommendation

Recommended temporary input lock:

```text
100ms – 180ms
```

after successful move placement.

This helps prevent accidental rapid taps.

---

## Performance Considerations

## Recommended Optimizations

* evaluate victory only after moves
* avoid unnecessary board rebuilds
* avoid repeated full-state recalculations
* minimize UI re-renders

---

## Win Detection Optimization

Since the board is fixed at 3×3:

* full board scans are acceptable
* optimization is optional

Clarity and correctness are prioritized over premature optimization.

---

## Edge Cases

The implementation must correctly handle:

* occupied cell selection
* rapid consecutive taps
* mark removal from potential winning lines
* win occurring immediately after rotation
* win occurring on 3rd move
* simultaneous animation + input attempts
* restart during transition states

---

## Testing Requirements

## Functional Tests

The game must verify:

* horizontal wins
* vertical wins
* diagonal wins
* FIFO removal behavior
* turn switching
* restart behavior
* active queue correctness
* move replacement correctness

---

## Edge Case Tests

The game must verify:

* oldest mark removal correctness
* prevention of 4 active marks
* invalid move handling
* win detection after rotation
* rapid tap protection
* deterministic state consistency

---

## UI/UX Requirements

The gameplay UI must clearly communicate:

* current player
* active marks
* oldest mark pending removal
* valid board state
* win state

---

## Faded Mark Indicator

The oldest active mark for the current player should be visually indicated.

Recommended treatment:

* reduced opacity
* subtle desaturation
* soft fade styling

This indicator is a core gameplay communication mechanic.

Players should immediately understand:

> “This mark disappears next.”

---

## Future Expansion Compatibility

The rule system should remain compatible with future features:

* AI opponent
* replay system
* undo functionality
* online multiplayer
* spectator mode
* move history
* analytics
* ranked matchmaking

---

## AI Considerations

AI systems must account for:

* move expiration
* active move rotation
* disappearing threats
* future board evolution

Traditional Tic Tac Toe evaluation logic is insufficient for ShiftTac.

---

## Final Design Philosophy

ShiftTac is not about filling the board.

It is about:

* prediction
* timing
* adaptation
* evolving positional control

Every move changes the board.

Every disappearing mark changes the strategy.
