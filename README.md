# ShiftTac

> Every move changes the board.

ShiftTac is a modern strategic evolution of classic Tic Tac Toe built with Flutter.

Unlike traditional Tic Tac Toe, players may only keep **3 active marks** on the board at any time. When a player places a fourth move, their oldest mark disappears automatically.

This creates a constantly evolving board where prediction, timing, and adaptation matter more than static positioning.

---

# Preview

ShiftTac is designed as a:

- Calm competitive experience
- Premium casual strategy game
- Local multiplayer board game
- Modern minimalist mobile game

The experience focuses on:

- Elegant UI
- Tactile interactions
- Strategic gameplay
- Smooth animations
- Infinite replayability

---

# Core Gameplay Mechanic

Each player can only maintain:

```text
3 active marks
```

When placing a new move while already owning 3 marks:

```text
1. Oldest mark disappears
2. New move is placed
3. Win condition is evaluated
```

This follows a FIFO (First-In-First-Out) queue system.

Example:

```text
X places A
X places B
X places C
```

Board:

```text
A B C
```

Next move:

```text
X places D
```

Result:

```text
A disappears
B C D remain
```

The board never permanently fills.

There are no draw states.

---

# Features

## Gameplay

- Infinite Tic Tac Toe gameplay loop
- FIFO disappearing move mechanic
- Local multiplayer support
- Real-time win detection
- Animated move transitions
- Faded oldest move indicator
- Restart and replay support

## UI/UX

- Premium modern design system
- Responsive layouts
- Smooth animations
- Minimalist visual language
- Soft tactile interactions
- Accessibility-focused interface

## Architecture

- Feature-based Flutter structure
- Cubit state management
- Pure domain game logic
- Scalable project organization
- Clean separation between UI and logic

---

# Tech Stack

- Flutter
- Dart
- flutter_bloc / Cubit
- Material 3

---

# Project Structure

The project follows a feature-first architecture with isolated game logic.

```text
lib/
├── core/
├── features/
├── shared/
└── assets/
```

Main gameplay logic lives inside:

```text
features/game/domain/logic/
```

UI components only render state and dispatch actions.

Game rules and mechanics remain independent from presentation.

---

# Architecture Philosophy

ShiftTac intentionally avoids unnecessary complexity.

The current architecture focuses on:

- Simplicity
- Scalability
- Maintainability
- Fast iteration

The project does NOT currently include:

```text
repositories/
usecases/
data/
services/
dependency_injection/
```

These layers should only be added when the app actually requires them.

---

# Game Rules

## Board

- Fixed 3×3 grid
- 2 players
- Alternating turns

## Active Mark Limit

Each player may only own:

```text
3 active marks
```

## Move Rotation

When a player places a move beyond the limit:

```text
Remove oldest mark
Place new mark
Check victory
```

## Win Condition

A player wins by forming:

- Horizontal line
- Vertical line
- Diagonal line

Victory is evaluated only after the board reaches its final resolved state.

---

# Design System

ShiftTac uses a calm premium visual identity.

## Design Keywords

- Elegant
- Strategic
- Infinite
- Minimal
- Tactile
- Smooth
- Timeless

## Primary Colors

| Purpose | Color |
|---|---|
| Background | Warm Ivory |
| Player O | Teal |
| Player X | Soft Coral |
| Highlight | Warm Gold |
| Text | Ink Navy |

## Typography

- Poppins → headings and buttons
- Nunito Sans → body text and descriptions

---

# App Flow

```text
Splash
↓
Onboarding
↓
Home
↓
Gameplay
↓
Win Dialog
↓
Replay or Exit
```

---

# Getting Started

## Prerequisites

Install:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code

Verify Flutter installation:

```bash
flutter doctor
```

---

# Installation

Clone the repository:

```bash
git clone <repository-url>
```

Navigate into the project:

```bash
cd shifttac
```

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

---

# Testing

Run tests using:

```bash
flutter test
```

Current test coverage includes:

- Game engine
- Win checker
- Cubit state
- FIFO move rotation
- Win detection
- Edge cases

---

# Recommended Development Order

```text
1. Theme system
2. Game models
3. Win checker
4. Game engine
5. Game state
6. Game cubit
7. Gameplay screen
8. Board widget
9. Cell widget
10. Win dialog
```

---

# Gameplay UX Rules

## Occupied Cell

- Input ignored
- Subtle shake feedback

## Oldest Active Mark

The oldest mark for the active player is visually faded.

This communicates:

> “This mark disappears next.”

## Win State

When a player wins:

- Board interaction stops
- Win animation plays
- Result dialog appears

---

# Future Expansion

The architecture is prepared for future features such as:

- AI opponent
- Online multiplayer
- Match history
- Themes
- Sound settings
- Replay system
- Leaderboards
- Ranked matchmaking

---

# Product Vision

ShiftTac is designed to feel like:

> A beautifully crafted strategy object.

The UI should support the gameplay mechanic — never overpower it.

Every move changes the board.

---

# References

Project structure reference: [docs/structure.md](docs/structure.md)

Design system reference: [docs/design.md](docs/design.md)

Gameplay rules reference: [docs/rules.md](docs/rules.md)
