import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

GameSnapshot _applyClassic(GameSnapshot s, int row, int col) {
  final r = ClassicGameEngine.instance.attemptMove(
    snapshot: s,
    position: Position(row: row, col: col),
  );
  expect(r.moveAccepted, isTrue, reason: 'classic move ($row,$col)');
  expect(r.removedMove, isNull);
  return r.snapshot;
}

void main() {
  group('ClassicGameEngine.initial', () {
    test('starts with the expected player when specified', () {
      final s = ClassicGameEngine.instance.initial();
      expect(s.status, GameStatus.playing);
      expect(s.turnIndex, 0);
      expect(s.xMoves, isEmpty);
      expect(s.oMoves, isEmpty);
    });

    test('shares random starter policy with ShiftTac', () {
      final starters = <Player>{};
      for (var i = 0; i < 40; i++) {
        starters.add(ClassicGameEngine.instance.initial().currentPlayer);
      }
      expect(starters, containsAll([Player.x, Player.o]));
    });

    test('starts with explicit starter when provided via snapshot factory', () {
      final s = GameSnapshot.initial(startingPlayer: Player.o);
      expect(s.currentPlayer, Player.o);
    });
  });

  group('ClassicGameEngine.oldestPositionFor', () {
    test('always returns null', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 2, 2);

      expect(
        ClassicGameEngine.instance.oldestPositionFor(Player.x, s),
        isNull,
      );
      expect(
        ClassicGameEngine.instance.oldestPositionFor(Player.o, s),
        isNull,
      );
    });
  });

  group('ClassicGameEngine.attemptMove — validation', () {
    test('accepts valid empty-cell moves', () {
      final s0 = GameSnapshot.initial(startingPlayer: Player.x);
      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s0,
        position: const Position(row: 1, col: 1),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.removedMove, isNull);
      expect(r.placedMove?.position, const Position(row: 1, col: 1));
      expect(r.snapshot.xMoves.length, 1);
    });

    test('rejects occupied cells without mutating snapshot', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 1, 1);
      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 1, col: 1),
      );
      expect(r.moveAccepted, isFalse);
      expect(r.removedMove, isNull);
      expect(identical(r.snapshot, s), isTrue);
    });

    test('rejects moves after win', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 2, 2);
      s = _applyClassic(s, 0, 2);
      expect(s.status, GameStatus.won);

      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 2, col: 0),
      );
      expect(r.moveAccepted, isFalse);
      expect(identical(r.snapshot, s), isTrue);
    });

    test('rejects moves after draw', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 2, 2);
      s = _applyClassic(s, 2, 0);
      s = _applyClassic(s, 0, 2);
      s = _applyClassic(s, 2, 1);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 1, 2);
      expect(s.status, GameStatus.draw);

      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 0, col: 0),
      );
      expect(r.moveAccepted, isFalse);
      expect(identical(r.snapshot, s), isTrue);
    });

    test('removedMove is always null', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      for (var i = 0; i < 9; i++) {
        final r = ClassicGameEngine.instance.attemptMove(
          snapshot: s,
          position: Position(row: i % 3, col: i ~/ 3),
        );
        if (!r.moveAccepted) {
          break;
        }
        expect(r.removedMove, isNull);
        s = r.snapshot;
      }
    });
  });

  group('ClassicGameEngine.attemptMove — turns', () {
    test('alternates turns', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      expect(s.currentPlayer, Player.x);
      s = _applyClassic(s, 0, 0);
      expect(s.currentPlayer, Player.o);
      s = _applyClassic(s, 1, 1);
      expect(s.currentPlayer, Player.x);
    });
  });

  group('ClassicGameEngine.attemptMove — wins', () {
    test('X can win by row', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 2, 2);
      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 0, col: 2),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.snapshot.status, GameStatus.won);
      expect(r.snapshot.winner, Player.x);
      expect(r.snapshot.winningLine, const [
        Position(row: 0, col: 0),
        Position(row: 0, col: 1),
        Position(row: 0, col: 2),
      ]);
    });

    test('O can win by column', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 2, 2);
      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 2, col: 1),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.snapshot.status, GameStatus.won);
      expect(r.snapshot.winner, Player.o);
      expect(r.snapshot.winningLine, const [
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
        Position(row: 2, col: 1),
      ]);
    });

    test('diagonal win works', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 0, 2);
      s = _applyClassic(s, 2, 2);
      expect(s.status, GameStatus.won);
      expect(s.winner, Player.x);
      expect(s.winningLine, const [
        Position(row: 0, col: 0),
        Position(row: 1, col: 1),
        Position(row: 2, col: 2),
      ]);
    });

    test('anti-diagonal win works', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 2);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 2, 0);
      expect(s.status, GameStatus.won);
      expect(s.winner, Player.x);
      expect(s.winningLine, const [
        Position(row: 0, col: 2),
        Position(row: 1, col: 1),
        Position(row: 2, col: 0),
      ]);
    });

    test('win on the ninth move wins instead of drawing', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 2, 2);
      s = _applyClassic(s, 0, 2);
      s = _applyClassic(s, 2, 1);
      s = _applyClassic(s, 2, 0);
      s = _applyClassic(s, 1, 0);
      s = _applyClassic(s, 1, 2);
      expect(s.status, GameStatus.playing);
      expect(s.turnIndex, 8);

      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 0, col: 1),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.snapshot.status, GameStatus.won);
      expect(r.snapshot.status, isNot(GameStatus.draw));
      expect(r.snapshot.winner, Player.x);
      expect(r.snapshot.turnIndex, 9);
      expect(r.snapshot.winningLine, const [
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
        Position(row: 2, col: 1),
      ]);
    });
  });

  group('ClassicGameEngine.attemptMove — draw', () {
    test('draw is detected on a full board with no winner', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _applyClassic(s, 0, 0);
      s = _applyClassic(s, 1, 1);
      s = _applyClassic(s, 0, 1);
      s = _applyClassic(s, 2, 2);
      s = _applyClassic(s, 2, 0);
      s = _applyClassic(s, 0, 2);
      s = _applyClassic(s, 2, 1);
      s = _applyClassic(s, 1, 0);
      final r = ClassicGameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 1, col: 2),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.snapshot.status, GameStatus.draw);
      expect(r.snapshot.winner, isNull);
      expect(r.snapshot.winningLine, isNull);
      expect(r.snapshot.xMoves.length + r.snapshot.oMoves.length, 9);
    });
  });
}
