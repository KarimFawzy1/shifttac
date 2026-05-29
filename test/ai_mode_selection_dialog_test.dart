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
import 'package:shifttac/features/home/presentation/widgets/ai_mode_selection_dialog.dart';

Widget _dialogTestApp({required Widget home}) {
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

Future<void> _openModeDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapDifficulty(
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

void main() {
  group('AiModeSelectionDialog', () {
    testWidgets('shows Classic and ShiftTac enabled', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);

      expect(find.text('Play vs AI'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Traditional 3x3 against the bot.'), findsOneWidget);
      expect(find.text('ShiftTac'), findsOneWidget);
      expect(
        find.text('Three active marks with FIFO rotation.'),
        findsOneWidget,
      );
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.byKey(const Key('ai-mode-classic')), findsOneWidget);
      expect(find.byKey(const Key('ai-mode-shift')), findsOneWidget);
    });

    testWidgets('ShiftTac opens difficulty dialog', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      expect(find.text('Choose Difficulty'), findsNothing);

      await tester.tap(find.byKey(const Key('ai-mode-shift')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('ai-difficulty-dialog-shift')),
        findsOneWidget,
      );
      expect(find.text('Choose Difficulty'), findsOneWidget);
      expect(
        find.text('Deep search with tactical evaluation.'),
        findsOneWidget,
      );
      expect(find.byType(GameplayScreen), findsNothing);
    });

    testWidgets('Classic advances to difficulty selection', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);

      await tester.tap(find.byKey(const Key('ai-mode-classic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('ai-difficulty-dialog-classic')),
        findsOneWidget,
      );
      expect(find.text('Choose Difficulty'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Optimal classic Tic Tac Toe.'), findsOneWidget);
      expect(find.byType(GameplayScreen), findsNothing);
    });

    testWidgets('Easy launches ShiftTac AI session', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      await tester.tap(find.byKey(const Key('ai-mode-shift')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDifficulty(tester, GameMode.shift, BotDifficulty.easy);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.isAiSession, isTrue);
      expect(screen.session.bot!.difficulty, BotDifficulty.easy);
      expect(screen.session.bot!.botPlayer, Player.o);
    });

    testWidgets('Intermediate launches ShiftTac AI session', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      await tester.tap(find.byKey(const Key('ai-mode-shift')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDifficulty(
        tester,
        GameMode.shift,
        BotDifficulty.intermediate,
      );

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.bot!.difficulty, BotDifficulty.intermediate);
    });

    testWidgets('Hard launches ShiftTac AI session', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      await tester.tap(find.byKey(const Key('ai-mode-shift')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDifficulty(tester, GameMode.shift, BotDifficulty.hard);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.shift);
      expect(screen.session.bot!.difficulty, BotDifficulty.hard);
    });

    testWidgets('Classic path still launches classic AI session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      await tester.tap(find.byKey(const Key('ai-mode-classic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _tapDifficulty(tester, GameMode.classic, BotDifficulty.easy);

      final screen = tester.widget<GameplayScreen>(find.byType(GameplayScreen));
      expect(screen.mode, GameMode.classic);
      expect(screen.session.isAiSession, isTrue);
      expect(screen.session.bot!.difficulty, BotDifficulty.easy);
    });

    testWidgets('Cancel closes without navigating to gameplay', (
      tester,
    ) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Traditional 3x3 against the bot.'), findsNothing);
      expect(find.byType(GameplayScreen), findsNothing);
    });

    testWidgets('difficulty Cancel returns without gameplay', (tester) async {
      await tester.pumpWidget(
        _dialogTestApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => AiModeSelectionDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openModeDialog(tester);
      await tester.tap(find.byKey(const Key('ai-mode-shift')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cancel = find.text('Cancel');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Choose Difficulty'), findsNothing);
      expect(find.byType(GameplayScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}
