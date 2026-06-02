# Morph Navigation Plan

## Goal

Add a reusable navigation animation that makes a tapped widget visually morph into the next full-screen route.

The first required consumers are:

- `HomeActionCard` in `lib/features/home/presentation/screens/home_screen.dart`, starting with the card-to-gameplay transition.
- The `How to Play` and `Settings` buttons in `lib/features/game/presentation/widgets/pause_bottom_sheet.dart`.

The implementation should not be hardcoded to those widgets. It should become a small shared navigation layer that any future widget can use when it needs to morph into a destination screen.

## Expected Result

When the user taps a supported source widget:

1. The app measures the source widget's global position and size.
2. A custom route is pushed.
3. During the route transition, a rounded container starts at the source widget bounds.
4. That container expands to cover the full screen.
5. The destination screen fades, scales, or reveals inside the expanding shape.
6. The old route is visually covered cleanly with no one-pixel halos, white seams, or clipped corner artifacts.
7. Back navigation reverses the transition where it makes sense.

This is different from the current AI pill animation in `ai_settings_pills.dart`. The AI pill animation is an anchored overlay morph inside the same route. Full-screen navigation should use a reusable route transition, because it needs to coordinate route lifecycle, back gestures, hero-like ownership, and destination rendering.

## Non-Goals

- Do not rebuild the app routing system from scratch.
- Do not replace every `Navigator.pushNamed` call.
- Do not force every route to use morph navigation.
- Do not couple this to `HomeActionCard`, `PauseBottomSheet`, `GameplayScreen`, `HowToPlayScreen`, or `SettingsScreen`.
- Do not introduce a large animation package unless the built-in Flutter route APIs are not enough.
- Do not duplicate the AI settings pill overlay implementation for page navigation.

## Recommended Architecture

Create a shared morph navigation utility under `lib/core/routing/`.

Suggested files:

- `lib/core/routing/morph_page_route.dart`
- `lib/core/routing/morph_navigator.dart`
- `lib/core/routing/morph_route_targets.dart` if named-route destination construction needs a small helper

The reusable API should be source-widget based:

```dart
MorphNavigator.pushNamedFrom(
  context,
  sourceKey: cardKey,
  routeName: AppRoutes.game,
  arguments: session,
);
```

And builder based for future custom destinations:

```dart
MorphNavigator.pushFrom(
  context,
  sourceKey: buttonKey,
  builder: (_) => const SettingsScreen(standalone: true),
  settings: const RouteSettings(name: AppRoutes.settings),
);
```

The key idea is that callers only provide:

- The source widget key.
- The target route or page builder.
- Optional route arguments.
- Optional transition styling.

The shared layer owns:

- Measuring the source rectangle.
- Falling back safely if measurement fails.
- Creating the custom `PageRoute`.
- Animating size, position, radius, color, and child opacity.
- Preserving route settings and arguments.

## Core Design

### Source Measurement

Use a `GlobalKey` on the tappable source widget or on a wrapper around the visual surface that should morph.

The measurement helper should:

- Read `key.currentContext`.
- Get the `RenderBox`.
- Convert `localToGlobal(Offset.zero)` to screen coordinates.
- Return a `Rect` with global origin and widget size.
- Use `MediaQuery.sizeOf(context)` for the final full-screen rect.

If measurement fails, the navigation should still work by using a normal route push or a centered scale transition. The user should never be blocked by animation plumbing.

### Route Transition

Use a custom `PageRouteBuilder` or `PageRoute` implementation.

The transition should animate:

- `Rect`: from source widget bounds to full-screen bounds.
- `BorderRadius`: from source radius to `BorderRadius.zero`.
- `Color`: from source surface color to the destination scaffold background if needed.
- Destination content opacity: delayed until the expanding surface has enough size.
- Destination content scale: subtle, such as `0.98` to `1.0`, to avoid a flat fade.

Recommended timing:

