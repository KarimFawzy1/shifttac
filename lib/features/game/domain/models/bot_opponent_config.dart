import 'bot_difficulty.dart';
import 'player.dart';

/// Describes the bot side and difficulty for an AI session.
class BotOpponentConfig {
  const BotOpponentConfig({
    required this.difficulty,
    required this.botPlayer,
  });

  final BotDifficulty difficulty;
  final Player botPlayer;
}
