import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_rules.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';

void main() {
  group('GameRules boundary', () {
    test('GameEngine implements GameRules for shift mode', () {
      const GameRules rules = GameEngine.instance;

      expect(rules.mode, GameMode.shift);

      final initial = rules.initial();
      expect(initial.status, GameStatus.playing);
      expect(initial.xMoves, isEmpty);
      expect(initial.oMoves, isEmpty);
      expect([Player.x, Player.o], contains(initial.currentPlayer));
    });

    test('GameEngine.restart matches instance initial()', () {
      final restarted = GameEngine.restart();
      expect(restarted.status, GameStatus.playing);
      expect(restarted.turnIndex, 0);
      expect(restarted.xMoves, isEmpty);
      expect(restarted.oMoves, isEmpty);
    });
  });
}
