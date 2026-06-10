import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/widgets/player_panel.dart';
import 'package:shifttac/features/game/presentation/widgets/player_turn_indicator.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/domain/services/answer_validator.dart';
import 'package:shifttac/features/tiki_taka/presentation/screens/tiki_taka_gameplay_screen.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_cubit.dart';
import 'package:shifttac/features/tiki_taka/presentation/state/tiki_taka_state.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_attribute_header.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/player_search_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_board.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_first_win_dialog.dart';
import 'package:shifttac/features/tiki_taka/presentation/widgets/tiki_taka_hud.dart';
import 'package:shifttac/shared/widgets/board_winning_line_overlay.dart';

import '../../support/tiki_taka_dao_test_support.dart';
import '../../support/tiki_taka_widget_test_support.dart';

TikiTakaDependencies _dependencies(TikiTakaTestDatabaseHandle handle) {
  return tikiTakaTestDependencies(handle);
}

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(wrapTikiGameplayScreen(child));
  await pumpTikiFrames(
    tester,
    frameCount: 5,
    frameDuration: const Duration(milliseconds: 100),
  );
  await waitForTikiBoard(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TikiTakaTestDatabaseHandle databaseHandle;
  late TikiTakaCubit cubit;

  setUp(() async {
    PlayerSearchDialog.resetVisibilityForTest();
    databaseHandle = await openTikiTakaTestDatabase();
    cubit = TikiTakaCubit(dependencies: _dependencies(databaseHandle));
    await cubit.loadBoard();
    cubit.pauseTimer();
  });

  tearDown(() async {
    cubit.closeSearch();
    PlayerSearchDialog.resetVisibilityForTest();
    await cubit.close();
    await databaseHandle.close();
  });

  group('TikiTakaGameplayScreen regression pack', () {
    test('loadBoard supplies a real SQLite board for the screen', () {
      expect(cubit.state.game.board, isNotNull);
      expect(cubit.state.rowHeaders, hasLength(3));
      expect(cubit.state.columnHeaders, hasLength(3));
      expect(cubit.state.status.name, 'ongoing');
    });

    testWidgets('regression pack: board UI and empty cell opens search', (
      tester,
    ) async {
      await _pumpScreen(tester, TikiTakaGameplayScreen(cubit: cubit));

      expect(find.byType(TikiTakaBoard), findsOneWidget);
      expect(find.byType(TikiAttributeHeader), findsNWidgets(6));
      expect(find.byType(TikiTakaHud), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));
      expect(find.text('00:00'), findsOneWidget);
      expect(find.byType(PlayerTurnIndicator), findsNothing);
      expect(find.byType(PlayerPanel), findsNothing);
      expect(find.textContaining('Moves:'), findsNothing);

      final emptyCell = find.bySemanticsLabel('Empty cell row 1 column 1');
      expect(emptyCell, findsOneWidget);

      await tester.tap(emptyCell);
      await pumpTikiFrames(
        tester,
        frameCount: 5,
        frameDuration: const Duration(milliseconds: 60),
      );

      expect(cubit.state.activeCell, isNotNull);
      expect(find.text('Find a player'), findsOneWidget);
      expect(PlayerSearchDialog.isVisible, isTrue);
    });

    testWidgets('clear board button empties filled cells on the same board', (
      tester,
    ) async {
      final board = cubit.state.game.board!;
      await cubit.close();

      const player = TikiPlayerSearchResult(
        id: 'tm:test_clear',
        displayName: 'Test Clear',
      );
      final engine = TikiTakaGameEngine.instance;
      final game = engine
          .attemptAnswer(
            state: engine.boardLoaded(engine.initial(), board),
            row: 0,
            col: 0,
            player: player,
            validation: const AnswerValidationResult.valid(player),
          )
          .state;

      cubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(databaseHandle),
        initialState: TikiTakaState.initial(game),
      );
      cubit.pauseTimer();

      await tester.pumpWidget(
        wrapTikiGameplayScreen(TikiTakaGameplayScreen(cubit: cubit)),
      );
      await pumpTikiFrames(
        tester,
        frameCount: 5,
        frameDuration: const Duration(milliseconds: 100),
      );

      expect(cubit.state.canClearBoard, isTrue);
      expect(find.byKey(const Key('tiki_clear_board')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tiki_clear_board')));
      await pumpTikiFrames(
        tester,
        frameCount: 3,
        frameDuration: const Duration(milliseconds: 60),
      );

      expect(cubit.state.game.board, board);
      expect(cubit.state.game.filledCellCount, 0);
      expect(cubit.state.canClearBoard, isFalse);

      cubit.pauseTimer();
    });

    testWidgets('first-win dialog waits for board line reveal', (tester) async {
      TikiTakaFirstWinDialog.resetVisibilityForTest();

      final engine = TikiTakaGameEngine.instance;
      final board = cubit.state.game.board!;
      await cubit.close();

      final game = engine.boardLoaded(engine.initial(), board).copyWith(
        status: TikiGameStatus.firstWin,
        winningLine: const [
          Position(row: 0, col: 0),
          Position(row: 0, col: 1),
          Position(row: 0, col: 2),
        ],
      );

      cubit = TikiTakaCubit.forTest(
        dependencies: _dependencies(databaseHandle),
        initialState: TikiTakaState.initial(game),
      );
      cubit.pauseTimer();

      await tester.pumpWidget(
        wrapTikiGameplayScreen(TikiTakaGameplayScreen(cubit: cubit)),
      );
      await waitForTikiBoard(tester);

      expect(find.text('Line complete!'), findsNothing);

      await tester.pumpAndSettle();
      await tester.pump(kTikiFirstWinLineSettleDuration);

      expect(find.text('Line complete!'), findsOneWidget);
    });
  });
}
