import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/classic_bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/classic_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_hard_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';

void main() {
  group('ClassicBotStrategyFactory.forDifficulty', () {
    test('returns ClassicEasyBotStrategy for easy', () {
      final strategy = ClassicBotStrategyFactory.forDifficulty(
        BotDifficulty.easy,
        random: Random(0),
      );
      expect(strategy, isA<ClassicEasyBotStrategy>());
    });

    test('returns ClassicIntermediateBotStrategy for intermediate', () {
      final strategy = ClassicBotStrategyFactory.forDifficulty(
        BotDifficulty.intermediate,
      );
      expect(strategy, isA<ClassicIntermediateBotStrategy>());
    });

    test('returns ClassicHardBotStrategy for hard', () {
      final strategy = ClassicBotStrategyFactory.forDifficulty(
        BotDifficulty.hard,
      );
      expect(strategy, isA<ClassicHardBotStrategy>());
    });
  });
}
