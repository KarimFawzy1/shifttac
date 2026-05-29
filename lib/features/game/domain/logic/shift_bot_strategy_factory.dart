import 'dart:math';

import '../models/bot_difficulty.dart';
import 'shift_bot_strategy.dart';
import 'shift_easy_bot_strategy.dart';
import 'shift_intermediate_bot_strategy.dart';

/// Maps [BotDifficulty] to a [ShiftBotStrategy] implementation.
abstract final class ShiftBotStrategyFactory {
  ShiftBotStrategyFactory._();

  static ShiftBotStrategy forDifficulty(
    BotDifficulty difficulty, {
    Random? random,
  }) {
    return switch (difficulty) {
      BotDifficulty.easy => ShiftEasyBotStrategy(random: random),
      BotDifficulty.intermediate => const ShiftIntermediateBotStrategy(),
      BotDifficulty.hard => throw UnimplementedError(
        'ShiftTac $difficulty bot is not implemented yet',
      ),
    };
  }
}
