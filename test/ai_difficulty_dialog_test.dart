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

    Future<void> openClassicDialog(WidgetTester tester) async {
      await tester.tap(find.text('Open Classic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> openShiftDialog(WidgetTester tester) async {
      await tester.tap(find.text('Open Shift'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> tapDifficulty(
      WidgetTester tester,
      GameMode mode,
      BotDifficulty difficulty,
    ) async {
      final option = find.byKey(
        Key('ai-difficulty-${mode.name}-${difficulty.name}'),
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    Widget _host() {
      return Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => AiDifficultyDialog.show(
                      context,
                      mode: GameMode.classic,
                    ),
                    child: const Text('Open Classic'),
                  ),
                  ElevatedButton(
                    onPressed: () => AiDifficultyDialog.show(
                      context,
                      mode: GameMode.shift,
                    ),
                    child: const Text('Open Shift'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    testWidgets('classic mode shows classic difficulty copy', (tester) async {
      await pumpDialogHost(tester, _host());
      await openClassicDialog(tester);

      expect(
        find.byKey(const ValueKey('ai-difficulty-dialog-classic')),
        findsOneWidget,
      );
      expect(find.text('Choose Difficulty'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Random moves for relaxed practice.'), findsOneWidget);
      expect(find.text('Blocks threats and takes wins.'), findsOneWidget);
      expect(find.text('Optimal classic Tic Tac Toe.'), findsOneWidget);
    });

    testWidgets('shift mode shows ShiftTac difficulty copy', (tester) async {
      await pumpDialogHost(tester, _host());
      await openShiftDialog(tester);

      expect(
        find.byKey(const ValueKey('ai-difficulty-dialog-shift')),
        findsOneWidget,
      );
      expect(find.text('Random legal moves for relaxed practice.'), findsOneWidget);
      expect(
        find.text('Wins, blocks, and avoids obvious FIFO traps.'),
        findsOneWidget,
      );
      expect(
        find.text('Deep search with tactical evaluation.'),
        findsOneWidget,
      );
      expect(find.text('Optimal classic Tic Tac Toe.'), findsNothing);
    });

    testWidgets('Cancel does not navigate to gameplay', (tester) async {
      await pumpDialogHost(tester, _host());
      await openClassicDialog(tester);

      await tester.tap(find.byKey(const Key('ai-difficulty-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Difficulty'), findsNothing);
      expect(find.byType(GameplayScreen), findsNothing);
      expect(find.text('Open Classic'), findsOneWidget);
    });

    testWidgets('tapping Easy launches classic AI session', (tester) async {
      await pumpDialogHost(tester, _host());
      await openClassicDialog(tester);

      await tapDifficulty(tester, GameMode.classic, BotDifficulty.easy);

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
      await pumpDialogHost(tester, _host());
      await openClassicDialog(tester);

      await tapDifficulty(
        tester,
        GameMode.classic,
        BotDifficulty.intermediate,
      );

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.classic);
      expect(screen.session.bot!.difficulty, BotDifficulty.intermediate);
      expect(screen.session.startingPlayer, isIn([Player.x, Player.o]));
    });

    testWidgets('tapping Hard launches classic AI session', (tester) async {
      await pumpDialogHost(tester, _host());
      await openClassicDialog(tester);

      await tapDifficulty(tester, GameMode.classic, BotDifficulty.hard);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.classic);
      expect(screen.session.bot!.difficulty, BotDifficulty.hard);
      expect(screen.session.bot!.botPlayer, Player.o);
    });

    testWidgets('tapping Easy launches ShiftTac AI session', (tester) async {
      await pumpDialogHost(tester, _host());
      await openShiftDialog(tester);

      await tapDifficulty(tester, GameMode.shift, BotDifficulty.easy);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.isAiSession, isTrue);
      expect(screen.session.bot!.difficulty, BotDifficulty.easy);
    });

    testWidgets('tapping Intermediate launches ShiftTac AI session', (
      tester,
    ) async {
      await pumpDialogHost(tester, _host());
      await openShiftDialog(tester);

      await tapDifficulty(
        tester,
        GameMode.shift,
        BotDifficulty.intermediate,
      );

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.bot!.difficulty, BotDifficulty.intermediate);
    });

    testWidgets('tapping Hard launches ShiftTac AI session', (tester) async {
      await pumpDialogHost(tester, _host());
      await openShiftDialog(tester);

      await tapDifficulty(tester, GameMode.shift, BotDifficulty.hard);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.bot!.difficulty, BotDifficulty.hard);
    });
  });
}
