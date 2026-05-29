import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/home/presentation/widgets/ai_difficulty_dialog.dart';

Widget _difficultyDialogTestApp({required Widget home}) {
  final settings = AppSettingsController();
  return AppSettingsScope(
    settings: settings,
    child: AppAudioScope(
      audio: AppAudio(settings),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) => MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: home,
        ),
      ),
    ),
  );
}

void main() {
  group('AiDifficultyDialog', () {
    Future<void> pumpDialogHost(WidgetTester tester, Widget home) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_difficultyDialogTestApp(home: home));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Easy, Intermediate, and Hard', (tester) async {
      await pumpDialogHost(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDifficultyDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Difficulty'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Random moves for relaxed practice.'), findsOneWidget);
      expect(find.text('Blocks threats and takes wins.'), findsOneWidget);
      expect(find.text('Optimal classic Tic Tac Toe.'), findsOneWidget);
    });

    testWidgets('Cancel does not navigate to gameplay', (tester) async {
      await pumpDialogHost(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDifficultyDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('ai-difficulty-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Difficulty'), findsNothing);
      expect(find.byType(GameplayScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('tapping Easy launches classic AI session', (tester) async {
      await pumpDialogHost(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDifficultyDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final easyOption = find.ancestor(
        of: find.text('Easy'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(easyOption);
      await tester.tap(easyOption);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.classic);
      expect(screen.session.isAiSession, isTrue);
      expect(screen.session.bot!.difficulty, BotDifficulty.easy);
      expect(screen.session.bot!.botPlayer, Player.o);
      expect(screen.session.startingPlayer, isIn([Player.x, Player.o]));
    });

    testWidgets('tapping Intermediate launches classic AI session', (
      tester,
    ) async {
      await pumpDialogHost(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDifficultyDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final intermediateOption = find.ancestor(
        of: find.text('Intermediate'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(intermediateOption);
      await tester.tap(intermediateOption);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.session.bot!.difficulty, BotDifficulty.intermediate);
      expect(screen.session.startingPlayer, isIn([Player.x, Player.o]));
    });

    testWidgets('tapping Hard launches classic AI session', (tester) async {
      await pumpDialogHost(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => AiDifficultyDialog.show(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final hardOption = find.ancestor(
        of: find.text('Hard'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(hardOption);
      await tester.tap(hardOption);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.session.bot!.difficulty, BotDifficulty.hard);
      expect(screen.session.bot!.botPlayer, Player.o);
    });
  });
}
