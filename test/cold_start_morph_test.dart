import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/launch/app_launch_gate.dart';
import 'package:shifttac/core/launch/app_launch_prefs.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/routing/morph_page_route.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';

/// Regression: first Home → Gameplay tap after cold start must use [MorphPageRoute].
void main() {
  testWidgets('first tap after launch gate uses MorphPageRoute', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppLaunchPrefs.hasCompletedOnboardingKey: true,
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final settings = AppSettingsController();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: AppAudioScope(
          audio: AppAudio(settings),
          child: ScreenUtilInit(
            designSize: AppConstants.designSize,
            builder: (context, child) => MaterialApp(
              onGenerateRoute: AppRouter.onGenerateRoute,
              home: const AppLaunchGate(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    expect(find.text('Play ShiftTac'), findsOneWidget);

    await tester.tap(find.text('Play ShiftTac'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 550));
    while (tester.takeException() != null) {}

    expect(find.byType(GameplayScreen), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(GameplayScreen)));
    expect(route, isA<MorphPageRoute<void>>());
    expect(route, isNot(isA<MaterialPageRoute<void>>()));
  });
}
