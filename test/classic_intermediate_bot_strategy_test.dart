import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/classic_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/classic_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
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
  const bot = ClassicIntermediateBotStrategy();

  group('ClassicIntermediateBotStrategy', () {
    test('takes an immediate winning move', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));
      snapshot = _apply(snapshot, const Position(row: 2, col: 0));

      expect(snapshot.currentPlayer, Player.x);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(move, const Position(row: 0, col: 2));
    });

    test('blocks an immediate human winning move', () {
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

    test('chooses center on an empty board', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, const Position(row: 1, col: 1));
    });

    test('chooses a corner before a side when center is taken', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _apply(snapshot, const Position(row: 1, col: 1));
      snapshot = _apply(snapshot, const Position(row: 0, col: 1));

      expect(snapshot.currentPlayer, Player.x);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(classicCornerPositions, contains(move));
      expect(classicSidePositions, isNot(contains(move)));
    });

    test('returns only legal cells', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _apply(snapshot, const Position(row: 0, col: 0));
      snapshot = _apply(snapshot, const Position(row: 1, col: 0));

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(availablePositions(snapshot), contains(move));
    });

    test('does not mutate the input snapshot', () {
      final before = GameSnapshot.initial(startingPlayer: Player.o);
      bot.chooseMove(snapshot: before, botPlayer: Player.o);
      expect(before.xMoves, isEmpty);
      expect(before.oMoves, isEmpty);
      expect(before.turnIndex, 0);
    });
  });
}
