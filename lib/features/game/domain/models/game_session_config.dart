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

  final GameMode mode;
  final BotOpponentConfig? bot;
  final Player? startingPlayer;

  /// Whether this session pits the human against a bot.
  bool get isAiSession => bot != null;
}