- Forward duration: 420-520 ms.
- Reverse duration: 300-380 ms.
- Position/size curve: `Curves.easeOutCubic`.
- Content curve: delayed interval, for example `Interval(0.35, 1.0, curve: Curves.easeOut)`.

The route should render a full-screen transparent `Stack`:

- The previous route remains underneath.
- The animated morph surface is positioned from the source rect to the screen rect.
- The destination page is clipped by the same animated border radius.
- A subtle scrim can fade in behind the morph only if needed for contrast.

### Clipping and One-Pixel Artifact Prevention

The implementation must avoid the white-edge issues already seen in the AI pill work.

Rules:

- Use one owner for the visible shape. Prefer `Material` with `clipBehavior: Clip.antiAlias` or `ClipRRect`, not both fighting each other.
- Do not layer separately rounded containers with slightly different radii.
- Do not draw a border during the morph unless it is clipped by exactly the same radius.
- Expand the painted surface by a very small amount, such as `0.5` logical pixels, only if device-pixel rounding creates visible gaps.
- Keep the destination background color consistent with the expanding surface.

### Route Construction

The cleanest path is to let the morph utility build the same destination screens that `AppRouter` already builds.

Options:

1. Add a route factory helper to `AppRouter`, such as `AppRouter.buildPage(settings)`, and let both normal and morph routes use it.
2. Add a small internal helper in `morph_route_targets.dart` that handles only the initial morph-enabled routes.
3. Pass a destination builder directly from each call site.

Preferred approach: option 1, because it avoids route destination drift. `AppRouter.onGenerateRoute` can keep returning `MaterialPageRoute` for normal navigation, while `MorphNavigator.pushNamedFrom` can reuse the same destination builder inside `MorphPageRoute`.

### Pause Sheet Behavior

The pause sheet has an extra lifecycle concern: the sheet currently closes before navigation and resumes the game when the pushed route completes.

For `How to Play` and `Settings`, preserve the current behavior:

- Set `resumeTimerOnClose` to `false`.
- Close the pause sheet.
- Push the destination route with morph navigation.
- Resume the match when the destination route completes if the cubit is still open.

The visual source for the morph should be the tapped menu tile, not the entire bottom sheet. That means `_MenuTile` should be able to expose or receive a key for the morph source.

## Phase 1: Routing Foundation — Done

Build the reusable route and navigation API without wiring it into the app yet.

Tasks:

- Create `MorphPageRoute<T>`.
- Create `MorphNavigator`.
- Add a source measurement helper.
- Define a small configuration object, for example `MorphRouteConfig`.
- Support push by page builder.
- Support a graceful fallback if source measurement fails.
- Keep all code under `lib/core/routing/`.

Implementation notes:

- `MorphPageRoute` should accept `sourceRect`, `destinationBuilder`, `RouteSettings`, and optional visual config.
- Use `opaque: false` only if the previous route must remain visible during the transition. Ensure the final page still behaves like a normal full-screen route.
- Keep animation math in one place so future consumers do not copy route transition code.

Definition of Done:

- [x] A demo call can push any screen from any keyed widget using `MorphNavigator.pushFrom`.
- [x] Normal named routes still work unchanged.
- [x] Measurement failure falls back to a normal route or safe default transition.
- [x] No production screen has been migrated yet.
- [x] Unit or widget coverage exists for source measurement fallback where practical.
- [x] `flutter analyze` passes.
- [x] Relevant tests pass.
- [x] Commit created with a message such as `Add reusable morph navigation route`.
- [x] Branch pushed to GitHub.

**Implemented in:** `morph_source_rect.dart`, `morph_route_config.dart`, `morph_page_route.dart`, `morph_navigator.dart`, `test/morph_navigation_test.dart`.

## Phase 2: AppRouter Reuse — Done

Make morph named-route navigation reuse the same page construction as normal navigation.

Tasks:

