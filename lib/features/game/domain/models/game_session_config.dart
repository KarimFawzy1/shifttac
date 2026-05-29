import 'dart:math';

import 'bot_difficulty.dart';
import 'bot_opponent_config.dart';
import 'game_mode.dart';
import 'player.dart';

/// Launch configuration for a local or AI gameplay session.
class GameSessionConfig {
  const GameSessionConfig({
    required this.mode,
    this.bot,
    this.startingPlayer,
  });

  /// Local ShiftTac multiplayer on one device.
  const GameSessionConfig.shift()
    : mode = GameMode.shift,
      bot = null,
      startingPlayer = null;

  /// Local classic multiplayer on one device.
  const GameSessionConfig.classic()
    : mode = GameMode.classic,
      bot = null,
      startingPlayer = null;

  /// Classic vs AI: human is [Player.x], bot is [Player.o]; starter is random.
  factory GameSessionConfig.classicAi(
    BotDifficulty difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final starter = rng.nextBool() ? Player.x : Player.o;
    return GameSessionConfig(
      mode: GameMode.classic,
      bot: BotOpponentConfig(
        difficulty: difficulty,
        botPlayer: Player.o,
      ),
      startingPlayer: starter,
    );
  }

  /// ShiftTac vs AI: human is [Player.x], bot is [Player.o]; starter is random.
  factory GameSessionConfig.shiftAi(
    BotDifficulty difficulty, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final starter = rng.nextBool() ? Player.x : Player.o;
    return GameSessionConfig(
      mode: GameMode.shift,
      bot: BotOpponentConfig(
        difficulty: difficulty,
        botPlayer: Player.o,
      ),
      startingPlayer: starter,
    );
  }

  final GameMode mode;
  final BotOpponentConfig? bot;
  final Player? startingPlayer;

  /// Whether this session pits the human against a bot.
  bool get isAiSession => bot != null;
}
