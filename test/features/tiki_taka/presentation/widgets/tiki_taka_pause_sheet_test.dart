import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_state.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_pause_sheet.dart';

import 'tiki_taka_dialog_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;
  late NavigatorState navigator;

  setUpAll(ensureTikiTakaDaoTestInit);

  setUp(() async {
    resetTikiDialogVisibilityForTest();
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = seedTikiCubit(
      handle: databaseHandle,
      status: TikiGameStatus.ongoing,
    );
    cubit.pauseTimer();
  });

  tearDown(() async {
    await cubit.close();
    await databaseHandle.close();
    resetTikiDialogVisibilityForTest();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    final resumeTimerOnClose = ValueNotifier(true);
    addTearDown(resumeTimerOnClose.dispose);

    await tester.pumpWidget(
      wrapTikiDialogTest(
        cubit: cubit,
        child: Builder(
          builder: (context) {
            navigator = Navigator.of(context);
            return TikiTakaPauseSheet.forTest(
              cubit: cubit,
              navigator: navigator,
              sheetContext: context,
              resumeTimerOnClose: resumeTimerOnClose,
              routeAnimation: const AlwaysStoppedAnimation<double>(1),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows pause actions', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Restart Match'), findsOneWidget);
    expect(find.text('Exit to Home'), findsOneWidget);
  });

  testWidgets('restart tile invokes restart path', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(TikiTakaPauseSheet.restartButtonKey));
    await tester.pump();
    cubit.pauseTimer();

    expect(cubit.state.status, TikiGameStatus.ongoing);
    expect(cubit.state.hearts, 5);
    expect(cubit.state.game.filledCellCount, 0);
  });
}