- Refactor `AppRouter` so route destination construction can be reused without changing current behavior.
- Add `MorphNavigator.pushNamedFrom`.
- Ensure `AppRoutes.game`, `AppRoutes.howToPlay`, and `AppRoutes.settings` can be built through the reusable path.
- Preserve route settings and arguments.

Implementation notes:

- Avoid duplicating route-to-screen mapping in two places.
- Keep `AppRouter.onGenerateRoute` as the single public entry point for normal navigation.
- Extract only the page builder decision, not the whole route implementation.

Definition of Done:

- [x] `Navigator.pushNamed` behavior is unchanged.
- [x] `MorphNavigator.pushNamedFrom` can navigate to game, how-to-play, and settings.
- [x] Existing router tests still pass.
- [x] New router or morph navigator tests cover route arguments for gameplay.
- [x] `flutter analyze` passes.
- [x] Relevant tests pass.
- [x] Commit created with a message such as `Reuse app route builders for morph navigation`.
- [x] Branch pushed to GitHub.

**Implemented in:** `AppRouter.pageBuilderFor`, `MorphNavigator.pushNamedFrom`, extended `app_router_test.dart` and `morph_navigation_test.dart`.

## Phase 3: HomeActionCard to Gameplay — Done

Wire the morph transition into the home screen cards that open gameplay.

Tasks:

- Add a stable `GlobalKey` for the `Play ShiftTac` card.
- Add keys for `Play Classic` and `VS AI` only if they should also morph into gameplay in this pass.
- Update the tapped card's navigation from `Navigator.pushNamed` to `MorphNavigator.pushNamedFrom`.
- Preserve current audio feedback.
- Preserve existing route arguments:
  - Default ShiftTac for `Play ShiftTac`.
  - `GameMode.classic` for `Play Classic`.
  - `GameSessionConfig` for `VS AI`.

Implementation notes:

- The card's visual bounds should be measured from the card surface, not from just the text or icon.
- If `HomeActionCard` needs to own the key, expose a `morphKey` or `sourceKey` parameter rather than reaching into private card internals.
- Keep `HomeActionCard` simple. It should not know about route names or destination screens.

Definition of Done:

- [x] Tapping the supported home card morphs smoothly into `GameplayScreen`.
- [x] Game startup audio still plays once.
- [x] Existing gameplay arguments still resolve correctly.
- [x] AI pills remain independently tappable and do not trigger card navigation.
- [x] The transition has no visible rounded white edge or one-pixel halo.
- [x] Home screen widget tests are updated for the new navigation behavior.
- [x] `flutter analyze` passes.
- [x] Relevant tests pass.
- [x] Manual check on at least one small and one larger emulator/device size.
- [x] Commit created with a message such as `Morph home gameplay navigation`.
- [x] Branch pushed to GitHub.

**Implemented in:** `HomeActionCard.morphKey`, `HomeScreen` morph keys + `MorphNavigator.pushNamedFrom`, card-matched `MorphRouteConfig` surface colors.

## Phase 4: Pause Sheet Buttons to How to Play and Settings

Wire the morph transition into the pause sheet menu tiles for `How to Play` and `Settings`.

Tasks:

- Let `_MenuTile` accept an optional `GlobalKey` or source key.
- Add keys for the `How to Play` and `Settings` tiles.
- Update pause navigation so those tiles call morph navigation after closing the sheet.
- Preserve the current pause lifecycle:
  - Do not resume the timer while navigating away.
  - Resume the match when the pushed destination route completes.
  - Keep `Exit to Home`, `Resume`, and `Restart Match` behavior unchanged.

Implementation notes:

- Because the sheet is popped before the target route is pushed, capture the source rect before popping the sheet.
- Add a lower-level API such as `MorphNavigator.pushNamedFromRect` if needed. This avoids measuring a tile after its route has been dismissed.
- The transition should begin from the tapped tile's last known global bounds.

Definition of Done:

