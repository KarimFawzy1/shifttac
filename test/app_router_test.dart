import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/bot_opponent_config.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';

void main() {
  group('AppRouter.sessionFromRouteArguments', () {
    test('defaults to ShiftTac local session when arguments are missing', () {
      expect(
        AppRouter.sessionFromRouteArguments(null),
        const GameSessionConfig.shift(),
      );
    });

    test('defaults to ShiftTac for invalid argument types', () {
      expect(
        AppRouter.sessionFromRouteArguments('classic'),
        const GameSessionConfig.shift(),
      );
      expect(
        AppRouter.sessionFromRouteArguments(1),
        const GameSessionConfig.shift(),
      );
    });

    test('maps GameMode.shift to a shift session', () {
      final session = AppRouter.sessionFromRouteArguments(GameMode.shift);
      expect(session.mode, GameMode.shift);
      expect(session.bot, isNull);
      expect(session.startingPlayer, isNull);
      expect(session.isAiSession, isFalse);
    });

    test('maps GameMode.classic to a classic session', () {
      final session = AppRouter.sessionFromRouteArguments(GameMode.classic);
      expect(session.mode, GameMode.classic);
      expect(session.bot, isNull);
      expect(session.isAiSession, isFalse);
    });

    test('returns GameSessionConfig unchanged', () {
      const config = GameSessionConfig(
        mode: GameMode.classic,
        bot: BotOpponentConfig(
          difficulty: BotDifficulty.intermediate,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
      );
      expect(AppRouter.sessionFromRouteArguments(config), same(config));
    });

    test('preserves classicAi session config from route arguments', () {
      final config = GameSessionConfig.classicAi(
        BotDifficulty.hard,
        random: Random(0),
      );
      final session = AppRouter.sessionFromRouteArguments(config);
      expect(session.mode, GameMode.classic);
      expect(session.bot!.difficulty, BotDifficulty.hard);
      expect(session.bot!.botPlayer, Player.o);
      expect(session.startingPlayer, config.startingPlayer);
      expect(session.isAiSession, isTrue);
    });

    test('preserves shiftAi session config from route arguments', () {
      final config = GameSessionConfig.shiftAi(
        BotDifficulty.intermediate,
        random: Random(0),
      );
      final session = AppRouter.sessionFromRouteArguments(config);
      expect(session.mode, GameMode.shift);
      expect(session.bot!.difficulty, BotDifficulty.intermediate);
      expect(session.bot!.botPlayer, Player.o);
      expect(session.startingPlayer, config.startingPlayer);
      expect(session.isAiSession, isTrue);
    });
  });

  group('AppRouter.gameModeFromRouteArguments', () {
    test('defaults to shift when arguments are missing', () {
      expect(AppRouter.gameModeFromRouteArguments(null), GameMode.shift);
    });

    test('defaults to shift for invalid argument types', () {
      expect(AppRouter.gameModeFromRouteArguments('classic'), GameMode.shift);
      expect(AppRouter.gameModeFromRouteArguments(1), GameMode.shift);
    });

    test('returns shift when GameMode.shift is passed', () {
      expect(
        AppRouter.gameModeFromRouteArguments(GameMode.shift),
        GameMode.shift,
      );
    });

    test('returns classic when GameMode.classic is passed', () {
      expect(
        AppRouter.gameModeFromRouteArguments(GameMode.classic),
        GameMode.classic,
      );
    });

    test('derives mode from GameSessionConfig', () {
      const config = GameSessionConfig(mode: GameMode.classic);
      expect(AppRouter.gameModeFromRouteArguments(config), GameMode.classic);
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
      expect(screen.session.mode, GameMode.shift);
      expect(screen.session.bot, isNull);
    });

    testWidgets('opens classic gameplay with GameMode.classic', (tester) async {
      final screen = await pumpGameRoute(tester, arguments: GameMode.classic);
      expect(screen.mode, GameMode.classic);
      expect(screen.session.mode, GameMode.classic);
      expect(screen.session.bot, isNull);
    });

    testWidgets('opens gameplay with GameSessionConfig', (tester) async {
      const config = GameSessionConfig(
        mode: GameMode.classic,
        bot: BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
      );
      final screen = await pumpGameRoute(tester, arguments: config);
      expect(screen.session, same(config));
      expect(screen.session.isAiSession, isTrue);
    });

    testWidgets('falls back to ShiftTac for invalid args', (tester) async {
      final screen = await pumpGameRoute(tester, arguments: 'invalid');
      expect(screen.mode, GameMode.shift);
      expect(screen.session.mode, GameMode.shift);
      expect(screen.session.bot, isNull);
    });
  });
}
