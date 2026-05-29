import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/move.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/widgets/board_appearance_mapper.dart';
import 'package:shifttac/features/game/presentation/widgets/board_cell.dart';

GameSnapshot _shiftSnapshotWithFullQueue() {
  return GameSnapshot(
    xMoves: const [
      Move(
        player: Player.x,
        position: Position(row: 0, col: 0),
        turnIndex: 0,
      ),
      Move(
        player: Player.x,
        position: Position(row: 0, col: 1),
        turnIndex: 2,
      ),
      Move(
        player: Player.x,
        position: Position(row: 0, col: 2),
        turnIndex: 4,
      ),
    ],
    oMoves: const [
      Move(
        player: Player.o,
        position: Position(row: 1, col: 0),
        turnIndex: 1,
      ),
      Move(
        player: Player.o,
        position: Position(row: 1, col: 1),
        turnIndex: 3,
      ),
    ],
    currentPlayer: Player.x,
    turnIndex: 5,
    status: GameStatus.playing,
  );
}

GameSnapshot _classicSnapshotWithManyMarks() {
  return GameSnapshot(
    xMoves: const [
      Move(
        player: Player.x,
        position: Position(row: 0, col: 0),
        turnIndex: 0,
      ),
      Move(
        player: Player.x,
        position: Position(row: 0, col: 1),
        turnIndex: 2,
      ),
      Move(
        player: Player.x,
        position: Position(row: 0, col: 2),
        turnIndex: 4,
      ),
      Move(
        player: Player.x,
        position: Position(row: 1, col: 0),
        turnIndex: 6,
      ),
    ],
    oMoves: const [
      Move(
        player: Player.o,
        position: Position(row: 1, col: 1),
        turnIndex: 1,
      ),
      Move(
        player: Player.o,
        position: Position(row: 1, col: 2),
        turnIndex: 3,
      ),
      Move(
        player: Player.o,
        position: Position(row: 2, col: 0),
        turnIndex: 5,
      ),
    ],
    currentPlayer: Player.x,
    turnIndex: 7,
    status: GameStatus.playing,
  );
}

void main() {
  group('boardCellAppearanceFor — shift mode', () {
    test('shows faded oldest mark when shift queue is full', () {
      final snapshot = _shiftSnapshotWithFullQueue();
      expect(snapshot.xMoves.length, GameConstants.maxActiveMarks);

      final appearance = boardCellAppearanceFor(
        rules: ShiftGameEngine.instance,
        snapshot: snapshot,
        position: const Position(row: 0, col: 0),
      );

      expect(appearance, BoardCellAppearance.xFaded);
    });

    test('shows solid marks for non-oldest shift cells', () {
      final snapshot = _shiftSnapshotWithFullQueue();

      expect(
        boardCellAppearanceFor(
          rules: ShiftGameEngine.instance,
          snapshot: snapshot,
          position: const Position(row: 0, col: 2),
        ),
        BoardCellAppearance.xSolid,
      );
      expect(
        boardCellAppearanceFor(
          rules: ShiftGameEngine.instance,
          snapshot: snapshot,
          position: const Position(row: 1, col: 0),
        ),
        BoardCellAppearance.oSolid,
      );
    });
  });

  group('boardCellAppearanceFor — classic mode', () {
    test('never produces faded cells even with many marks', () {
      final snapshot = _classicSnapshotWithManyMarks();

      for (final row in [0, 1, 2]) {
        for (final col in [0, 1, 2]) {
          final appearance = boardCellAppearanceFor(
            rules: ClassicGameEngine.instance,
            snapshot: snapshot,
            position: Position(row: row, col: col),
          );
          expect(
            appearance,
            isNot(isIn([BoardCellAppearance.xFaded, BoardCellAppearance.oFaded])),
          );
        }
      }
    });

    test('maps occupied classic cells to solid marks only', () {
      final snapshot = _classicSnapshotWithManyMarks();

      expect(
        boardCellAppearanceFor(
          rules: ClassicGameEngine.instance,
          snapshot: snapshot,
          position: const Position(row: 0, col: 0),
        ),
        BoardCellAppearance.xSolid,
      );
      expect(
        boardCellAppearanceFor(
          rules: ClassicGameEngine.instance,
          snapshot: snapshot,
          position: const Position(row: 2, col: 1),
        ),
        BoardCellAppearance.empty,
      );
    });
  });

  group('isBoardFrozen', () {
    test('draw state freezes the board', () {
      expect(isBoardFrozen(GameStatus.draw), isTrue);
    });

    test('won state freezes the board', () {
      expect(isBoardFrozen(GameStatus.won), isTrue);
    });

    test('playing state allows input', () {
      expect(isBoardFrozen(GameStatus.playing), isFalse);
    });
  });
}
