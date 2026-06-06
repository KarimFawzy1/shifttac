import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/bot_opening_helpers.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_hard_bot_strategy.dart';
import 'package:shifttac/features/game/domain/models/player.dart';

void main() {
  group('forcedOBotCenterOpening', () {
    test('returns center when O opens on an empty board', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      expect(
        forcedOBotCenterOpening(snapshot: snapshot, botPlayer: Player.o),
        botOpeningCenter,
      );
    });

    test('returns null when X opens', () {
      final snapshot = GameSnapshot.initial(startingPlayer: Player.x);
      expect(
        forcedOBotCenterOpening(snapshot: snapshot, botPlayer: Player.o),
        isNull,
      );
    });

    test('returns null after the first ply', () {
      var snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      snapshot = ClassicGameEngine.instance
          .attemptMove(
            snapshot: snapshot,
            position: botOpeningCenter,
          )
          .snapshot;

      expect(
        forcedOBotCenterOpening(snapshot: snapshot, botPlayer: Player.o),
        isNull,
      );
    });
  });

  group('ShiftHardBotStrategy O opening', () {
    test('chooses center on an empty board', () {
      const bot = ShiftHardBotStrategy();
      final snapshot = GameSnapshot.initial(startingPlayer: Player.o);
      final move = bot.chooseMove(snapshot: snapshot, botPlayer: Player.o);
      expect(move, botOpeningCenter);
    });
  });
}
