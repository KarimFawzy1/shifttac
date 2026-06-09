import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_state.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_hud.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('TikiTakaHud', () {
    test('formatElapsed renders mm:ss under one hour', () {
      expect(
        TikiTakaHud.formatElapsed(const Duration(minutes: 2, seconds: 5).inMilliseconds),
        '02:05',
      );
      expect(TikiTakaHud.formatElapsed(0), '00:00');
      expect(
        TikiTakaHud.formatElapsed(const Duration(minutes: 59, seconds: 59).inMilliseconds),
        '59:59',
      );
    });

    test('formatElapsed renders hh:mm:ss at and after one hour', () {
      expect(
        TikiTakaHud.formatElapsed(const Duration(hours: 1).inMilliseconds),
        '01:00:00',
      );
      expect(
        TikiTakaHud.formatElapsed(
          const Duration(hours: 1, minutes: 23, seconds: 45).inMilliseconds,
        ),
        '01:23:45',
      );
    });

    testWidgets('shows hearts and timer with fixture values', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TikiTakaHud(
            hearts: 3,
            elapsedMs: 125_000,
            maxHearts: TikiGameState.startingHearts,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsNWidgets(3));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
      expect(find.text('02:05'), findsOneWidget);
      expect(find.textContaining('02:05'), findsOneWidget);
    });
  });
}
