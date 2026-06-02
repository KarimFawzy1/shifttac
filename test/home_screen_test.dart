import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/home/presentation/screens/home_screen.dart';

Widget _homeTestApp({AppSettingsController? settings}) {
  final appSettings = settings ?? AppSettingsController();
  return AppSettingsScope(
    settings: appSettings,
    child: AppAudioScope(
      audio: AppAudio(appSettings),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) => MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
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
    });
  });

  group('HomeScreen navigation', () {
    testWidgets('Play ShiftTac opens ShiftTac gameplay', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play ShiftTac'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(
        tester.widget<GameplayScreen>(find.byType(GameplayScreen)).mode,
        GameMode.shift,
      );
    });

    testWidgets('Play Classic opens classic gameplay', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play Classic'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GameplayScreen), findsOneWidget);
      expect(
        tester.widget<GameplayScreen>(find.byType(GameplayScreen)).mode,
        GameMode.classic,
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
      await tester.pump();

      expect(find.byType(GameplayScreen), findsOneWidget);
      final gameplay = tester.widget<GameplayScreen>(
        find.byType(GameplayScreen),
      );
      expect(gameplay.session.mode, GameMode.shift);
      expect(gameplay.session.bot?.difficulty, BotDifficulty.easy);
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
      await tester.pump();

      final gameplay = tester.widget<GameplayScreen>(
        find.byType(GameplayScreen),
      );
      expect(gameplay.session.mode, GameMode.classic);
      expect(gameplay.session.bot?.difficulty, BotDifficulty.easy);
    });
  });
}
