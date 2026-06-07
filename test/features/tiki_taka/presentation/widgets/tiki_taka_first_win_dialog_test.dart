import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_first_win_dialog.dart';

import 'tiki_taka_dialog_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;
  var continueTapped = false;
  var restartTapped = false;
  var goHomeTapped = false;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    resetTikiDialogVisibilityForTest();
    continueTapped = false;
    restartTapped = false;
    goHomeTapped = false;
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = seedTikiCubit(
      handle: databaseHandle,
      status: TikiGameStatus.firstWin,
      elapsed: const Duration(minutes: 2, seconds: 5),
      hearts: 4,
    );
    cubit.pauseTimer();
  });

  tearDown(() async {
    await cubit.close();
    await databaseHandle.close();
    resetTikiDialogVisibilityForTest();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapTikiDialogTest(
        cubit: cubit,
        child: TikiTakaFirstWinDialog.forTest(
          routeAnimation: const AlwaysStoppedAnimation<double>(1),
          elapsed: const Duration(minutes: 2, seconds: 5),
          hearts: 4,
          onContinue: () => continueTapped = true,
          onRestart: () => restartTapped = true,
          onGoHome: () => goHomeTapped = true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows win copy, stats, and actions', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Line complete!'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.text('Hearts remaining'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Continue Playing'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Go Home'), findsOneWidget);
  });

  testWidgets('continue action fires callback', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(TikiTakaFirstWinDialog.continueButtonKey));
    await tester.pump();

    expect(continueTapped, isTrue);
    expect(restartTapped, isFalse);
    expect(goHomeTapped, isFalse);
  });
}
