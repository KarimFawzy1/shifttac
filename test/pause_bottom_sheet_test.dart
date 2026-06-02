import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/routing/app_routes.dart';
import 'package:shifttac/core/routing/morph_page_route.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';
import 'package:shifttac/features/game/presentation/widgets/pause_bottom_sheet.dart';
import 'package:shifttac/features/settings/presentation/screens/settings_screen.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

Widget _pauseTestApp({
  required GameCubit cubit,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  final settings = AppSettingsController();
  return AppSettingsScope(
    settings: settings,
    child: AppAudioScope(
      audio: AppAudio(settings),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) => MaterialApp(
          navigatorObservers: navigatorObservers,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: BlocProvider.value(
            value: cubit,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => PauseBottomSheet.show(context),
                    child: const Text('open pause'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _stopMatchTicker(GameCubit cubit) {
  if (!cubit.isClosed) {
    cubit.pauseMatch();
  }
}

Future<void> _openPauseSheet(WidgetTester tester) async {
  await tester.tap(find.text('open pause'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.text('Paused'), findsOneWidget);
}

void main() {
  group('PauseBottomSheet morph navigation', () {
    testWidgets('Settings morphs from menu tile and resumes match after return', (
      tester,
    ) async {
      final cubit = GameCubit.shift();
      addTearDown(() {
        _stopMatchTicker(cubit);
        cubit.close();
      });
      final observer = _RecordingNavigatorObserver();

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _pauseTestApp(cubit: cubit, navigatorObservers: [observer]),
      );
      await tester.pump();

      await _openPauseSheet(tester);

      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Paused'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(observer.lastPushed, isA<MorphPageRoute<void>>());
      expect(observer.lastPushed!.settings.name, AppRoutes.settings);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SettingsScreen), findsNothing);
      _stopMatchTicker(cubit);
    });

    testWidgets('Resume still closes the sheet without morph navigation', (
      tester,
    ) async {
      final cubit = GameCubit.shift();
      addTearDown(() {
        _stopMatchTicker(cubit);
        cubit.close();
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_pauseTestApp(cubit: cubit));
      await tester.pump();

      await _openPauseSheet(tester);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Paused'), findsNothing);
      expect(find.text('open pause'), findsOneWidget);
      _stopMatchTicker(cubit);
    });
  });
}
