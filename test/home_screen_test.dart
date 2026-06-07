import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/core/routing/morph_page_route.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/home/presentation/screens/home_screen.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

Widget _homeTestApp({
  AppSettingsController? settings,
  List<NavigatorObserver> observers = const [],
}) {
  final appSettings = settings ?? AppSettingsController();
  return AppSettingsScope(
    settings: appSettings,
    child: AppAudioScope(
      audio: AppAudio(appSettings),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) => MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: observers,
          home: const HomeScreen(),
        ),
      ),
    ),
  );
}

void main() {
  group('HomeScreen copy', () {
    testWidgets('mode cards describe ShiftTac vs Classic', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Only 3 active marks — your oldest shifts off the board.'),
        findsOneWidget,
      );
      expect(
        find.text('Traditional 3x3. Every mark stays on the board.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Football knowledge on a 3×3 board. Name the player, win the line.',
        ),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen navigation', () {
    MorphPageRoute<void>? gameplayMorphRoute(WidgetTester tester) {
      final element = tester.element(find.byType(GameplayScreen));
      final route = ModalRoute.of(element);
      return route is MorphPageRoute<void> ? route : null;
    }

    testWidgets('Play Tiki-Taka morphs into tiki-taka route', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(_homeTestApp(observers: [observer]));
      await tester.pumpAndSettle();

      final playTikiTaka = find.text('Play Tiki-Taka');
      await tester.ensureVisible(playTikiTaka);
      await tester.pumpAndSettle();
      await tester.tap(playTikiTaka);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(observer.lastPushed, isNotNull);
      expect(observer.lastPushed!.settings.name, AppRoutes.tikiTaka);
      expect(find.byType(GameplayScreen), findsNothing);
    });

    testWidgets('Play ShiftTac morphs into ShiftTac gameplay', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play ShiftTac'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(
        tester.widget<GameplayScreen>(find.byType(GameplayScreen)).mode,
        GameMode.shift,
      );
      final route = gameplayMorphRoute(tester);
      expect(route, isNotNull);
      expect(route!.settings.name, AppRoutes.game);
    });

    testWidgets('Play Classic morphs into classic gameplay', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play Classic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(
        tester.widget<GameplayScreen>(find.byType(GameplayScreen)).mode,
        GameMode.classic,
      );
      final route = gameplayMorphRoute(tester);
      expect(route, isNotNull);
      expect(route!.settings.arguments, GameMode.classic);
    });

    testWidgets('Play Tiki-Taka is tappable and has no Coming Soon badge', (
      tester,
    ) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      final playTikiTaka = find.text('Play Tiki-Taka');
      await tester.ensureVisible(playTikiTaka);

      expect(playTikiTaka, findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);
      expect(
        find.ancestor(
          of: playTikiTaka,
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Play Classic is tappable and has no Coming Soon badge', (
      tester,
    ) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Play Classic'), findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);

      expect(
        find.ancestor(
          of: find.text('Play Classic'),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('VS AI has in-card pills and opens AI gameplay', (
      tester,
    ) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      expect(find.text('VS AI'), findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.byKey(const Key('ai-pill-mode')), findsOneWidget);
      expect(find.byKey(const Key('ai-pill-difficulty')), findsOneWidget);

      final playVsAi = find.text('VS AI');
      await tester.ensureVisible(playVsAi);
      await tester.pumpAndSettle();
      await tester.tap(playVsAi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(GameplayScreen), findsOneWidget);
      final gameplay = tester.widget<GameplayScreen>(
        find.byType(GameplayScreen),
      );
      expect(gameplay.session.mode, GameMode.shift);
      expect(gameplay.session.bot?.difficulty, BotDifficulty.easy);
      expect(gameplayMorphRoute(tester), isNotNull);
    });

    testWidgets('AI pills update defaults and only one pill opens', (
      tester,
    ) async {
      final settings = AppSettingsController();
      await tester.pumpWidget(_homeTestApp(settings: settings));
      await tester.pumpAndSettle();

      final playVsAi = find.text('VS AI');
      await tester.ensureVisible(playVsAi);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ai-pill-mode')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-option-classic')), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ai-pill-difficulty')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-option-classic')), findsNothing);
      expect(find.byKey(const Key('ai-option-easy')), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      settings.setAiGameMode(GameMode.classic);

      await tester.tap(playVsAi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final gameplay = tester.widget<GameplayScreen>(
        find.byType(GameplayScreen),
      );
      expect(gameplay.session.mode, GameMode.classic);
      expect(gameplay.session.bot?.difficulty, BotDifficulty.easy);
      expect(gameplayMorphRoute(tester), isNotNull);
    });
  });
}
