import '../models/game_status.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'classic_game_engine.dart';
import 'game_engine_result.dart';
import 'game_snapshot.dart';

/// Stable tie-break order for classic AI: center, corners, then sides.
const List<Position> classicStableMoveOrder = [
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

/// All cells currently marked by either player.
Set<Position> occupiedPositions(GameSnapshot snapshot) {
  return {
    ...snapshot.xMoves.map((move) => move.position),
    ...snapshot.oMoves.map((move) => move.position),
  };
}

/// Empty cells in [classicStableMoveOrder].
List<Position> availablePositions(GameSnapshot snapshot) {
  final occupied = occupiedPositions(snapshot);
  return classicStableMoveOrder
      .where((position) => !occupied.contains(position))
      .toList(growable: false);
}

/// Reorders [positions] using [classicStableMoveOrder].
List<Position> sortPositionsStable(Iterable<Position> positions) {
  final set = positions is Set<Position> ? positions : positions.toSet();
  return classicStableMoveOrder
      .where(set.contains)
      .toList(growable: false);
}

/// Applies a classic move via [ClassicGameEngine] without side effects on [snapshot].
GameEngineResult simulateClassicMove({
  required GameSnapshot snapshot,
  required Position position,
}) {
  return ClassicGameEngine.instance.attemptMove(
    snapshot: snapshot,
    position: position,
  );
}

/// Returns a winning move for [player] on [snapshot.currentPlayer]'s turn, if any.
Position? findImmediateWin({
  required GameSnapshot snapshot,
  required Player player,
}) {
  if (snapshot.status != GameStatus.playing) {
    return null;
  }
  if (snapshot.currentPlayer != player) {
    return null;
  }

  for (final position in availablePositions(snapshot)) {
    final result = simulateClassicMove(
      snapshot: snapshot,
      position: position,
    );
    if (!result.moveAccepted) {
      continue;
    }
    if (result.snapshot.status == GameStatus.won &&
        result.snapshot.winner == player) {
      return position;
    }
  }
  return null;
}

/// Cells [threateningPlayer] could play to win on their turn (used to block).
Position? findImmediateThreat({
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
  return findImmediateWin(snapshot: asThreatTurn, player: threateningPlayer);
}

/// First empty cell from [order] on [snapshot], or null if none match.
Position? firstAvailableInOrder(
  GameSnapshot snapshot,
  List<Position> order,
) {
  final available = occupiedPositions(snapshot);
  for (final position in order) {
    if (!available.contains(position)) {
      return position;
    }
  }
  return null;
}

/// Corner cells in stable order (subset of [classicStableMoveOrder]).
const List<Position> classicCornerPositions = [
  Position(row: 0, col: 0),
  Position(row: 0, col: 2),
  Position(row: 2, col: 0),
  Position(row: 2, col: 2),
];

/// Side cells in stable order (subset of [classicStableMoveOrder]).
const List<Position> classicSidePositions = [
  Position(row: 0, col: 1),
  Position(row: 1, col: 0),
  Position(row: 1, col: 2),
  Position(row: 2, col: 1),
];
