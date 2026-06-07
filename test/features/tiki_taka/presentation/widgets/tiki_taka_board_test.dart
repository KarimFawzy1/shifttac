import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_board.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_cell.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/board_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/player_search_dao.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import 'package:shifttac/features/tiki_taka/domain/services/answer_validator.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_board.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_cell.dart';

import '../../data/local/tiki_taka_dao_test_support.dart';

const _salah = TikiPlayerSearchResult(
  id: 'tm:148455',
  displayName: 'Mohamed Salah',
  position: 'Right Winger',
  nation: 'Egypt',
);

TikiBoard _testBoard() {
  return const TikiBoard(
    id: 'test_board',
    name: 'Test Board',
    minIntersection: 1,
    rowAttributes: [
      TikiAttribute(
        id: 'nation:egypt',
        type: 'nation',
        displayName: 'Egypt',
        slug: 'egypt',
        iconKey: 'nation_egypt',
      ),
      TikiAttribute(
        id: 'nation:england',
        type: 'nation',
        displayName: 'England',
        slug: 'england',
        iconKey: 'nation_england',
      ),
      TikiAttribute(
        id: 'nation:france',
        type: 'nation',
        displayName: 'France',
        slug: 'france',
        iconKey: 'nation_france',
      ),
    ],
    columnAttributes: [
      TikiAttribute(
        id: 'club:31',
        type: 'club',
        displayName: 'Liverpool',
        slug: 'liverpool',
        iconKey: 'club_31',
      ),
      TikiAttribute(
        id: 'club:16',
        type: 'club',
        displayName: 'Borussia Dortmund',
        slug: 'borussia-dortmund',
        iconKey: 'club_16',
      ),
      TikiAttribute(
        id: 'club:27',
        type: 'club',
        displayName: 'Bayern Munich',
        slug: 'bayern-munich',
        iconKey: 'club_27',
      ),
    ],
  );
}

Widget _wrap({
  required TikiTakaCubit cubit,
  required Widget child,
}) {
  return ScreenUtilInit(
    designSize: AppConstants.designSize,
    builder: (context, _) => MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: SizedBox(width: 360, height: 420, child: child),
        ),
      ),
    ),
  );
}

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return TikiTakaDependencies(
    boardDao: BoardDao(handle.database),
    playerSearchDao: PlayerSearchDao(handle.database),
    answerValidator: AnswerValidator(ValidationDao(handle.database)),
  );
}

TikiTakaCubit _cubitWithBoard(TikiTakaTestDatabaseHandle handle) {
  final engine = TikiTakaGameEngine.instance;
  final board = _testBoard();
  final game = engine.boardLoaded(engine.initial(), board);
  return TikiTakaCubit.forTest(
    dependencies: _dependencies(handle),
    initialState: TikiTakaState.initial(game),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;

  setUp(() async {
    databaseHandle = await openTikiTakaTestDatabase();
  });

  tearDown(() async {
    await databaseHandle.close();
  });

  group('TikiTakaCell', () {
    testWidgets('long player names scale down without overflow', (tester) async {
      const player = TikiPlayerSearchResult(
        id: 'tm:test',
        displayName: 'Christopher Alexander Montgomery-Williams',
        position: 'Forward',
        nation: 'England',
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: TikiTakaCell(
                    cell: const TikiCell(row: 0, col: 0, player: player),
                    interactive: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TikiTakaBoard', () {
    testWidgets('empty cell tap activates search on cubit', (tester) async {
      final cubit = _cubitWithBoard(databaseHandle);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _wrap(
          cubit: cubit,
          child: const TikiTakaBoard(),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Empty cell row 1 column 1'));
      await tester.pump();

      expect(cubit.state.activeCell, isNotNull);
      expect(cubit.state.activeCell, const TikiActiveCell(row: 0, col: 0));
    });

    testWidgets('occupied cell tap is explained', (tester) async {
      final engine = TikiTakaGameEngine.instance;
      final board = _testBoard();
      final cells = TikiCell.emptyBoard()
          .map(
            (cell) => cell.row == 0 && cell.col == 0
                ? cell.copyWith(player: _salah)
                : cell,
          )
          .toList();
      final cubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(databaseHandle),
        initialState: TikiTakaState.initial(
          engine.boardLoaded(engine.initial(), board).copyWith(cells: cells),
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _wrap(cubit: cubit, child: const TikiTakaBoard()),
      );
      await tester.pump();

      await tester.tap(find.text('Mohamed Salah'));
      await tester.pump();

      expect(cubit.state.activeCell, isNull);
      expect(find.text('This cell is already filled.'), findsOneWidget);
    });
  });
}
