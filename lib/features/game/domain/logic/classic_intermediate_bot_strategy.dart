import '../models/player.dart';
import '../models/position.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Tactical classic bot; implemented in Phase 3.
class ClassicIntermediateBotStrategy implements ClassicBotStrategy {
  const ClassicIntermediateBotStrategy();

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    throw UnimplementedError(
      'ClassicIntermediateBotStrategy is implemented in Phase 3',
    );
  }
}
