import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_board.dart';

/// Bounded frame pumps for Tiki-Taka widget tests (T6+ hygiene).
Future<void> pumpTikiFrames(
  WidgetTester tester, {
  int frameCount = 2,
  Duration frameDuration = const Duration(milliseconds: 100),
}) async {
  for (var frame = 0; frame < frameCount; frame++) {
    await tester.pump(frameDuration);
  }
}

/// Waits for [TikiTakaBoard] with a capped retry loop; fails fast when absent.
Future<void> waitForTikiBoard(
  WidgetTester tester, {
  int maxAttempts = 30,
  Duration step = const Duration(milliseconds: 200),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (find.byType(TikiTakaBoard).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }
  fail('TikiTakaBoard did not appear after $maxAttempts attempts');
}

Widget wrapTikiGameplayScreen(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: SizedBox(
        width: AppConstants.designSize.width,
        height: AppConstants.designSize.height,
        child: child,
      ),
    ),
  );
}
