# ShiftTac

ShiftTac is a Flutter game built around a simple twist on tic-tac-toe: only a few marks stay active on the board at once, so each new move can replace the oldest mark and change the whole position. The app is organized by feature, with game rules kept in domain logic and UI driven by a Cubit layer, as described in the project specs.

Documentation for design, rules, folder layout, implementation guardrails, and the phased roadmap lives in the [`docs/`](docs/) directory. Start with [`docs/development-roadmap.md`](docs/development-roadmap.md) for build order and acceptance criteria.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.10.3` per `pubspec.yaml`)

## Run locally

```bash
flutter pub get
flutter run
```

You should see a blank screen; the window title / task name should show **ShiftTac** once theming and shell work land in later phases.

## Analyze & test

```bash
flutter analyze
flutter test
```
