import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_snapshot.dart';
import 'shift_bot_helpers.dart';
import 'shift_bot_strategy.dart';
import 'shift_game_engine.dart';

/// Strong ShiftTac bot via depth-limited negamax with alpha-beta pruning.
class ShiftHardBotStrategy implements ShiftBotStrategy {
  const ShiftHardBotStrategy();

  static const int searchDepthPlies = 8;

  static const int _terminalWinScore = 100000;
  static const int _worstScore = -200000;
  static const int _bestScore = 200000;

  static const int _botImmediateWinThreat = 5000;
  static const int _humanImmediateWinThreat = 6000;
  static const int _botFork = 1200;
  static const int _humanFork = 1500;
  static const int _botTwoInLine = 250;
  static const int _humanTwoInLine = 300;
  static const int _centerOwnership = 60;
  static const int _cornerOwnership = 25;
  static const int _sideOwnership = 10;
  static const int _botCriticalOldestPenalty = 200;
  static const int _humanCriticalOldestBonus = 150;
  static const int _mobility = 5;

  static const Position _center = Position(row: 1, col: 1);

  static const List<List<Position>> _winningLines = [
    [
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 0, col: 2),
    ],
    [
      Position(row: 1, col: 0),
      Position(row: 1, col: 1),
      Position(row: 1, col: 2),
    ],
    [
      Position(row: 2, col: 0),
      Position(row: 2, col: 1),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 0),
      Position(row: 1, col: 0),
      Position(row: 2, col: 0),
    ],
    [
      Position(row: 0, col: 1),
      Position(row: 1, col: 1),
      Position(row: 2, col: 1),
    ],
    [
      Position(row: 0, col: 2),
      Position(row: 1, col: 2),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 0),
      Position(row: 1, col: 1),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 2),
      Position(row: 1, col: 1),
      Position(row: 2, col: 0),
    ],
  ];

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    if (snapshot.status != GameStatus.playing) {
      throw StateError('ShiftHardBotStrategy: match is not in progress');
    }
    if (snapshot.currentPlayer != botPlayer) {
      throw StateError('ShiftHardBotStrategy: not the bot turn');
    }

    final moves = _orderedMoves(snapshot: snapshot, player: botPlayer);
    if (moves.isEmpty) {
      throw StateError('ShiftHardBotStrategy: no legal moves');
    }

    Position? bestMove;
    var bestScore = _worstScore;
    var alpha = _worstScore;

    for (final position in moves) {
      final result = simulateShiftMove(
        snapshot: snapshot,
        position: position,
      );
      if (!result.moveAccepted) {
        continue;
      }

      final score = -_negamax(
        result.snapshot,
        depth: searchDepthPlies - 1,
        alpha: -_bestScore,
        beta: -alpha,
        botPlayer: botPlayer,
        plyDepth: 1,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMove = position;
      }
      if (score > alpha) {
        alpha = score;
      }
    }

    if (bestMove == null) {
      throw StateError('ShiftHardBotStrategy: no legal moves');
    }
    return bestMove;
  }

  int _negamax(
    GameSnapshot snapshot, {
    required int depth,
    required int alpha,
    required int beta,
    required Player botPlayer,
    required int plyDepth,
  }) {
    final terminal = _terminalScore(snapshot, botPlayer, plyDepth);
    if (terminal != null) {
      return terminal;
    }
    if (depth <= 0) {
      return _evaluate(snapshot, botPlayer);
    }

    final current = snapshot.currentPlayer;
    final moves = _orderedMoves(snapshot: snapshot, player: current);

    var best = _worstScore;
    for (final position in moves) {
      final result = simulateShiftMove(
        snapshot: snapshot,
        position: position,
      );
      if (!result.moveAccepted) {
        continue;
      }

      final score = -_negamax(
        result.snapshot,
        depth: depth - 1,
        alpha: -beta,
        beta: -alpha,
        botPlayer: botPlayer,
        plyDepth: plyDepth + 1,
      );

      if (score > best) {
        best = score;
      }
      if (best > alpha) {
        alpha = best;
      }
      if (alpha >= beta) {
        break;
      }
    }

    return best;
  }

  int? _terminalScore(GameSnapshot snapshot, Player botPlayer, int plyDepth) {
    if (snapshot.status != GameStatus.won) {
      return null;
    }
    if (snapshot.winner == botPlayer) {
      return _terminalWinScore - plyDepth;
    }
    return plyDepth - _terminalWinScore;
  }

  int _evaluate(GameSnapshot snapshot, Player botPlayer) {
    final terminal = _terminalScore(snapshot, botPlayer, 0);
    if (terminal != null) {
      return terminal;
    }

    final humanPlayer = botPlayer.opponent;
    var score = 0;

    final botTurn = _asPlayerTurn(snapshot, botPlayer);
    final humanTurn = _asPlayerTurn(snapshot, humanPlayer);

    final botImmediateWins =
        countImmediateWinsFor(snapshot: botTurn, player: botPlayer);
    final humanImmediateWins =
        countImmediateWinsFor(snapshot: humanTurn, player: humanPlayer);

    score += botImmediateWins * _botImmediateWinThreat;
    score -= humanImmediateWins * _humanImmediateWinThreat;
    score += botImmediateWins * _botFork;
    score -= humanImmediateWins * _humanFork;

    score += _countTwoInLine(snapshot, botPlayer) * _botTwoInLine;
    score -= _countTwoInLine(snapshot, humanPlayer) * _humanTwoInLine;

    score += _positionalOwnershipScore(snapshot, botPlayer);
    score += _criticalOldestScore(snapshot, botPlayer);
    score += shiftAvailablePositions(snapshot).length * _mobility;

    return score;
  }

  int _positionalOwnershipScore(GameSnapshot snapshot, Player botPlayer) {
    final humanPlayer = botPlayer.opponent;
    var score = 0;

    final botMarks = snapshot.movesFor(botPlayer).map((m) => m.position).toSet();
    final humanMarks =
        snapshot.movesFor(humanPlayer).map((m) => m.position).toSet();

    if (botMarks.contains(_center)) {
      score += _centerOwnership;
    } else if (humanMarks.contains(_center)) {
      score -= _centerOwnership;
    }

    for (final corner in shiftCornerPositions) {
      if (botMarks.contains(corner)) {
        score += _cornerOwnership;
      } else if (humanMarks.contains(corner)) {
        score -= _cornerOwnership;
      }
    }

    for (final side in shiftSidePositions) {
      if (botMarks.contains(side)) {
        score += _sideOwnership;
      } else if (humanMarks.contains(side)) {
        score -= _sideOwnership;
      }
    }

    return score;
  }

  int _criticalOldestScore(GameSnapshot snapshot, Player botPlayer) {
    final humanPlayer = botPlayer.opponent;
    var score = 0;

    final botOldest =
        ShiftGameEngine.instance.oldestPositionFor(botPlayer, snapshot);
    if (botOldest != null &&
        snapshot.movesFor(botPlayer).length >= 3 &&
        _isCriticalOldestMark(snapshot, botPlayer, botOldest)) {
      score -= _botCriticalOldestPenalty;
    }

    final humanOldest =
        ShiftGameEngine.instance.oldestPositionFor(humanPlayer, snapshot);
    if (humanOldest != null &&
        snapshot.movesFor(humanPlayer).length >= 3 &&
        _isCriticalOldestMark(snapshot, humanPlayer, humanOldest)) {
      score += _humanCriticalOldestBonus;
    }

    return score;
  }

  bool _isCriticalOldestMark(
    GameSnapshot snapshot,
    Player player,
    Position oldest,
  ) {
    final owned = snapshot.movesFor(player).map((m) => m.position).toSet();
    if (!owned.contains(oldest)) {
      return false;
    }

    final occupied = shiftOccupiedPositions(snapshot);
    for (final line in _winningLines) {
      if (!line.contains(oldest)) {
        continue;
      }
      var onLine = 0;
      var open = 0;
      for (final cell in line) {
        if (owned.contains(cell)) {
          onLine++;
        } else if (!occupied.contains(cell)) {
          open++;
        }
      }
      if (onLine == 2 && open == 1) {
        return true;
      }
    }
    return false;
  }

  int _countTwoInLine(GameSnapshot snapshot, Player player) {
    final owned = snapshot.movesFor(player).map((m) => m.position).toSet();
    final occupied = shiftOccupiedPositions(snapshot);
    var count = 0;

    for (final line in _winningLines) {
      var onLine = 0;
      var open = 0;
      for (final cell in line) {
        if (owned.contains(cell)) {
          onLine++;
        } else if (!occupied.contains(cell)) {
          open++;
        }
      }
      if (onLine == 2 && open == 1) {
        count++;
      }
    }
    return count;
  }

  List<Position> _orderedMoves({
    required GameSnapshot snapshot,
    required Player player,
  }) {
    if (snapshot.status != GameStatus.playing) {
      return const [];
    }
    if (snapshot.currentPlayer != player) {
      return const [];
    }

    final legal = shiftAvailablePositions(snapshot);
    if (legal.isEmpty) {
      return const [];
    }

    final wins = shiftWinningMovesFor(snapshot: snapshot, player: player);
    if (wins.isNotEmpty) {
      return wins;
    }

    final opponent = player.opponent;
    final threat = findShiftImmediateThreat(
      snapshot: snapshot,
      threateningPlayer: opponent,
    );
    if (threat != null && legal.contains(threat)) {
      final blocks = <Position>[threat];
      final rest = legal.where((p) => p != threat).toList(growable: false);
      return [...blocks, ...sortShiftPositionsStable(rest)];
    }

    return sortShiftPositionsStable(legal);
  }
}

GameSnapshot _asPlayerTurn(GameSnapshot snapshot, Player player) {
  return GameSnapshot(
    xMoves: snapshot.xMoves,
    oMoves: snapshot.oMoves,
    currentPlayer: player,
    turnIndex: snapshot.turnIndex,
    status: GameStatus.playing,
    winningLine: null,
    winner: null,
  );
}
