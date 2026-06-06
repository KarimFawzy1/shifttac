import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'bot_opening_helpers.dart';
import 'classic_bot_helpers.dart';
import 'classic_bot_strategy.dart';
import 'game_snapshot.dart';

/// Optimal classic Tic Tac Toe via minimax ([ClassicGameEngine] simulations).
class ClassicHardBotStrategy implements ClassicBotStrategy {
  const ClassicHardBotStrategy();

  static const int _terminalWinScore = 10;
  static const int _worstScore = -1000;
  static const int _bestMinScore = 1000;

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    if (snapshot.status != GameStatus.playing) {
      throw StateError('ClassicHardBotStrategy: match is not in progress');
    }
    if (snapshot.currentPlayer != botPlayer) {
      throw StateError('ClassicHardBotStrategy: not the bot turn');
    }

    final opening = forcedOBotCenterOpening(
      snapshot: snapshot,
      botPlayer: botPlayer,
    );
    if (opening != null) {
      return opening;
    }

    final humanPlayer = botPlayer.opponent;
    Position? bestMove;
    var bestScore = _worstScore;

    for (final position in availablePositions(snapshot)) {
      final result = simulateClassicMove(
        snapshot: snapshot,
        position: position,
      );
      if (!result.moveAccepted) {
        continue;
      }

      final score = _minimaxScore(
        result.snapshot,
        depth: 1,
        botPlayer: botPlayer,
        humanPlayer: humanPlayer,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = position;
      }
    }

    if (bestMove == null) {
      throw StateError('ClassicHardBotStrategy: no legal moves');
    }
    return bestMove;
  }

  int _minimaxScore(
    GameSnapshot snapshot, {
    required int depth,
    required Player botPlayer,
    required Player humanPlayer,
  }) {
    if (snapshot.status == GameStatus.won) {
      if (snapshot.winner == botPlayer) {
        return _terminalWinScore - depth;
      }
      if (snapshot.winner == humanPlayer) {
        return depth - _terminalWinScore;
      }
      return 0;
    }
    if (snapshot.status == GameStatus.draw) {
      return 0;
    }
    if (snapshot.status != GameStatus.playing) {
      return 0;
    }

    final maximizing = snapshot.currentPlayer == botPlayer;
    final moves = availablePositions(snapshot);

    if (maximizing) {
      var best = _worstScore;
      for (final position in moves) {
        final result = simulateClassicMove(
          snapshot: snapshot,
          position: position,
        );
        if (!result.moveAccepted) {
          continue;
        }
        final score = _minimaxScore(
          result.snapshot,
          depth: depth + 1,
          botPlayer: botPlayer,
          humanPlayer: humanPlayer,
        );
        if (score > best) {
          best = score;
        }
      }
      return best;
    }

    var best = _bestMinScore;
    for (final position in moves) {
      final result = simulateClassicMove(
        snapshot: snapshot,
        position: position,
      );
      if (!result.moveAccepted) {
        continue;
      }
      final score = _minimaxScore(
        result.snapshot,
        depth: depth + 1,
        botPlayer: botPlayer,
        humanPlayer: humanPlayer,
      );
      if (score < best) {
        best = score;
      }
    }
    return best;
  }
}
