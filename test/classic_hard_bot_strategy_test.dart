import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/classic_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/classic_hard_bot_strategy.dart';
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
  const bot = ClassicHardBotStrategy();

  group('ClassicHardBotStrategy', () {
    test('takes a winning move', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));

      expect(snapshot.currentPlayer, Player.x);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(move, const Position(row: 0, col: 2));
    });

    test('blocks an immediate loss', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 2));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));

      expect(snapshot.currentPlayer, Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, const Position(row: 0, col: 2));
    });

    test('plays center after human corner opening (draw-oriented)', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));

      expect(snapshot.currentPlayer, Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, const Position(row: 1, col: 1));
    });

    test('never chooses an occupied cell', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(availablePositions(snapshot), contains(move));
      expect(occupiedPositions(snapshot), isNot(contains(move)));
    });

    test('returns a deterministic move when multiple moves share a score', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final first = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      final second = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(first, second);
      expect(first, const Position(row: 1, col: 1));
    });

    test('takes the only winning cell when one move left', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      final after = _apply(snapshot, move);
      expect(after.status, GameStatus.won);
      expect(after.winner, Player.x);
    });

    test('completes a draw when only one cell remains', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 2));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));
      snapshot = _apply(snapshot, const Position(row: 0, col: 2));
      snapshot = _apply(snapshot, const Position(row: 2, col: 1));
      snapshot = _apply(snapshot, const Position(row: 1, col: 0));

      expect(snapshot.currentPlayer, Player.x);
      expect(availablePositions(snapshot), [const Position(row: 1, col: 2)]);

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(move, const Position(row: 1, col: 2));

      final after = ClassicGameEngine.instance.attemptMove(
        snapshot: snapshot,
        position: move,
      );
      expect(after.snapshot.status, GameStatus.draw);
    });

    test('full game vs greedy human never loses when bot plays O', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      const hard = ClassicHardBotStrategy();

      for (var ply = 0; ply < 9 && snapshot.status == GameStatus.playing; ply++) {
        if (snapshot.currentPlayer == Player.o) {
          final move = hard.chooseMove(snapshot: snapshot, botPlayer: Player.o);
          snapshot = _apply(snapshot, move);
        } else {
          final humanMove = findImmediateWin(
                snapshot: snapshot,
                player: Player.x,
              ) ??
              findImmediateThreat(
                snapshot: snapshot,
                threateningPlayer: Player.x,
              ) ??
              availablePositions(snapshot).first;
          snapshot = _apply(snapshot, humanMove);
        }
      }

      expect(snapshot.status, isIn([GameStatus.draw, GameStatus.won]));
      expect(snapshot.winner, isNot(Player.x));
    });
  });
}
