import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';

void main() {
  group('AppRouter.gameModeFromRouteArguments', () {
    test('defaults to shift when arguments are missing', () {
      expect(AppRouter.gameModeFromRouteArguments(null), GameMode.shift);
    });

    test('defaults to shift for invalid argument types', () {
      expect(AppRouter.gameModeFromRouteArguments('classic'), GameMode.shift);
      expect(AppRouter.gameModeFromRouteArguments(1), GameMode.shift);
    });

    test('returns classic when GameMode.classic is passed', () {
      expect(
        AppRouter.gameModeFromRouteArguments(GameMode.classic),
        GameMode.classic,
      );
    });
  });

  group('AppRouter.onGenerateRoute — game', () {
    Future<GameplayScreen> pumpGameRoute(
      WidgetTester tester, {
      Object? arguments,
    }) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (context, child) => MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.game,
                  arguments: arguments,
                ),
                child: const Text('open game'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open game'));
      await tester.pump();
      await tester.pump();
      return tester.widget<GameplayScreen>(find.byType(GameplayScreen));
    }

    testWidgets('opens ShiftTac gameplay with no args', (tester) async {
      final screen = await pumpGameRoute(tester);
      expect(screen.mode, GameMode.shift);
    });

    testWidgets('opens classic gameplay with GameMode.classic', (tester) async {
      final screen = await pumpGameRoute(tester, arguments: GameMode.classic);
      expect(screen.mode, GameMode.classic);
    });

    testWidgets('falls back to ShiftTac for invalid args', (tester) async {
      final screen = await pumpGameRoute(tester, arguments: 'invalid');
      expect(screen.mode, GameMode.shift);
    });
  });
}
