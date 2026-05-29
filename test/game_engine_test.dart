import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

GameSnapshot _apply(GameSnapshot s, int row, int col) {
  final r = GameEngine.instance.attemptMove(
    snapshot: s,
    position: Position(row: row, col: col),
  );
  expect(r.moveAccepted, isTrue, reason: 'move ($row,$col)');
  return r.snapshot;
}

void main() {
  group('GameEngine.restart', () {
    test('returns initial playing state with random starter', () {
      final s = GameEngine.restart();
      expect(s.xMoves, isEmpty);
      expect(s.oMoves, isEmpty);
      expect([Player.x, Player.o], contains(s.currentPlayer));
      expect(s.turnIndex, 0);
      expect(s.status, GameStatus.playing);
      expect(s.winner, isNull);
      expect(s.winningLine, isNull);
    });
  });

  group('GameEngine.oldestPositionFor', () {
    test('returns null when queue empty', () {
      final s = GameSnapshot.initial(startingPlayer: Player.x);
      expect(GameEngine.instance.oldestPositionFor(Player.x, s), isNull);
    });

    test('returns oldest FIFO position', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 1);
      s = _apply(s, 2, 2);
      expect(
        GameEngine.instance.oldestPositionFor(Player.x, s),
        const Position(row: 0, col: 0),
      );
    });
  });

  group('GameEngine.attemptMove — validation', () {
    test('rejects occupied cell without mutating snapshot', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 1, 1);
      final r = GameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 1, col: 1),
      );
      expect(r.moveAccepted, isFalse);
      expect(identical(r.snapshot, s), isTrue);
    });

    test('rejects moves after win', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 0);
      s = _apply(s, 0, 1);
      s = _apply(s, 2, 2);
      s = _apply(s, 0, 2);
      expect(s.status, GameStatus.won);

      final r = GameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 2, col: 0),
      );
      expect(r.moveAccepted, isFalse);
      expect(identical(r.snapshot, s), isTrue);
    });
  });

  group('GameEngine.attemptMove — turns & FIFO', () {
    test('initial picks X or O at random when unspecified', () {
      final starters = <Player>{};
      for (var i = 0; i < 40; i++) {
        starters.add(GameSnapshot.initial().currentPlayer);
      }
      expect(starters, containsAll([Player.x, Player.o]));
    });

    test('alternates players on successful moves', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      expect(s.currentPlayer, Player.x);
      s = _apply(s, 0, 0);
      expect(s.currentPlayer, Player.o);
      s = _apply(s, 1, 1);
      expect(s.currentPlayer, Player.x);
    });

    test('increments turnIndex on accepted moves', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      expect(s.turnIndex, 1);
      s = _apply(s, 1, 1);
      expect(s.turnIndex, 2);
    });

    test('does not rotate when player has fewer than 3 marks', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 1);
      s = _apply(s, 1, 0);
      expect(s.xMoves.length, 2);
      expect(s.oMoves.length, 1);
    });

    test('FIFO removes oldest when placing 4th mark for a player', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 2, 2);
      s = _apply(s, 0, 1);
      s = _apply(s, 1, 2);
      s = _apply(s, 2, 0);
      s = _apply(s, 1, 1);
      s = _apply(s, 0, 2);
      expect(s.xMoves.length, GameConstants.maxActiveMarks);
      expect(s.xMoves.map((m) => m.position), const [
        Position(row: 0, col: 1),
        Position(row: 2, col: 0),
        Position(row: 0, col: 2),
      ]);
      expect(s.xMoves.first.position, const Position(row: 0, col: 1));
      expect(s.xMoves.last.position, const Position(row: 0, col: 2));
    });

    test('reports removedMove when rotation occurs', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 2, 2);
      s = _apply(s, 0, 1);
      s = _apply(s, 1, 2);
      s = _apply(s, 2, 0);
      s = _apply(s, 1, 1);
      final r = GameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 0, col: 2),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.removedMove?.position, const Position(row: 0, col: 0));
      expect(r.placedMove?.position, const Position(row: 0, col: 2));
    });

    test('never exposes more than maxActiveMarks per player', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      const seq = <(int, int)>[
        (0, 0),
        (2, 2),
        (0, 1),
        (1, 2),
        (2, 0),
        (1, 1),
        (0, 2),
        (2, 1),
        (1, 0),
        (2, 1),
      ];
      for (final pair in seq) {
        if (s.status == GameStatus.won) {
          break;
        }
        final r = GameEngine.instance.attemptMove(
          snapshot: s,
          position: Position(row: pair.$1, col: pair.$2),
        );
        if (!r.moveAccepted) {
          continue;
        }
        s = r.snapshot;
        expect(
          s.xMoves.length,
          lessThanOrEqualTo(GameConstants.maxActiveMarks),
        );
        expect(
          s.oMoves.length,
          lessThanOrEqualTo(GameConstants.maxActiveMarks),
        );
      }
    });
  });

  group('GameEngine.attemptMove — wins', () {
    test('detects top row win on third X mark (with alternation)', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 0);
      s = _apply(s, 0, 1);
      s = _apply(s, 2, 2);
      final r = GameEngine.instance.attemptMove(
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

    test('detects middle column win for O', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 0, 1);
      s = _apply(s, 1, 0);
      s = _apply(s, 1, 1);
      s = _apply(s, 2, 2);
      final r = GameEngine.instance.attemptMove(
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

    test('detects primary diagonal win', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 0, 1);
      s = _apply(s, 1, 1);
      s = _apply(s, 0, 2);
      s = _apply(s, 2, 2);
      expect(s.status, GameStatus.won);
      expect(s.winner, Player.x);
      expect(s.winningLine, const [
        Position(row: 0, col: 0),
        Position(row: 1, col: 1),
        Position(row: 2, col: 2),
      ]);
    });

    test('detects anti-diagonal win', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 2);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 1);
      s = _apply(s, 1, 0);
      s = _apply(s, 2, 0);
      expect(s.status, GameStatus.won);
      expect(s.winner, Player.x);
      expect(s.winningLine, const [
        Position(row: 0, col: 2),
        Position(row: 1, col: 1),
        Position(row: 2, col: 0),
      ]);
    });

    /// Win only appears after FIFO removal + placement (`rules.md` §7).
    test('win immediately after rotation (not a line before 4th X)', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 2, 2);
      s = _apply(s, 1, 0);
      s = _apply(s, 0, 2);
      s = _apply(s, 1, 1);
      expect(s.status, GameStatus.playing);
      expect(s.currentPlayer, Player.o);
      s = _apply(s, 2, 0);
      expect(s.currentPlayer, Player.x);
      final r = GameEngine.instance.attemptMove(
        snapshot: s,
        position: const Position(row: 1, col: 2),
      );
      expect(r.moveAccepted, isTrue);
      expect(r.removedMove?.position, const Position(row: 0, col: 0));
      expect(r.snapshot.status, GameStatus.won);
      expect(r.snapshot.winner, Player.x);
      expect(r.snapshot.winningLine, const [
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });
  });

  group('GameEngine.attemptMove — placedMove / rules', () {
    test('placedMove uses snapshot turnIndex before increment', () {
      final s0 = GameSnapshot.initial(startingPlayer: Player.x);
      final r = GameEngine.instance.attemptMove(
        snapshot: s0,
        position: const Position(row: 0, col: 0),
      );
      expect(r.placedMove?.turnIndex, 0);
      expect(r.snapshot.turnIndex, 1);
    });

    test('restart clears queues and win metadata', () {
      var s = GameSnapshot.initial(startingPlayer: Player.x);
      s = _apply(s, 0, 0);
      s = _apply(s, 1, 0);
      s = _apply(s, 0, 1);
      s = _apply(s, 2, 2);
      s = _apply(s, 0, 2);
      expect(s.status, GameStatus.won);

      final fresh = GameEngine.restart();
      expect(fresh.xMoves, isEmpty);
      expect(fresh.oMoves, isEmpty);
      expect(fresh.status, GameStatus.playing);
      expect(fresh.winner, isNull);
    });
  });
}
