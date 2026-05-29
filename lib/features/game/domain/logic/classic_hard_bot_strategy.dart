import '../models/player.dart';
import '../models/position.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Minimax classic bot; implemented in Phase 4.
class ClassicHardBotStrategy implements ClassicBotStrategy {
  const ClassicHardBotStrategy();

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    throw UnimplementedError('ClassicHardBotStrategy is implemented in Phase 4');
  }
}
