import '../models/game_mode.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_engine_result.dart';
import 'game_snapshot.dart';

/// Mode-specific gameplay rules. Implementations are pure Dart (no Flutter).
abstract interface class GameRules {
  GameMode get mode;

  GameSnapshot initial();

  GameEngineResult attemptMove({
    required GameSnapshot snapshot,
    required Position position,
  });

  Position? oldestPositionFor(Player player, GameSnapshot snapshot);
}
