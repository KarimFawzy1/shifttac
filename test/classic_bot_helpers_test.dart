import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/classic_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

GameSnapshot _apply(GameSnapshot snapshot, Position position) {
  final result = ClassicGameEngine.instance.attemptMove(
    snapshot: snapshot,
    position: position,
  );
  expect(result.moveAccepted, isTrue);
  return result.snapshot;
}

void main() {
  group('occupiedPositions', () {
    test('includes X and O marks', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));

      final occupied = occupiedPositions(snapshot);
      expect(occupied, {
        const Position(row: 0, col: 0),
        const Position(row: 1, col: 1),
      });
    });
  });

  group('availablePositions', () {
    test('returns all cells in stable order on an empty board', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      expect(availablePositions(snapshot), classicStableMoveOrder);
      expect(availablePositions(snapshot).length, GameConstants.boardCellCount);
    });

    test('excludes occupied cells', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));

      final available = availablePositions(snapshot);
      expect(available, isNot(contains(const Position(row: 1, col: 1))));
      expect(available.length, GameConstants.boardCellCount - 1);
    });

    test('returns empty on a full board', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 2));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));
      snapshot = _apply(snapshot, const Position(row: 0, col: 2));
      snapshot = _apply(snapshot, const Position(row: 2, col: 1));
      snapshot = _apply(snapshot, const Position(row: 1, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 2));
      expect(snapshot.status, GameStatus.draw);
      expect(availablePositions(snapshot), isEmpty);
    });
  });

  group('sortPositionsStable', () {
    test('orders arbitrary positions by classicStableMoveOrder', () {
      const input = [
        Position(row: 2, col: 1),
        Position(row: 0, col: 0),
        Position(row: 1, col: 1),
      ];
      expect(
        sortPositionsStable(input),
        [
          const Position(row: 1, col: 1),
          const Position(row: 0, col: 0),
          const Position(row: 2, col: 1),
        ],
      );
    });
  });

  group('simulateClassicMove', () {
    test('does not mutate the input snapshot', () {
      final before = GameSnapshot.initial(startingPlayer: Player.x);
      final result = simulateClassicMove(
        snapshot: before,
        position: const Position(row: 1, col: 1),
      );
      expect(result.moveAccepted, isTrue);
      expect(before.xMoves, isEmpty);
      expect(result.snapshot.xMoves.length, 1);
    });
  });

  group('findImmediateWin', () {
    test('returns winning cell when player can win now', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));

      expect(snapshot.currentPlayer, Player.x);
      expect(
        findImmediateWin(snapshot: snapshot, player: Player.x),
        const Position(row: 0, col: 2),
      );
    });

    test('returns null when it is not the player turn', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      expect(
        findImmediateWin(snapshot: snapshot, player: Player.o),
        isNull,
      );
    });
  });
}
