import 'package:shifttac/core/constants/game_constants.dart';
import '../models/game_status.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_snapshot.dart';
import 'win_checker.dart';

class GameEngineResult {
  const GameEngineResult({
    required this.snapshot,
    required this.moveAccepted,
    this.removedMove,
    this.placedMove,
  });

  final GameSnapshot snapshot;
  final bool moveAccepted;
  final Move? removedMove;
  final Move? placedMove;
}

/// Gameplay rules: FIFO rotation, then placement, then win evaluation (`rules.md` §7).
class GameEngine {
  GameEngine._();

  static GameSnapshot restart() => GameSnapshot.initial();

  static Position? oldestPositionFor(Player player, GameSnapshot snapshot) {
    final q = snapshot.movesFor(player);
    if (q.isEmpty) {
      return null;
    }
    return q.first.position;
  }

  static GameEngineResult attemptMove({
    required GameSnapshot snapshot,
    required Position position,
  }) {
    if (snapshot.status != GameStatus.playing) {
      return GameEngineResult(
        snapshot: snapshot,
        moveAccepted: false,
        removedMove: null,
        placedMove: null,
      );
    }

    if (_isOccupied(snapshot, position)) {
      return GameEngineResult(
        snapshot: snapshot,
        moveAccepted: false,
        removedMove: null,
        placedMove: null,
      );
    }

    final player = snapshot.currentPlayer;
    final xMoves = List<Move>.from(snapshot.xMoves);
    final oMoves = List<Move>.from(snapshot.oMoves);
    final queue = player == Player.x ? xMoves : oMoves;

    Move? removedMove;
    if (queue.length >= GameConstants.maxActiveMarks) {
      removedMove = queue.removeAt(0);
    }

    final placedMove = Move(
      player: player,
      position: position,
      turnIndex: snapshot.turnIndex,
    );
    queue.add(placedMove);

    final nextTurnIndex = snapshot.turnIndex + 1;
    final activeForMover = List<Move>.from(queue);
    final winningLine = WinChecker.findWinningLine(
      activeMoves: activeForMover,
      player: player,
    );

    if (winningLine != null) {
      final next = GameSnapshot(
        xMoves: xMoves,
        oMoves: oMoves,
        currentPlayer: player,
        turnIndex: nextTurnIndex,
        status: GameStatus.won,
        winningLine: winningLine,
        winner: player,
      );
      return GameEngineResult(
        snapshot: next,
        moveAccepted: true,
        removedMove: removedMove,
        placedMove: placedMove,
      );
    }

    final next = GameSnapshot(
      xMoves: xMoves,
      oMoves: oMoves,
      currentPlayer: player.opponent,
      turnIndex: nextTurnIndex,
      status: GameStatus.playing,
      winningLine: null,
      winner: null,
    );
    return GameEngineResult(
      snapshot: next,
      moveAccepted: true,
      removedMove: removedMove,
      placedMove: placedMove,
    );
  }

  static bool _isOccupied(GameSnapshot snapshot, Position position) {
    for (final m in snapshot.xMoves) {
      if (m.position == position) {
        return true;
      }
    }
    for (final m in snapshot.oMoves) {
      if (m.position == position) {
        return true;
      }
    }
    return false;
  }
}
