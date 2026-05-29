import 'dart:math';

import '../models/bot_difficulty.dart';
import '../models/game_mode.dart';
import 'bot_strategy.dart';
import 'classic_bot_strategy_factory.dart';
import 'shift_bot_strategy_factory.dart';

/// Maps [GameMode] and [BotDifficulty] to a [BotStrategy] implementation.
abstract final class BotStrategyFactory {
  BotStrategyFactory._();

  static BotStrategy forSession({
    required GameMode mode,
    required BotDifficulty difficulty,
    Random? random,
  }) {
    return switch (mode) {
      GameMode.classic => ClassicBotStrategyFactory.forDifficulty(
        difficulty,
        random: random,
      ),
      GameMode.shift => ShiftBotStrategyFactory.forDifficulty(
        difficulty,
        random: random,
      ),
    };
  }
}
