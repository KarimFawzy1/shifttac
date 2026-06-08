import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

GameSnapshot _applyShift(GameSnapshot snapshot, int row, int col) {
  return ShiftGameEngine.instance
      .attemptMove(
        snapshot: snapshot,
        position: Position(row: row, col: col),
      )
      .snapshot;
}

void main() {
  group('shiftOccupiedPositions / shiftAvailablePositions', () {
    test('occupied includes both players active marks', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 1, 1);
      s = _applyShift(s, 2, 2);

      final occupied = shiftOccupiedPositions(s);
      expect(
        occupied,
        {
          const Position(row: 0, col: 0),
          const Position(row: 1, col: 1),
          const Position(row: 2, col: 2),
        },
      );
    });

    test('available excludes occupied cells in stable order', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 1, 1);

      final available = shiftAvailablePositions(s);
      expect(available, isNot(contains(const Position(row: 1, col: 1))));
      expect(available.first, const Position(row: 0, col: 0));
      expect(available.length, GameConstants.boardCellCount - 1);
    });

    test('stable ordering is deterministic', () {
      expect(shiftStableMoveOrder, shiftStableMoveOrder);
      expect(
        sortShiftPositionsStable([
          const Position(row: 2, col: 1),
          const Position(row: 1, col: 1),
          const Position(row: 0, col: 0),
        ]),
        [
          const Position(row: 1, col: 1),
          const Position(row: 0, col: 0),
          const Position(row: 2, col: 1),
        ],
      );
    });
  });

  group('simulateShiftMove', () {
    test('does not mutate the input snapshot', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 2, 2);
      s = _applyShift(s, 0, 1);
      s = _applyShift(s, 1, 2);
      s = _applyShift(s, 2, 0);
      s = _applyShift(s, 1, 1);

      final before = s;
      final result = simulateShiftMove(
        snapshot: s,
        position: const Position(row: 0, col: 2),
      );

      expect(identical(before, s), isTrue);
      expect(result.moveAccepted, isTrue);
      expect(result.removedMove?.position, const Position(row: 0, col: 0));
      expect(result.placedMove?.position, const Position(row: 0, col: 2));
      expect(s.xMoves.length, GameConstants.maxActiveMarks);
    });

    test('removes oldest mark when placing fourth active mark', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 2, 2);
      s = _applyShift(s, 0, 1);
      s = _applyShift(s, 1, 2);
      s = _applyShift(s, 2, 0);
      s = _applyShift(s, 1, 1);

      final result = simulateShiftMove(
        snapshot: s,
        position: const Position(row: 0, col: 2),
      );

      expect(result.snapshot.xMoves.map((m) => m.position), const [
        Position(row: 0, col: 1),
        Position(row: 2, col: 0),
        Position(row: 0, col: 2),
      ]);
    });
  });

  group('findShiftImmediateWin / findShiftImmediateThreat', () {
    test('detects win after FIFO removal and placement', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 2, 2);
      s = _applyShift(s, 1, 0);
      s = _applyShift(s, 0, 2);
      s = _applyShift(s, 1, 1);
      s = _applyShift(s, 2, 0);

      expect(s.currentPlayer, Player.x);
      expect(s.status, GameStatus.playing);

      final win = findShiftImmediateWin(snapshot: s, player: Player.x);
      expect(win, const Position(row: 1, col: 2));
      expect(
        shiftWinningMovesFor(snapshot: s, player: Player.x),
        [const Position(row: 1, col: 2)],
      );
      expect(countImmediateWinsFor(snapshot: s, player: Player.x), 1);

      final result = simulateShiftMove(
        snapshot: s,
        position: const Position(row: 1, col: 2),
      );
      expect(result.removedMove?.position, const Position(row: 0, col: 0));
      expect(result.snapshot.status, GameStatus.won);
      expect(result.snapshot.winner, Player.x);
    });

    test('detects opponent immediate win as a threat to block', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 1, 0);
      s = _applyShift(s, 0, 1);
      s = _applyShift(s, 2, 2);

      expect(s.currentPlayer, Player.x);
      expect(
        findShiftImmediateThreat(
          snapshot: s,
          threateningPlayer: Player.x,
        ),
        const Position(row: 0, col: 2),
      );
      expect(
        findShiftImmediateWin(snapshot: s, player: Player.x),
        const Position(row: 0, col: 2),
      );
    });

    test('allowsOpponentImmediateWin mirrors post-move threat detection', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 0, 1);
      s = _applyShift(s, 1, 0);
      s = _applyShift(s, 1, 1);
      s = _applyShift(s, 2, 2);

      const bot = Player.o;
      for (final candidate in shiftAvailablePositions(s)) {
        final result = simulateShiftMove(snapshot: s, position: candidate);
        expect(result.moveAccepted, isTrue);

        final opponentCanWinNext = findShiftImmediateThreat(
              snapshot: result.snapshot,
              threateningPlayer: bot.opponent,
            ) !=
            null;

        expect(
          allowsOpponentImmediateWin(
            snapshot: s,
            candidate: candidate,
            botPlayer: bot,
          ),
          opponentCanWinNext,
        );
      }
    });

    test('returns null when game is not playing', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyShift(s, 0, 0);
      s = _applyShift(s, 1, 0);
      s = _applyShift(s, 0, 1);
      s = _applyShift(s, 2, 2);
      s = _applyShift(s, 0, 2);

      expect(s.status, GameStatus.won);
      expect(
        findShiftImmediateWin(snapshot: s, player: Player.x),
        isNull,
      );
      expect(
        findShiftImmediateThreat(
          snapshot: s,
          threateningPlayer: Player.o,
        ),
        isNull,
      );
    });
  });

  group('firstAvailableInShiftOrder', () {
    test('returns first empty cell from custom order', () {
      final s = GameSnapshot.initial(startingPlayer: Player.x);
      expect(
        firstAvailableInShiftOrder(s, shiftCornerPositions),
        const Position(row: 0, col: 0),
      );
    });
  });
}
