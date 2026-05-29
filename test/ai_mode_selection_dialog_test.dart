import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
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
        builder: (context, child) => MaterialApp(home: home),
      ),
    ),
  );
}

void main() {
  group('AiModeSelectionDialog', () {
    testWidgets('shows Classic enabled and ShiftTac Coming Soon', (
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

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Play vs AI'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Traditional 3x3 against the bot.'), findsOneWidget);
      expect(find.text('ShiftTac'), findsOneWidget);
      expect(find.text('Coming Soon'), findsOneWidget);
      expect(
        find.text('AI for shifting marks will arrive later.'),
        findsOneWidget,
      );
    });

    testWidgets('ShiftTac option does not open difficulty dialog', (
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

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Difficulty'), findsNothing);

      await tester.tap(find.text('ShiftTac'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Difficulty'), findsNothing);
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

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Classic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose Difficulty'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.byType(GameplayScreen), findsNothing);
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

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Traditional 3x3 against the bot.'), findsNothing);
      expect(find.byType(GameplayScreen), findsNothing);
    });
  });
}
