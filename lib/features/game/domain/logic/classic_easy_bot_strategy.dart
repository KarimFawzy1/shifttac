import 'dart:math';

import '../models/player.dart';
import '../models/position.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Random legal moves; implemented in Phase 3.
class ClassicEasyBotStrategy implements ClassicBotStrategy {
  ClassicEasyBotStrategy({Random? random}) : random = random ?? Random();

  /// Used by Phase 3 random move selection.
  final Random random;

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    throw UnimplementedError('ClassicEasyBotStrategy is implemented in Phase 3');
  }
}
