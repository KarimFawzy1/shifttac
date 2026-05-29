import 'dart:math';

import '../models/bot_difficulty.dart';
import 'classic_bot_strategy.dart';
import 'classic_easy_bot_strategy.dart';
import 'classic_hard_bot_strategy.dart';
import 'classic_intermediate_bot_strategy.dart';

/// Maps [BotDifficulty] to a [ClassicBotStrategy] implementation.
abstract final class ClassicBotStrategyFactory {
  ClassicBotStrategyFactory._();

  /// [random] is reserved for [BotDifficulty.easy] (Phase 3); ignored otherwise.
  static ClassicBotStrategy forDifficulty(
    BotDifficulty difficulty, {
    Random? random,
  }) {
    return switch (difficulty) {
      BotDifficulty.easy => ClassicEasyBotStrategy(random: random),
      BotDifficulty.intermediate => const ClassicIntermediateBotStrategy(),
      BotDifficulty.hard => const ClassicHardBotStrategy(),
    };
  }
}
