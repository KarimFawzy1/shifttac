import '../models/player.dart';
import '../models/position.dart';
import 'game_snapshot.dart';

/// Chooses a legal cell for the bot; does not mutate [snapshot].
abstract interface class BotStrategy {
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  });
}
