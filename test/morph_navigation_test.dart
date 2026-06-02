import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/core/routing/morph_fade_page_route.dart';
import 'package:shifttac/core/routing/morph_motion.dart';
import 'package:shifttac/core/routing/morph_navigator.dart';
import 'package:shifttac/core/routing/morph_page_route.dart';
import 'package:shifttac/core/routing/morph_source_rect.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/settings/presentation/screens/settings_screen.dart';

void main() {
  group('MorphMotion', () {
    testWidgets('prefersReducedMotion follows MediaQuery.disableAnimations', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: _ReduceMotionProbe(),
          ),
        ),
      );

      expect(
        MorphMotion.prefersReducedMotion(
          tester.element(find.byType(_ReduceMotionProbe)),
        ),
        isTrue,
      );
    });
  });

  group('MorphNavigator reduced motion', () {
    testWidgets('pushFromRect uses MorphFadePageRoute when animations disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        MorphNavigator.pushFromRect<void>(
                          context: context,
                          sourceRect: const Rect.fromLTWH(0, 0, 100, 50),
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('destination')),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(find.text('destination'), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.text('destination')));
      expect(route, isA<MorphFadePageRoute<void>>());
      expect(route, isNot(isA<MorphPageRoute<void>>()));
    });

    testWidgets('pushFrom uses fade route when animations disabled', (
      tester,
    ) async {
      final sourceKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Column(
                    children: [
                      SizedBox(
                        key: sourceKey,
                        width: 160,
                        height: 72,
                        child: const ColoredBox(color: Colors.teal),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          MorphNavigator.pushFrom<void>(
                            context: context,
                            sourceKey: sourceKey,
                            builder: (_) => const Scaffold(
                              body: Center(child: Text('destination')),
                            ),
                          );
                        },
                        child: const Text('open'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      final route = ModalRoute.of(tester.element(find.text('destination')));
      expect(route, isA<MorphFadePageRoute<void>>());
    });
  });

  group('MorphSourceRect.tryMeasure', () {
    test('returns null when key has no context', () {
      final key = GlobalKey();
      expect(MorphSourceRect.tryMeasure(key), isNull);
    });

    testWidgets('returns global bounds when key is attached', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              key: key,
              width: 120,
              height: 48,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );

      final rect = MorphSourceRect.tryMeasure(key);
      expect(rect, isNotNull);
      expect(rect!.width, 120);
      expect(rect.height, 48);
    });
  });

  group('MorphNavigator.pushFrom', () {
    ModalRoute<dynamic>? routeForDestination(WidgetTester tester) {
      final element = tester.element(find.text('destination'));
      return ModalRoute.of(element);
    }

    testWidgets('falls back to MaterialPageRoute when source is not measured', (
      tester,
    ) async {
      final unattachedKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      MorphNavigator.pushFrom<void>(
                        context: context,
                        sourceKey: unattachedKey,
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('destination')),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final route = routeForDestination(tester);
      expect(route, isA<MaterialPageRoute<void>>());
      expect(route, isNot(isA<MorphPageRoute<void>>()));
    });

    testWidgets('uses MorphPageRoute when source can be measured', (
      tester,
    ) async {
      final sourceKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      key: sourceKey,
                      width: 160,
                      height: 72,
                      child: const ColoredBox(color: Colors.teal),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        MorphNavigator.pushFrom<void>(
                          context: context,
                          sourceKey: sourceKey,
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('destination')),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final route = routeForDestination(tester);
      expect(route, isA<MorphPageRoute<void>>());
    });
  });

  group('MorphNavigator.pushFromRect', () {
    testWidgets('pushes MorphPageRoute with explicit source rect', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      MorphNavigator.pushFromRect<void>(
                        context: context,
                        sourceRect: const Rect.fromLTWH(24, 48, 100, 50),
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('destination')),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('destination'), findsOneWidget);
      final element = tester.element(find.text('destination'));
      final route = ModalRoute.of(element);
      expect(route, isA<MorphPageRoute<void>>());
      expect((route! as MorphPageRoute<void>).sourceRect,
          const Rect.fromLTWH(24, 48, 100, 50));
    });
  });

  group('MorphNavigator.pushNamedFrom', () {
    Future<void> pumpMorphHost(
      WidgetTester tester, {
      required GlobalKey sourceKey,
      required VoidCallback onOpen,
    }) async {
      final settings = AppSettingsController();
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          child: AppAudioScope(
            audio: AppAudio(settings),
            child: ScreenUtilInit(
              designSize: AppConstants.designSize,
              builder: (context, child) => MaterialApp(
                home: Builder(
                  builder: (context) {
                    return Scaffold(
                      body: Column(
                        children: [
                          SizedBox(
                            key: sourceKey,
                            width: 160,
                            height: 72,
                            child: const ColoredBox(color: Colors.teal),
                          ),
                          ElevatedButton(
                            onPressed: onOpen,
                            child: const Text('open'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens gameplay with route arguments', (tester) async {
      final sourceKey = GlobalKey();
      late BuildContext hostContext;

      await pumpMorphHost(
        tester,
        sourceKey: sourceKey,
        onOpen: () {
          MorphNavigator.pushNamedFrom<void>(
            context: hostContext,
            sourceKey: sourceKey,
            routeName: AppRoutes.game,
            arguments: GameMode.classic,
          );
        },
      );

      hostContext = tester.element(find.text('open'));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.classic);
      final route = ModalRoute.of(tester.element(find.byType(GameplayScreen)));
      expect(route, isA<MorphPageRoute<void>>());
      expect(route!.settings.name, AppRoutes.game);
      expect(route.settings.arguments, GameMode.classic);
    });

    testWidgets('opens gameplay with GameSessionConfig', (tester) async {
      final sourceKey = GlobalKey();
      late BuildContext hostContext;
      const config = GameSessionConfig(mode: GameMode.shift);

      await pumpMorphHost(
        tester,
        sourceKey: sourceKey,
        onOpen: () {
          MorphNavigator.pushNamedFrom<void>(
            context: hostContext,
            sourceKey: sourceKey,
            routeName: AppRoutes.game,
            arguments: config,
          );
        },
      );

      hostContext = tester.element(find.text('open'));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.session, same(config));
    });

    testWidgets('opens SettingsScreen', (tester) async {
      final sourceKey = GlobalKey();
      late BuildContext hostContext;

      await pumpMorphHost(
        tester,
        sourceKey: sourceKey,
        onOpen: () {
          MorphNavigator.pushNamedFrom<void>(
            context: hostContext,
            sourceKey: sourceKey,
            routeName: AppRoutes.settings,
          );
        },
      );

      hostContext = tester.element(find.text('open'));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsScreen), findsOneWidget);
      final route = ModalRoute.of(tester.element(find.byType(SettingsScreen)));
      expect(route, isA<MorphPageRoute<void>>());
      expect(route!.settings.name, AppRoutes.settings);
    });

    testWidgets('falls back to MaterialPageRoute when source rect is null', (
      tester,
    ) async {
      final settings = AppSettingsController();
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        MorphNavigator.pushNamedFromRect<void>(
                          context: context,
                          sourceRect: null,
                          routeName: AppRoutes.settings,
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final route = ModalRoute.of(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(route, isA<MaterialPageRoute<void>>());
      expect(route, isNot(isA<MorphPageRoute<void>>()));
    });
  });
}

class _ReduceMotionProbe extends StatelessWidget {
  const _ReduceMotionProbe();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
