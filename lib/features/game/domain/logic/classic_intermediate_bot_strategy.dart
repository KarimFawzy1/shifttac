import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'classic_bot_helpers.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Tactical classic bot: win, block, then center → corners → sides.
class ClassicIntermediateBotStrategy implements ClassicBotStrategy {
  const ClassicIntermediateBotStrategy();

  static const Position _center = Position(row: 1, col: 1);

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    if (snapshot.status != GameStatus.playing) {
      throw StateError('ClassicIntermediateBotStrategy: match is not in progress');
    }
    if (snapshot.currentPlayer != botPlayer) {
      throw StateError('ClassicIntermediateBotStrategy: not the bot turn');
    }

    final win = findImmediateWin(snapshot: snapshot, player: botPlayer);
    if (win != null) {
      return win;
    }

    final block = findImmediateThreat(
      snapshot: snapshot,
      threateningPlayer: botPlayer.opponent,
    );
    if (block != null) {
      return block;
    }

    final center = firstAvailableInOrder(snapshot, const [_center]);
    if (center != null) {
      return center;
    }

    final corner = firstAvailableInOrder(snapshot, classicCornerPositions);
    if (corner != null) {
      return corner;
    }

    final side = firstAvailableInOrder(snapshot, classicSidePositions);
    if (side != null) {
      return side;
    }

    final fallback = availablePositions(snapshot);
    if (fallback.isEmpty) {
      throw StateError('ClassicIntermediateBotStrategy: no legal moves');
    }
    return fallback.first;
  }
}
