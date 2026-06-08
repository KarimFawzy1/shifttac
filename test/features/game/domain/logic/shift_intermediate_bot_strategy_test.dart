import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/shift_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
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
  const bot = ShiftIntermediateBotStrategy();

  group('ShiftIntermediateBotStrategy', () {
    test('takes an immediate winning move after FIFO removal', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 0, 2);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 2, 0);

      expect(snapshot.currentPlayer, Player.x);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(move, const Position(row: 1, col: 2));
    });

    test('blocks an immediate human winning move', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 2, 0);

      expect(snapshot.currentPlayer, Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, const Position(row: 0, col: 2));
    });

    test('avoids a move that gives the human an immediate win', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 2, 2);

      expect(snapshot.currentPlayer, Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(
        allowsOpponentImmediateWin(
          snapshot: snapshot,
          candidate: move,
          botPlayer: Player.o,
        ),
        isFalse,
      );
    });

    test('prefers the highest fork-count among safe moves', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 0, 2);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 2, 1);

      expect(snapshot.currentPlayer, Player.o);

      int forkCountAfter(Position position) {
        final result = simulateShiftMove(snapshot: snapshot, position: position);
        if (!result.moveAccepted) {
          return -1;
        }
        final asBotTurn = GameSnapshot(
          xMoves: result.snapshot.xMoves,
          oMoves: result.snapshot.oMoves,
          currentPlayer: Player.o,
          turnIndex: result.snapshot.turnIndex,
          status: GameStatus.playing,
          winningLine: null,
          winner: null,
        );
        return countImmediateWinsFor(snapshot: asBotTurn, player: Player.o);
      }

      final safeMoves = shiftAvailablePositions(snapshot)
          .where(
            (position) => !allowsOpponentImmediateWin(
              snapshot: snapshot,
              candidate: position,
              botPlayer: Player.o,
            ),
          )
          .toList();
      expect(safeMoves.length, greaterThan(1));

      var bestFork = -1;
      for (final position in safeMoves) {
        final count = forkCountAfter(position);
        if (count > bestFork) {
          bestFork = count;
        }
      }
      expect(bestFork, greaterThanOrEqualTo(1));

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(forkCountAfter(move), bestFork);
    });

    test('chooses center on an empty board', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, const Position(row: 1, col: 1));
    });

    test('chooses a corner before a side when center is taken', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 1);

      expect(snapshot.currentPlayer, Player.x);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(shiftCornerPositions, contains(move));
      expect(shiftSidePositions, isNot(contains(move)));
    });

    test('returns only legal cells', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 1, 0);

      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(shiftAvailablePositions(snapshot), contains(move));
    });

    test('does not mutate the input snapshot', () {
      final before = GameSnapshot.initial(startingPlayer: Player.o);
      bot.chooseMove(snapshot: before, botPlayer: Player.o);
      expect(before.xMoves, isEmpty);
      expect(before.oMoves, isEmpty);
      expect(before.turnIndex, 0);
    });

    test('throws when match is not playing', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 0, 2);

      expect(snapshot.status, GameStatus.won);
      expect(
        () => bot.chooseMove(snapshot: snapshot, botPlayer: Player.x),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ShiftBotStrategyFactory.forDifficulty', () {
    test('returns ShiftIntermediateBotStrategy for intermediate', () {
      final strategy = ShiftBotStrategyFactory.forDifficulty(
        BotDifficulty.intermediate,
      );
      expect(strategy, isA<ShiftIntermediateBotStrategy>());
    });
  });
}
