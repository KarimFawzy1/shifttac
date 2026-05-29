import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/classic_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_hard_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';

void main() {
  group('BotStrategyFactory.forSession', () {
    test('returns ClassicEasyBotStrategy for classic easy', () {
      final strategy = BotStrategyFactory.forSession(
        mode: GameMode.classic,
        difficulty: BotDifficulty.easy,
        random: Random(0),
      );
      expect(strategy, isA<ClassicEasyBotStrategy>());
    });

    test('returns ClassicIntermediateBotStrategy for classic intermediate', () {
      final strategy = BotStrategyFactory.forSession(
        mode: GameMode.classic,
        difficulty: BotDifficulty.intermediate,
      );
      expect(strategy, isA<ClassicIntermediateBotStrategy>());
    });

    test('returns ClassicHardBotStrategy for classic hard', () {
      final strategy = BotStrategyFactory.forSession(
        mode: GameMode.classic,
        difficulty: BotDifficulty.hard,
      );
      expect(strategy, isA<ClassicHardBotStrategy>());
    });

    test('throws for shift mode until ShiftTac strategies exist', () {
      expect(
        () => BotStrategyFactory.forSession(
          mode: GameMode.shift,
          difficulty: BotDifficulty.easy,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
