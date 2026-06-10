import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/tiki_taka/data/local/daos/validation_dao.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_attribute.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_board.dart';
import 'package:shifttac/features/tiki_taka/data/models/tiki_player_search_result.dart';
import 'package:shifttac/features/tiki_taka/domain/logic/tiki_taka_game_engine.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_cell.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_state.dart';
import 'package:shifttac/features/tiki_taka/domain/models/tiki_game_status.dart';
import 'package:shifttac/features/tiki_taka/domain/services/answer_validator.dart';

import '../../support/tiki_taka_dao_test_support.dart';

const _salah = TikiPlayerSearchResult(
  id: 'tm:148455',
  displayName: 'Mohamed Salah',
  position: 'Right Winger',
  nation: 'Egypt',
);

const _kane = TikiPlayerSearchResult(
  id: 'tm:132098',
  displayName: 'Harry Kane',
  position: 'Centre-Forward',
  nation: 'England',
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

TikiGameState _ongoingState({int hearts = TikiGameState.startingHearts}) {
  final engine = TikiTakaGameEngine.instance;
  final loaded = engine.boardLoaded(engine.initial(), _testBoard());
  return loaded.copyWith(hearts: hearts);
}

TikiAnswerResult _attempt({
  required TikiGameState state,
  required int row,
  required int col,
  required TikiPlayerSearchResult player,
  required AnswerValidationResult validation,
}) {
  return TikiTakaGameEngine.instance.attemptAnswer(
    state: state,
    row: row,
    col: col,
    player: player,
    validation: validation,
  );
}

void main() {
  final engine = TikiTakaGameEngine.instance;

  group('TikiTakaGameEngine', () {
    test('starting hearts = 5', () {
      final state = engine.boardLoaded(engine.initial(), _testBoard());
      expect(state.hearts, 5);
      expect(TikiGameState.startingHearts, 5);
    });

    test('valid answer fills the selected cell', () {
      final result = _attempt(
        state: _ongoingState(),
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      );

      expect(result.accepted, isTrue);
      expect(result.state.cellAt(0, 0).player, _salah);
      expect(result.state.usedPlayerIds, {'tm:148455'});
    });

    test('invalid answer leaves cell empty and removes one heart', () {
      final result = _attempt(
        state: _ongoingState(),
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.invalid(
          AnswerValidationReason.playerNotMatching,
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.state.cellAt(0, 0).isEmpty, isTrue);
      expect(result.state.hearts, 4);
      expect(result.rejectionReason, AnswerValidationReason.playerNotMatching);
    });

    test('duplicate correct player does not remove a heart', () {
      final afterFirst = _attempt(
        state: _ongoingState(),
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      ).state;

      final duplicate = _attempt(
        state: afterFirst,
        row: 1,
        col: 1,
        player: _salah,
        validation: const AnswerValidationResult.invalid(
          AnswerValidationReason.duplicatePlayer,
        ),
      );

      expect(duplicate.accepted, isFalse);
      expect(duplicate.state.cellAt(1, 1).isEmpty, isTrue);
      expect(duplicate.state.hearts, 5);
      expect(duplicate.rejectionReason, AnswerValidationReason.duplicatePlayer);
    });

    test('duplicate wrong player removes one heart', () {
      final afterFirst = _attempt(
        state: _ongoingState(),
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      ).state;

      final duplicateWrong = _attempt(
        state: afterFirst,
        row: 1,
        col: 1,
        player: _salah,
        validation: const AnswerValidationResult.invalid(
          AnswerValidationReason.playerNotMatching,
        ),
      );

      expect(duplicateWrong.accepted, isFalse);
      expect(duplicateWrong.state.cellAt(1, 1).isEmpty, isTrue);
      expect(duplicateWrong.state.hearts, 4);
      expect(
        duplicateWrong.rejectionReason,
        AnswerValidationReason.playerNotMatching,
      );
    });

    test('occupied cell cannot be edited', () {
      final filled = _attempt(
        state: _ongoingState(),
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      ).state;

      final retry = _attempt(
        state: filled,
        row: 0,
        col: 0,
        player: _kane,
        validation: const AnswerValidationResult.valid(_kane),
      );

      expect(retry.accepted, isFalse);
      expect(retry.state.cellAt(0, 0).player, _salah);
      expect(retry.state.hearts, 5);
    });

    test('hearts reaching 0 produces lost', () {
      var state = _ongoingState(hearts: 1);

      final result = _attempt(
        state: state,
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.invalid(
          AnswerValidationReason.playerNotMatching,
        ),
      );

      expect(result.state.hearts, 0);
      expect(result.state.status, TikiGameStatus.lost);
    });

    test('first line produces firstWin', () {
      var state = _ongoingState();

      for (final col in [0, 1, 2]) {
        final player = TikiPlayerSearchResult(
          id: 'tm:test_$col',
          displayName: 'Player $col',
        );
        state = _attempt(
          state: state,
          row: 0,
          col: col,
          player: player,
          validation: AnswerValidationResult.valid(player),
        ).state;
      }

      expect(state.status, TikiGameStatus.firstWin);
      expect(
        state.winningLine,
        const [
          Position(row: 0, col: 0),
          Position(row: 0, col: 1),
          Position(row: 0, col: 2),
        ],
      );
      expect(state.filledCellCount, 3);
    });

    test('continue keeps existing board and cells', () {
      var state = _ongoingState();
      state = _attempt(
        state: state,
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      ).state;

      for (final col in [1, 2]) {
        final player = TikiPlayerSearchResult(
          id: 'tm:line_$col',
          displayName: 'Line $col',
        );
        state = _attempt(
          state: state,
          row: 0,
          col: col,
          player: player,
          validation: AnswerValidationResult.valid(player),
        ).state;
      }

      expect(state.status, TikiGameStatus.firstWin);

      final continued = engine.continuePlaying(state);

      expect(continued.status, TikiGameStatus.continuing);
      expect(continued.board, state.board);
      expect(continued.cells, state.cells);
      expect(continued.hearts, state.hearts);
      expect(continued.usedPlayerIds, state.usedPlayerIds);
      expect(continued.winningLine, isNull);
    });

    test('clearBoard empties cells and used players while keeping headers', () {
      var state = _ongoingState();
      state = _attempt(
        state: state,
        row: 0,
        col: 0,
        player: _salah,
        validation: const AnswerValidationResult.valid(_salah),
      ).state;

      final cleared = engine.clearBoard(state);

      expect(cleared, isNotNull);
      expect(cleared!.filledCellCount, 0);
      expect(cleared.usedPlayerIds, isEmpty);
      expect(cleared.winningLine, isNull);
      expect(cleared.status, TikiGameStatus.ongoing);
      expect(cleared.board, state.board);
      expect(cleared.hearts, state.hearts);
      expect(cleared.elapsed, state.elapsed);
    });

    test('clearBoard resets terminal statuses to ongoing', () {
      var state = _ongoingState().copyWith(
        status: TikiGameStatus.completed,
        cells: TikiCell.emptyBoard()
            .map(
              (cell) => cell.copyWith(
                player: TikiPlayerSearchResult(
                  id: 'tm:${cell.row}${cell.col}',
                  displayName: 'Player ${cell.row}${cell.col}',
                ),
              ),
            )
            .toList(growable: false),
        usedPlayerIds: const {'tm:00'},
      );

      final cleared = engine.clearBoard(state);

      expect(cleared, isNotNull);
      expect(cleared!.status, TikiGameStatus.ongoing);
      expect(cleared.filledCellCount, 0);
    });

    test('clearBoard is a no-op for an empty ongoing board', () {
      final state = _ongoingState();

      expect(engine.clearBoard(state), isNull);
    });

    test('completing all 9 cells produces completed', () {
      var state = _ongoingState();

      for (final col in [0, 1, 2]) {
        final player = TikiPlayerSearchResult(
          id: 'tm:top_$col',
          displayName: 'Top $col',
        );
        state = _attempt(
          state: state,
          row: 0,
          col: col,
          player: player,
          validation: AnswerValidationResult.valid(player),
        ).state;
      }

      expect(state.status, TikiGameStatus.firstWin);
      state = engine.continuePlaying(state);

      var playerIndex = 0;
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          if (state.cellAt(row, col).isFilled) {
            continue;
          }

          final player = TikiPlayerSearchResult(
            id: 'tm:fill_$playerIndex',
            displayName: 'Fill $playerIndex',
          );
          playerIndex++;
          state = _attempt(
            state: state,
            row: row,
            col: col,
            player: player,
            validation: AnswerValidationResult.valid(player),
          ).state;
        }
      }

      expect(state.filledCellCount, 9);
      expect(state.status, TikiGameStatus.completed);
    });

    test('completed takes priority over firstWin when the board is full', () {
      final usedIds = <String>{};
      final cells = TikiCell.emptyBoard().map((cell) {
        if (cell.row == 2 && cell.col == 2) {
          return cell;
        }

        final player = TikiPlayerSearchResult(
          id: 'tm:priority_${cell.row}_${cell.col}',
          displayName: 'Priority ${cell.row}-${cell.col}',
        );
        usedIds.add(player.id);
        return cell.copyWith(player: player);
      }).toList(growable: false);

      final state = _ongoingState().copyWith(
        cells: cells,
        usedPlayerIds: usedIds,
      );

      const lastPlayer = TikiPlayerSearchResult(
        id: 'tm:priority_last',
        displayName: 'Priority Last',
      );
      final result = _attempt(
        state: state,
        row: 2,
        col: 2,
        player: lastPlayer,
        validation: const AnswerValidationResult.valid(lastPlayer),
      );

      expect(result.state.filledCellCount, 9);
      expect(result.state.status, TikiGameStatus.completed);
      expect(result.state.status, isNot(TikiGameStatus.firstWin));
    });
  });

  group('AnswerValidator', () {
    late TikiTakaTestDatabaseHandle handle;
    late AnswerValidator validator;

    setUpAll(ensureTikiTakaDaoTestInit);

    setUp(() async {
      handle = await openTikiTakaTestDatabase();
      validator = AnswerValidator(ValidationDao(handle.database));
    });

    tearDown(() async {
      await handle.close();
    });

    test('validates Salah for Egypt x Liverpool', () async {
      final result = await validator.validate(
        playerId: '148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:31',
        usedPlayerIds: const {},
      );

      expect(result.isValid, isTrue);
      expect(result.player?.displayName, 'Mohamed Salah');
    });

    test('rejects Salah for Egypt x Dortmund', () async {
      final result = await validator.validate(
        playerId: '148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:16',
        usedPlayerIds: const {},
      );

      expect(result.isValid, isFalse);
      expect(result.reason, AnswerValidationReason.playerNotMatching);
    });

    test('rejects duplicate player when cell attributes still match', () async {
      final result = await validator.validate(
        playerId: 'tm:148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:31',
        usedPlayerIds: const {'tm:148455'},
      );

      expect(result.isValid, isFalse);
      expect(result.reason, AnswerValidationReason.duplicatePlayer);
    });

    test('rejects duplicate player as wrong when cell attributes do not match',
        () async {
      final result = await validator.validate(
        playerId: 'tm:148455',
        rowAttributeId: 'nation:egypt',
        colAttributeId: 'club:16',
        usedPlayerIds: const {'tm:148455'},
      );

      expect(result.isValid, isFalse);
      expect(result.reason, AnswerValidationReason.playerNotMatching);
    });
  });
}
