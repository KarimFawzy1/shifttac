import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/shift_bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/shift_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/shift_hard_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/shift_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
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
  group('ShiftEasyBotStrategy', () {
    test('always returns a legal empty cell', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final bot = ShiftEasyBotStrategy(random: Random(1));

      for (var i = 0; i < 20; i++) {
        final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
        expect(shiftAvailablePositions(snapshot), contains(move));

        final result = ShiftGameEngine.instance.attemptMove(
          snapshot: snapshot,
          position: move,
        );
        expect(result.moveAccepted, isTrue);
        snapshot = result.snapshot;
        if (snapshot.currentPlayer != Player.o) {
          break;
        }
      }
    });

    test('never chooses an occupied cell', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = _applyShift(snapshot, 1, 1);
      snapshot = _applyShift(snapshot, 0, 0);

      expect(snapshot.currentPlayer, Player.o);
      final bot = ShiftEasyBotStrategy(random: Random(3));
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);

      expect(shiftOccupiedPositions(snapshot), isNot(contains(move)));
    });

    test('works when the bot already has three active marks', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      snapshot = _applyShift(snapshot, 0, 0);
      snapshot = _applyShift(snapshot, 2, 2);
      snapshot = _applyShift(snapshot, 0, 1);
      snapshot = _applyShift(snapshot, 1, 2);
      snapshot = _applyShift(snapshot, 2, 0);
      snapshot = _applyShift(snapshot, 1, 1);

      expect(snapshot.currentPlayer, Player.x);
      expect(snapshot.xMoves.length, GameConstants.maxActiveMarks);

      final bot = ShiftEasyBotStrategy(random: Random(2));
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.x);

      expect(shiftAvailablePositions(snapshot), contains(move));
      final result = ShiftGameEngine.instance.attemptMove(
        snapshot: snapshot,
        position: move,
      );
      expect(result.moveAccepted, isTrue);
      expect(result.removedMove, isNotNull);
    });

    test('is deterministic with a seeded random source', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);

      final first = ShiftEasyBotStrategy(
        random: Random(99),
      ).chooseMove(snapshot: snapshot, botPlayer: Player.o);
      final second = ShiftEasyBotStrategy(
        random: Random(99),
      ).chooseMove(snapshot: snapshot, botPlayer: Player.o);

      expect(first, second);
      expect(shiftAvailablePositions(snapshot), contains(first));
    });

    test('throws when called outside bot turn', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      final bot = ShiftEasyBotStrategy();

      expect(
        () => bot.chooseMove(snapshot: snapshot, botPlayer: Player.o),
        throwsA(isA<StateError>()),
      );
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
        () => ShiftEasyBotStrategy().chooseMove(
          snapshot: snapshot,
          botPlayer: Player.x,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ShiftBotStrategyFactory.forDifficulty', () {
    test('returns ShiftEasyBotStrategy for easy', () {
      final strategy = ShiftBotStrategyFactory.forDifficulty(
        BotDifficulty.easy,
        random: Random(0),
      );
      expect(strategy, isA<ShiftEasyBotStrategy>());
    });

    test('returns ShiftHardBotStrategy for hard', () {
      final strategy = ShiftBotStrategyFactory.forDifficulty(BotDifficulty.hard);
      expect(strategy, isA<ShiftHardBotStrategy>());
    });

    test('returns ShiftIntermediateBotStrategy for intermediate', () {
      final strategy = ShiftBotStrategyFactory.forDifficulty(
        BotDifficulty.intermediate,
      );
      expect(strategy, isA<ShiftIntermediateBotStrategy>());
    });
  });
}
