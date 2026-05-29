import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/home/presentation/screens/home_screen.dart';

Widget _homeTestApp() {
  final settings = AppSettingsController();
  return AppSettingsScope(
    settings: settings,
    child: AppAudioScope(
      audio: AppAudio(settings),
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

      expect(find.text('Coming Soon'), findsOneWidget);

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
      expect(find.text('Coming Soon'), findsOneWidget);

      expect(
        find.ancestor(
          of: find.text('Play Classic'),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Play vs AI remains disabled with Coming Soon', (tester) async {
      await tester.pumpWidget(_homeTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Play vs AI'), findsOneWidget);
      expect(find.text('Coming Soon'), findsOneWidget);

      final aiTitle = find.text('Play vs AI');
      expect(
        find.ancestor(of: aiTitle, matching: find.byType(InkWell)),
        findsNothing,
      );
    });
  });
}
