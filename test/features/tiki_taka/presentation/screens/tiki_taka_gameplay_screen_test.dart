import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/game/presentation/widgets/player_panel.dart';
import 'package:shifttac/features/game/presentation/widgets/player_turn_indicator.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/board_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/player_search_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import 'package:shifttac/features/tiki_taka/domain/services/answer_validator.dart';
import 'package:shifttac/features/tiki_taka/presentation/screens/tiki_taka_gameplay_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_header.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_board.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_cell.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_hud.dart';

import '../../data/local/tiki_taka_dao_test_support.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(home: child),
  );
}

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return TikiTakaDependencies(
    boardDao: BoardDao(handle.database),
    playerSearchDao: PlayerSearchDao(handle.database),
    answerValidator: AnswerValidator(ValidationDao(handle.database)),
  );
}

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    _wrap(
      SizedBox(
        width: AppConstants.designSize.width,
        height: AppConstants.designSize.height,
        child: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

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

  test('loadBoard supplies a real SQLite board for the screen', () {
    expect(cubit.state.game.board, isNotNull);
    expect(cubit.state.rowHeaders, hasLength(3));
    expect(cubit.state.columnHeaders, hasLength(3));
    expect(cubit.state.status.name, 'ongoing');
  });

  group('TikiTakaGameplayScreen', () {
    testWidgets('renders board with headers, hearts, and timer', (tester) async {
      await _pumpScreen(tester, TikiTakaGameplayScreen(cubit: cubit));

      expect(find.byType(TikiTakaBoard), findsOneWidget);
      expect(find.byType(TikiAttributeHeader), findsNWidgets(6));
      expect(find.byType(TikiTakaHud), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('does not show Classic or Shift turn UI', (tester) async {
      await _pumpScreen(tester, TikiTakaGameplayScreen(cubit: cubit));

      expect(find.byType(PlayerTurnIndicator), findsNothing);
      expect(find.byType(PlayerPanel), findsNothing);
      expect(find.textContaining('Moves:'), findsNothing);
    });

    testWidgets('empty cell tap opens search placeholder state', (tester) async {
      expect(cubit.onCellTapped(0, 0), TikiCellTapResult.openedSearch);

      await _pumpScreen(tester, TikiTakaGameplayScreen(cubit: cubit));

      expect(cubit.state.activeCell, isNotNull);
      expect(
        find.textContaining('Player search opens here'),
        findsOneWidget,
      );
    });
  });
}
