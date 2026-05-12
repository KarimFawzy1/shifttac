# ShiftTac — Implementation Rules

This document defines the engineering and implementation guidelines for the project.

The goal is to keep the codebase:

- clean
- scalable
- readable
- maintainable
- predictable

while avoiding unnecessary complexity during early development.

---

## 1. General Philosophy

Prioritize:

- clarity over cleverness
- simplicity over abstraction
- readability over optimization
- consistency over experimentation

The project should feel:

- calm
- structured
- intentional

just like the game itself.

---

## 2. Architecture Rules

### Keep Game Logic Outside the UI

UI widgets should never decide:

- who wins
- whose turn is next
- which mark disappears
- FIFO behavior
- move validation

All gameplay rules belong inside:

```txt
features/game/domain/logic/
```

UI should only:

- display state
- send user actions
- react to state changes

---

### Prefer Feature-Based Structure

Keep files grouped by feature.

Avoid creating generic folders that mix unrelated responsibilities.

---

### Avoid Premature Complexity

Do not introduce:

- repositories
- dependency injection
- service layers
- use cases
- data sources
- overly abstract architecture

unless a real need appears later.

The current version should remain lightweight and focused.

---

## 3. State Management Rules

### Single Source of Truth

The Cubit state should represent the authoritative UI state.

Avoid duplicated state across widgets.

---

### Keep State Predictable

State updates should be:

- explicit
- deterministic
- easy to trace

Avoid hidden mutations.

---

### Prefer Immutable State

When possible:

- create new state instances
- avoid modifying existing objects directly

---

### Avoid Business Logic in Cubit

Cubit should coordinate state flow.

Core gameplay calculations should remain inside:

```txt
game_engine.dart
win_checker.dart
```

---

## 4. UI Rules

### Keep Widgets Small

Prefer small focused widgets over very large screens.

A widget should ideally have one clear responsibility.

---

### Reuse Shared Components

If a UI pattern appears multiple times:

- buttons
- headers
- panels
- animations

move it into shared widgets.

---

### Avoid Deep Widget Nesting

Break complex layouts into smaller widgets for readability.

---

### Use Const Constructors When Possible

Prefer `const` widgets whenever appropriate for cleaner rebuild behavior.

---

### The Board Is the Hero

Gameplay clarity always has higher priority than decorative UI.

Do not overcrowd the gameplay screen.

---

## 5. Animation Rules

### Keep Motion Calm

Animations should feel:

- soft
- responsive
- smooth

Avoid exaggerated effects.

---

### Separate Logic From Animation

Animations are visual only.

Game state should not depend on animation completion.

---

### Prevent Rapid Interaction Issues

During sensitive transitions:

- temporarily block rapid taps
- avoid duplicate move events

Keep this lightweight and predictable.

---

## 6. Styling Rules

### Follow the Design System

Use values from the design system whenever possible:

- colors
- spacing
- typography
- radius
- animation timing

Avoid random visual values.

---

### Avoid Magic Numbers

Prefer centralized constants for:

- durations
- spacing
- board sizes
- opacity values

---

### Maintain Consistent Spacing

Use spacing intentionally.

The interface should feel balanced and breathable.

---

## 7. Code Quality Rules

### Write Readable Code

Prefer code that is easy to understand quickly.

Future readability is more important than saving a few lines.

---

### Keep Functions Focused

A function should ideally do one thing clearly.

---

### Name Things Clearly

Use descriptive names for:

- variables
- methods
- widgets
- states

Avoid unclear abbreviations.

---

### Avoid Large Files

If a file becomes difficult to scan comfortably:

- split responsibilities
- extract widgets or helpers

---

## 8. Performance Rules

### Optimize Only When Needed

The board is small and predictable.

Prioritize correctness and readability before optimization.

---

### Avoid Unnecessary Rebuilds

Keep rebuild scopes focused where possible.

---

## 9. Testing Rules

### Test Core Gameplay Logic First

Gameplay correctness is more important than UI polish.

Prioritize tests for:

- FIFO rotation
- win detection
- turn switching
- move validation
- restart behavior

---

### Edge Cases Matter

Always consider:

- rapid taps
- occupied cells
- animation overlap
- restart timing
- win-after-rotation scenarios

---

## 10. Cursor Agent Collaboration Rules

### Implement Incrementally

Do not build large systems all at once.

Prefer small completed milestones.

---

### Modify Minimal Files

Avoid unnecessary refactors during early development.

Keep changes focused and isolated.

---

### Preserve Existing Patterns

Follow the current project structure and conventions before introducing new patterns.

---

### Avoid Placeholder Logic

Prefer complete working implementations over temporary fake systems whenever possible.

---

## 11. Future Expansion

The project should remain compatible with future additions such as:

- AI opponent
- replay system
- themes
- online multiplayer
- analytics
- sound systems

But current implementation should stay intentionally lightweight until those features are actually needed.

---

Add this section to `implementation-rules.md`:

## 12. Responsive UI Rules

### Use ScreenUtil for Responsive Sizing

Use `flutter_screenutil` to keep the UI consistent across different phone and tablet sizes.

Use ScreenUtil for:

- spacing
- padding
- margins
- border radius
- icon sizes
- board sizing
- button height
- font scaling when appropriate

Example:

```dart
EdgeInsets.all(24.w)
SizedBox(height: 16.h)
BorderRadius.circular(16.r)
Icon(size: 24.sp)
```

---

### Initialize ScreenUtil Once

ScreenUtil should be initialized at the app root level, usually inside `app.dart`.

Do not initialize it inside individual screens or widgets.

---

### Keep Responsive Values Consistent

Avoid random responsive values across the app.

Prefer using centralized spacing and sizing constants from:

```txt
core/theme/app_spacing.dart
```

---

### Recommended Base Design Size

Use one consistent design reference size for the app.

Recommended:

```dart
designSize: Size(390, 844)
```

This works well for modern mobile layouts.

---

### Board Responsiveness

The game board should remain:

- centered
- square
- readable
- easy to tap

The board should scale with screen size but should not become too large on tablets.

Use constraints when needed.

Example:

```dart
final boardSize = min(0.82.sw, 420.w);
```

---

### Text Scaling

Use responsive typography carefully.

Text should remain readable but not oversized.

Prefer defining text styles centrally in:

```txt
core/theme/app_text_styles.dart
```

---

### Tablet Behavior

On larger screens:

- increase spacing slightly
- keep content centered
- avoid stretching layouts full width
- use max-width containers when needed

---

### Avoid Overusing ScreenUtil

Do not make every value responsive blindly.

Use fixed values where they make more visual sense.

The goal is consistency, not mathematical scaling.

---

## Final Principle

ShiftTac should feel carefully crafted.

The codebase should reflect the same qualities as the gameplay experience:

- elegant
- calm
- structured
- intentional
- easy to evolve
