import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/classic_bot_helpers.dart';
import 'package:shifttac/features/game/domain/logic/classic_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/player.dart';

void main() {
  group('ClassicEasyBotStrategy', () {
    test('always returns a legal empty cell', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final bot = ClassicEasyBotStrategy(random: Random(1));

      for (var i = 0; i < 20; i++) {
        final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
        expect(availablePositions(snapshot), contains(move));

        final result = ClassicGameEngine.instance.attemptMove(
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

    test('is deterministic with a seeded random source', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);

      final first = ClassicEasyBotStrategy(
        random: Random(99),
      ).chooseMove(snapshot: snapshot, botPlayer: Player.o);
      final second = ClassicEasyBotStrategy(
        random: Random(99),
      ).chooseMove(snapshot: snapshot, botPlayer: Player.o);

      expect(first, second);
      expect(availablePositions(snapshot), contains(first));
    });
  });
}
