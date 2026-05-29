import 'dart:math';

import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_snapshot.dart';
import 'shift_bot_helpers.dart';
import 'shift_bot_strategy.dart';

/// Chooses a random legal empty cell in ShiftTac mode.
class ShiftEasyBotStrategy implements ShiftBotStrategy {
  ShiftEasyBotStrategy({Random? random}) : random = random ?? Random();

  final Random random;

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    _assertBotTurn(snapshot, botPlayer);

    final moves = shiftAvailablePositions(snapshot);
    if (moves.isEmpty) {
      throw StateError('ShiftEasyBotStrategy: no legal moves');
    }
    return moves[random.nextInt(moves.length)];
  }
}

void _assertBotTurn(GameSnapshot snapshot, Player botPlayer) {
  if (snapshot.status != GameStatus.playing) {
    throw StateError('ShiftEasyBotStrategy: match is not in progress');
  }
  if (snapshot.currentPlayer != botPlayer) {
    throw StateError('ShiftEasyBotStrategy: not the bot turn');
  }
}
