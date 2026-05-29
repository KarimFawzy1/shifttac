import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/bot_strategy_factory.dart';
import 'package:shifttac/features/game/domain/logic/classic_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_hard_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_intermediate_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/shift_easy_bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/shift_intermediate_bot_strategy.dart';
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

    test('returns ShiftEasyBotStrategy for shift easy', () {
      final strategy = BotStrategyFactory.forSession(
        mode: GameMode.shift,
        difficulty: BotDifficulty.easy,
        random: Random(0),
      );
      expect(strategy, isA<ShiftEasyBotStrategy>());
    });

    test('returns ShiftIntermediateBotStrategy for shift intermediate', () {
      final strategy = BotStrategyFactory.forSession(
        mode: GameMode.shift,
        difficulty: BotDifficulty.intermediate,
      );
      expect(strategy, isA<ShiftIntermediateBotStrategy>());
    });

    test('throws for shift hard', () {
      expect(
        () => BotStrategyFactory.forSession(
          mode: GameMode.shift,
          difficulty: BotDifficulty.hard,
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
