import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'bot_opening_helpers.dart';
import 'game_snapshot.dart';
import 'shift_bot_helpers.dart';
import 'shift_bot_strategy.dart';

/// Tactical ShiftTac bot: win, block, avoid blunders, fork preference, then position.
class ShiftIntermediateBotStrategy implements ShiftBotStrategy {
  const ShiftIntermediateBotStrategy();

  static const Position _center = Position(row: 1, col: 1);

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    if (snapshot.status != GameStatus.playing) {
      throw StateError('ShiftIntermediateBotStrategy: match is not in progress');
    }
    if (snapshot.currentPlayer != botPlayer) {
      throw StateError('ShiftIntermediateBotStrategy: not the bot turn');
    }

    final opening = forcedOBotCenterOpening(
      snapshot: snapshot,
      botPlayer: botPlayer,
    );
    if (opening != null) {
      return opening;
    }

    final win = findShiftImmediateWin(snapshot: snapshot, player: botPlayer);
    if (win != null) {
      return win;
    }

    final block = findShiftImmediateThreat(
      snapshot: snapshot,
      threateningPlayer: botPlayer.opponent,
    );
    if (block != null) {
      return block;
    }

    final legal = shiftAvailablePositions(snapshot);
    if (legal.isEmpty) {
      throw StateError('ShiftIntermediateBotStrategy: no legal moves');
    }

    final safe = legal
        .where(
          (position) => !allowsOpponentImmediateWin(
            snapshot: snapshot,
            candidate: position,
            botPlayer: botPlayer,
          ),
        )
        .toList(growable: false);
    final candidates = safe.isNotEmpty ? safe : legal;

    final forkMove = _bestByForkCount(snapshot, botPlayer, candidates);
    if (forkMove != null) {
      return forkMove;
    }

    final positional = _positionalPick(snapshot, candidates);
    if (positional != null) {
      return positional;
    }

    return sortShiftPositionsStable(candidates).first;
  }

  Position? _bestByForkCount(
    GameSnapshot snapshot,
    Player botPlayer,
    List<Position> candidates,
  ) {
    Position? best;
    var bestCount = -1;

    for (final position in candidates) {
      final count = _forkCountAfterMove(snapshot, botPlayer, position);
      if (count > bestCount) {
        bestCount = count;
        best = position;
      }
    }

    if (best == null || bestCount <= 0) {
      return null;
    }

    final tied = candidates
        .where((position) => _forkCountAfterMove(snapshot, botPlayer, position) == bestCount)
        .toList(growable: false);
    return _positionalPick(snapshot, tied) ?? tied.first;
  }

  int _forkCountAfterMove(
    GameSnapshot snapshot,
    Player botPlayer,
    Position position,
  ) {
    final result = simulateShiftMove(snapshot: snapshot, position: position);
    if (!result.moveAccepted) {
      return -1;
    }
    return countImmediateWinsFor(
      snapshot: _asPlayerTurn(result.snapshot, botPlayer),
      player: botPlayer,
    );
  }

  Position? _positionalPick(GameSnapshot snapshot, List<Position> candidates) {
    if (candidates.isEmpty) {
      return null;
    }

    final center = firstAvailableInShiftOrder(snapshot, const [_center]);
    if (center != null && candidates.contains(center)) {
      return center;
    }

    for (final position in shiftCornerPositions) {
      if (candidates.contains(position) &&
          !shiftOccupiedPositions(snapshot).contains(position)) {
        return position;
      }
    }

    for (final position in shiftSidePositions) {
      if (candidates.contains(position) &&
          !shiftOccupiedPositions(snapshot).contains(position)) {
        return position;
      }
    }

    return sortShiftPositionsStable(candidates).first;
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
