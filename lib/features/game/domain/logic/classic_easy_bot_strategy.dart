import 'dart:math';

import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'classic_bot_helpers.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Chooses a random legal empty cell.
class ClassicEasyBotStrategy implements ClassicBotStrategy {
  ClassicEasyBotStrategy({Random? random}) : random = random ?? Random();

  final Random random;

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    _assertBotTurn(snapshot, botPlayer);

    final moves = availablePositions(snapshot);
    if (moves.isEmpty) {
      throw StateError('ClassicEasyBotStrategy: no legal moves');
    }
    return moves[random.nextInt(moves.length)];
  }
}

void _assertBotTurn(GameSnapshot snapshot, Player botPlayer) {
  if (snapshot.status != GameStatus.playing) {
    throw StateError('ClassicEasyBotStrategy: match is not in progress');
  }
  if (snapshot.currentPlayer != botPlayer) {
    throw StateError('ClassicEasyBotStrategy: not the bot turn');
  }
}
