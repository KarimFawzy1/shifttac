import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_engine_result.dart';
import 'game_snapshot.dart';
import 'shift_game_engine.dart';

/// Stable tie-break order for ShiftTac AI: center, corners, then sides.
const List<Position> shiftStableMoveOrder = [
  Position(row: 1, col: 1),
  Position(row: 0, col: 0),
  Position(row: 0, col: 2),
  Position(row: 2, col: 0),
  Position(row: 2, col: 2),
  Position(row: 0, col: 1),
  Position(row: 1, col: 0),
  Position(row: 1, col: 2),
  Position(row: 2, col: 1),
];

/// All cells currently marked by either player's active marks.
Set<Position> shiftOccupiedPositions(GameSnapshot snapshot) {
  return {
    ...snapshot.xMoves.map((move) => move.position),
    ...snapshot.oMoves.map((move) => move.position),
  };
}

/// Empty cells in [shiftStableMoveOrder].
List<Position> shiftAvailablePositions(GameSnapshot snapshot) {
  final occupied = shiftOccupiedPositions(snapshot);
  return shiftStableMoveOrder
      .where((position) => !occupied.contains(position))
      .toList(growable: false);
}

/// Reorders [positions] using [shiftStableMoveOrder].
List<Position> sortShiftPositionsStable(Iterable<Position> positions) {
  final set = positions is Set<Position> ? positions : positions.toSet();
  return shiftStableMoveOrder
      .where(set.contains)
      .toList(growable: false);
}

/// Applies a ShiftTac move via [ShiftGameEngine] without mutating [snapshot].
GameEngineResult simulateShiftMove({
  required GameSnapshot snapshot,
  required Position position,
}) {
  return ShiftGameEngine.instance.attemptMove(
    snapshot: snapshot,
    position: position,
  );
}

/// Returns a winning move for [player] on [snapshot.currentPlayer]'s turn, if any.
Position? findShiftImmediateWin({
  required GameSnapshot snapshot,
  required Player player,
}) {
  final wins = shiftWinningMovesFor(snapshot: snapshot, player: player);
  if (wins.isEmpty) {
    return null;
  }
  return wins.first;
}

/// Cells [threateningPlayer] could play to win on their turn (used to block).
Position? findShiftImmediateThreat({
  required GameSnapshot snapshot,
  required Player threateningPlayer,
}) {
  if (snapshot.status != GameStatus.playing) {
    return null;
  }

  final asThreatTurn = GameSnapshot(
    xMoves: snapshot.xMoves,
    oMoves: snapshot.oMoves,
    currentPlayer: threateningPlayer,
    turnIndex: snapshot.turnIndex,
    status: GameStatus.playing,
    winningLine: null,
    winner: null,
  );
  return findShiftImmediateWin(snapshot: asThreatTurn, player: threateningPlayer);
}

/// All legal moves that win immediately for [player] on their turn.
List<Position> shiftWinningMovesFor({
  required GameSnapshot snapshot,
  required Player player,
}) {
  if (snapshot.status != GameStatus.playing) {
    return const [];
  }
  if (snapshot.currentPlayer != player) {
    return const [];
  }

  final wins = <Position>[];
  for (final position in shiftAvailablePositions(snapshot)) {
    final result = simulateShiftMove(
      snapshot: snapshot,
      position: position,
    );
    if (!result.moveAccepted) {
      continue;
    }
    if (result.snapshot.status == GameStatus.won &&
        result.snapshot.winner == player) {
      wins.add(position);
    }
  }
  return wins;
}

/// Count of immediate winning moves for [player] on their turn.
int countImmediateWinsFor({
  required GameSnapshot snapshot,
  required Player player,
}) {
  return shiftWinningMovesFor(snapshot: snapshot, player: player).length;
}

/// Whether [candidate] lets [botPlayer]'s opponent win on the next turn.
bool allowsOpponentImmediateWin({
  required GameSnapshot snapshot,
  required Position candidate,
  required Player botPlayer,
}) {
  final result = simulateShiftMove(
    snapshot: snapshot,
    position: candidate,
  );
  if (!result.moveAccepted) {
    return false;
  }
  return findShiftImmediateThreat(
        snapshot: result.snapshot,
        threateningPlayer: botPlayer.opponent,
      ) !=
      null;
}

/// First empty cell from [order] on [snapshot], or null if none match.
Position? firstAvailableInShiftOrder(
  GameSnapshot snapshot,
  List<Position> order,
) {
  final occupied = shiftOccupiedPositions(snapshot);
  for (final position in order) {
    if (!occupied.contains(position)) {
      return position;
    }
  }
  return null;
}

/// Corner cells in stable order (subset of [shiftStableMoveOrder]).
const List<Position> shiftCornerPositions = [
  Position(row: 0, col: 0),
  Position(row: 0, col: 2),
  Position(row: 2, col: 0),
  Position(row: 2, col: 2),
];

/// Side cells in stable order (subset of [shiftStableMoveOrder]).
const List<Position> shiftSidePositions = [
  Position(row: 0, col: 1),
  Position(row: 1, col: 0),
  Position(row: 1, col: 2),
  Position(row: 2, col: 1),
];