- Tapping `How to Play` morphs from the tile into the standalone How to Play screen.
- Tapping `Settings` morphs from the tile into the standalone Settings screen.
- The pause sheet closes cleanly without double animations fighting each other.
- The game remains paused while the destination screen is open.
- Returning from the destination resumes the match if the cubit is still active.
- Other pause sheet actions behave exactly as before.
- Widget tests cover the pause navigation lifecycle where practical.
- `flutter analyze` passes.
- Relevant tests pass.
- Manual check verifies no layout jump at the moment the sheet is dismissed.
- Commit created with a message such as `Morph pause sheet navigation actions`.
- Branch pushed to GitHub.

## Phase 5: Polish, Accessibility, and Reduced Motion

Make the animation feel production-ready and respectful of platform settings.

Tasks:

- Respect reduced-motion preferences from `MediaQuery.disableAnimations` or the nearest Flutter-supported equivalent.
- Add configurable colors, radii, and durations.
- Tune curves and opacity intervals based on device testing.
- Ensure semantic navigation announcements still make sense.
- Ensure back navigation does not expose broken intermediate states.

Implementation notes:

- Reduced motion should use a short fade or normal route transition instead of the full morph.
- Keep default config aligned with existing app tokens in `AppColors` and `AppSpacing`.
- Do not make every call site pass detailed styling unless it truly needs customization.

Definition of Done:

- Reduced-motion mode avoids the full morph.
- Default animation matches the app's visual language.
- Reverse transition is acceptable or intentionally simplified.
- No accessibility regression is found in basic screen reader navigation.
- `flutter analyze` passes.
- Relevant tests pass.
- Manual checks cover Android emulator and at least two screen sizes.
- Commit created with a message such as `Polish morph navigation behavior`.
- Branch pushed to GitHub.

## Phase 6: Final Validation and Cleanup

Stabilize the feature and remove temporary code.

Tasks:

- Remove debug-only keys, logs, or temporary fallback paths that are no longer needed.
- Review all route call sites touched by the feature.
- Confirm no obsolete navigation helper code was left behind.
- Run the full test suite if project runtime allows it.
- Update docs if implementation details differ from this plan.

Definition of Done:

- Full intended scope is implemented:
  - `HomeActionCard` to gameplay.
  - Pause sheet `How to Play` tile to How to Play screen.
  - Pause sheet `Settings` tile to Settings screen.
  - Shared morph navigation utility available for future widgets.
- Full test suite passes, or any skipped/unavailable tests are documented.
- `flutter analyze` passes.
- Code is reviewed for duplicated animation math.
- Final commit created with a message such as `Finalize morph navigation rollout`.
- Branch pushed to GitHub.
- Pull request opened or updated with summary, test plan, and screenshots/video if available.

## Suggested Test Plan

Automated tests:

- `AppRouter` still builds all existing routes.
- Gameplay route arguments still resolve through morph navigation.
- Morph navigation falls back safely when the source key cannot be measured.
- Home screen tap starts navigation with the expected arguments.
- Pause sheet How to Play and Settings actions keep the timer lifecycle intact.

Manual tests:

- Tap `Play ShiftTac` and verify the card expands into gameplay.
- Tap `Play Classic` and `VS AI` if included in the home phase.
- Open pause sheet, tap `How to Play`, return, and verify the game resumes.
- Open pause sheet, tap `Settings`, return, and verify the game resumes.
- Test on at least two screen sizes.
- Test with system animations reduced or disabled.
- Watch rounded corners during the animation for one-pixel gaps.

## Future Reuse Examples

Once the shared API exists, future widgets can use it for:

- Home card to online matchmaking.
- Result dialog button to rematch setup.
- Profile tile to profile details.
- Store item card to purchase details.
- Settings row to nested settings pages.

Future consumers should not add new route animation classes. They should call `MorphNavigator` with a source key or a premeasured source rect.
