import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_lost_dialog.dart';

import '../../support/tiki_taka_dialog_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;
  var restartTapped = false;
  var goHomeTapped = false;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    resetTikiDialogVisibilityForTest();
    restartTapped = false;
    goHomeTapped = false;
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = seedTikiCubit(
      handle: databaseHandle,
      status: TikiGameStatus.lost,
      elapsed: const Duration(minutes: 1, seconds: 15),
      hearts: 0,
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
        child: TikiTakaLostDialog.forTest(
          routeAnimation: const AlwaysStoppedAnimation<double>(1),
          elapsed: const Duration(minutes: 1, seconds: 15),
          onRestart: () => restartTapped = true,
          onGoHome: () => goHomeTapped = true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows lost copy and zero hearts', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Out of hearts'), findsOneWidget);
    expect(find.text('1:15'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Go Home'), findsOneWidget);
  });

  testWidgets('go home action fires callback', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(TikiTakaLostDialog.goHomeButtonKey));
    await tester.pump();

    expect(goHomeTapped, isTrue);
    expect(restartTapped, isFalse);
  });
}
