import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/bot_opponent_config.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/domain/models/player.dart';

void main() {
  group('GameSessionConfig', () {
    test('shift factory is local ShiftTac', () {
      const session = GameSessionConfig.shift();
      expect(session.mode, GameMode.shift);
      expect(session.bot, isNull);
      expect(session.startingPlayer, isNull);
      expect(session.isAiSession, isFalse);
    });

    test('classic factory is local classic', () {
      const session = GameSessionConfig.classic();
      expect(session.mode, GameMode.classic);
      expect(session.bot, isNull);
      expect(session.isAiSession, isFalse);
    });

    test('ai session exposes bot config', () {
      const session = GameSessionConfig(
        mode: GameMode.classic,
        bot: BotOpponentConfig(
          difficulty: BotDifficulty.hard,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
      );
      expect(session.isAiSession, isTrue);
      expect(session.bot!.difficulty, BotDifficulty.hard);
      expect(session.bot!.botPlayer, Player.o);
      expect(session.startingPlayer, Player.x);
    });

    test('classicAi factory configures human X vs bot O', () {
      final session = GameSessionConfig.classicAi(BotDifficulty.intermediate);
      expect(session.mode, GameMode.classic);
      expect(session.isAiSession, isTrue);
      expect(session.bot!.difficulty, BotDifficulty.intermediate);
      expect(session.bot!.botPlayer, Player.o);
      expect(session.startingPlayer, isIn([Player.x, Player.o]));
    });

    test('classicAi randomizes X or O as starting player', () {
      final starters = <Player>{};
      for (var seed = 0; seed < 24; seed++) {
        starters.add(
          GameSessionConfig.classicAi(
            BotDifficulty.easy,
            random: Random(seed),
          ).startingPlayer!,
        );
      }
      expect(starters, contains(Player.x));
      expect(starters, contains(Player.o));
    });
  });
}
