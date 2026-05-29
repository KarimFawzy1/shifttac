import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/shift_hard_bot_strategy.dart';
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

/// Whether [bot] can force a win within [maxPlies] after playing [firstMove].
bool botCanForceWinWithin({
  required GameSnapshot snapshot,
  required Position firstMove,
  required Player bot,
  required int maxPlies,
}) {
  final result = simulateShiftMove(snapshot: snapshot, position: firstMove);
  if (!result.moveAccepted) {
    return false;
  }
  return _searchForcedWin(
    result.snapshot,
    bot: bot,
    pliesLeft: maxPlies - 1,
  );
}

/// Whether [winner] can force a win within [pliesLeft] from [snapshot].
bool searchForcedLoss(
  GameSnapshot snapshot, {
  required Player winner,
  required int pliesLeft,
}) {
  if (snapshot.status == GameStatus.won) {
    return snapshot.winner == winner;
  }
  if (pliesLeft <= 0) {
    return false;
  }

  final mover = snapshot.currentPlayer;
  final moves = shiftAvailablePositions(snapshot);

  if (mover == winner) {
    for (final move in moves) {
      final result = simulateShiftMove(snapshot: snapshot, position: move);
      if (!result.moveAccepted) continue;
      if (searchForcedLoss(
        result.snapshot,
        winner: winner,
        pliesLeft: pliesLeft - 1,
      )) {
        return true;
      }
    }
    return false;
  }

  if (moves.isEmpty) return false;
  for (final move in moves) {
    final result = simulateShiftMove(snapshot: snapshot, position: move);
    if (!result.moveAccepted) continue;
    if (!searchForcedLoss(
      result.snapshot,
      winner: winner,
      pliesLeft: pliesLeft - 1,
    )) {
      return false;
    }
  }
  return true;
}

bool _searchForcedWin(
  GameSnapshot snapshot, {
  required Player bot,
  required int pliesLeft,
}) {
  if (snapshot.status == GameStatus.won) {
    return snapshot.winner == bot;
  }
  if (pliesLeft <= 0) {
    return false;
  }

  final mover = snapshot.currentPlayer;
  final moves = shiftAvailablePositions(snapshot);

  if (mover == bot) {
    for (final move in moves) {
      final result = simulateShiftMove(snapshot: snapshot, position: move);
      if (!result.moveAccepted) {
        continue;
      }
      if (_searchForcedWin(
        result.snapshot,
        bot: bot,
        pliesLeft: pliesLeft - 1,
      )) {
        return true;
      }
    }
    return false;
  }

  if (moves.isEmpty) {
    return false;
  }

  for (final move in moves) {
    final result = simulateShiftMove(snapshot: snapshot, position: move);
    if (!result.moveAccepted) {
      continue;
    }
    if (!_searchForcedWin(
      result.snapshot,
      bot: bot,
      pliesLeft: pliesLeft - 1,
    )) {
      return false;
    }
  }
  return true;
}

void main() {
  const hard = ShiftHardBotStrategy();
  const intermediate = ShiftIntermediateBotStrategy();

  group('ShiftHardBotStrategy', () {
    test('takes an immediate winning move after FIFO removal', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 0, 2);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 2, 0);

      expect(snapshot.currentPlayer, Player.x);
      final move = hard.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      expect(move, const Position(row: 1, col: 2));

      final after = simulateShiftMove(snapshot: snapshot, position: move);
      expect(after.snapshot.status, GameStatus.won);
      expect(after.snapshot.winner, Player.x);
    });

    test('blocks an immediate human winning move', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 2, 0);

      expect(snapshot.currentPlayer, Player.o);
      final move = hard.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      final after = simulateShiftMove(snapshot: snapshot, position: move);
      expect(
        findShiftImmediateThreat(
          snapshot: after.snapshot,
          threateningPlayer: Player.x,
        ),
        isNull,
      );
    });

    test('finds a forced win that intermediate misses', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 1, 2);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 2, 1);
      snapshot = _applyShift(snapshot, 0, 2);

      expect(snapshot.currentPlayer, Player.x);

      final hardMove = hard.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      final intermediateMove = intermediate.chooseMove(
        snapshot: snapshot,
        botPlayer: Player.x,
      );

      expect(hardMove, isNot(intermediateMove));
      expect(
        botCanForceWinWithin(
          snapshot: snapshot,
          firstMove: hardMove,
          bot: Player.x,
          maxPlies: ShiftHardBotStrategy.searchDepthPlies,
        ),
        isTrue,
      );
      expect(
        botCanForceWinWithin(
          snapshot: snapshot,
          firstMove: intermediateMove,
          bot: Player.x,
          maxPlies: ShiftHardBotStrategy.searchDepthPlies,
        ),
        isFalse,
      );
    });

    test('avoids a forced loss when a safe move exists', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 0, 2);
      snapshot = _applyShift(snapshot, 2, 0);
      snapshot = _applyShift(snapshot, 1, 0);
      snapshot = _applyShift(snapshot, 1, 2);

      expect(snapshot.currentPlayer, Player.x);

      final hardMove = hard.chooseMove(snapshot: snapshot, botPlayer: Player.x);
      final intermediateMove = intermediate.chooseMove(
        snapshot: snapshot,
        botPlayer: Player.x,
      );

      expect(hardMove, isNot(intermediateMove));
      expect(hardMove, const Position(row: 2, col: 2));
      expect(intermediateMove, const Position(row: 1, col: 1));

      final afterHard = simulateShiftMove(snapshot: snapshot, position: hardMove);
      expect(
        searchForcedLoss(
          afterHard.snapshot,
          winner: Player.o,
          pliesLeft: 5,
        ),
        isFalse,
      );

      final afterIntermediate = simulateShiftMove(
        snapshot: snapshot,
        position: intermediateMove,
      );
      expect(
        searchForcedLoss(
          afterIntermediate.snapshot,
          winner: Player.o,
          pliesLeft: 5,
        ),
        isTrue,
      );
    });

    test('returns a deterministic move', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 0);

      final first = hard.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      final second = hard.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(first, second);
    });

    test('never chooses an occupied cell', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 1, 0);

      final move = hard.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(shiftAvailablePositions(snapshot), contains(move));
      expect(shiftOccupiedPositions(snapshot), isNot(contains(move)));
    });

    test('does not mutate the input snapshot', () {
      final before = GameSnapshot.initial(startingPlayer: Player.o);
      hard.chooseMove(snapshot: before, botPlayer: Player.o);
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
        () => hard.chooseMove(snapshot: snapshot, botPlayer: Player.x),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ShiftBotStrategyFactory.forDifficulty', () {
    test('returns ShiftHardBotStrategy for hard', () {
      final strategy = ShiftBotStrategyFactory.forDifficulty(
        BotDifficulty.hard,
      );
      expect(strategy, isA<ShiftHardBotStrategy>());
    });
  });
}
