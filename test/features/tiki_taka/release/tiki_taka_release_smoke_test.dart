import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/presentation/widgets/player_turn_indicator.dart';
import 'package:shifttac/features/tiki_taka/presentation/screens/tiki_taka_entry_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_board.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_hud.dart';

import '../support/tiki_taka_dao_test_support.dart';
import '../support/tiki_taka_widget_test_support.dart';

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return tikiTakaTestDependencies(handle);
}

/// Release-gate smoke: offline local DB → entry → playable board (T6+ hygiene).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;

  setUp(() async {
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = TikiTakaCubit(dependencies: _dependencies(databaseHandle));
    await cubit.loadBoard();
    cubit.pauseTimer();
  });

  tearDown(() async {
    await cubit.close();
    await databaseHandle.close();
  });

  testWidgets('offline release smoke loads board through entry screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapTikiGameplayScreen(
        TikiTakaEntryScreen(cubit: cubit),
      ),
    );
    await pumpTikiFrames(
      tester,
      frameCount: 5,
      frameDuration: const Duration(milliseconds: 100),
    );
    await waitForTikiBoard(tester);

    expect(find.byType(TikiTakaBoard), findsOneWidget);
    expect(find.byType(TikiTakaHud), findsOneWidget);
    expect(find.byType(PlayerTurnIndicator), findsNothing);
    expect(find.textContaining('http'), findsNothing);
  });
}
