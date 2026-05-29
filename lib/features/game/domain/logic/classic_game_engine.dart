import 'package:shifttac/core/constants/game_constants.dart';

import '../models/game_mode.dart';
import '../models/game_status.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/position.dart';
import 'game_engine_result.dart';
import 'game_rules.dart';
import 'game_snapshot.dart';
import 'win_checker.dart';

/// Classic 3×3 Tic Tac Toe: every mark stays on the board until the match ends.
class ClassicGameEngine implements GameRules {
  const ClassicGameEngine._();

  static const ClassicGameEngine instance = ClassicGameEngine._();

  static GameSnapshot restart() => instance.initial();

  @override
  GameMode get mode => GameMode.classic;

  @override
  GameSnapshot initial() => GameSnapshot.initial();

  @override
  Position? oldestPositionFor(Player player, GameSnapshot snapshot) => null;

  @override
  GameEngineResult attemptMove({
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
    final moves = player == Player.x ? xMoves : oMoves;

    final placedMove = Move(
      player: player,
      position: position,
      turnIndex: snapshot.turnIndex,
    );
    moves.add(placedMove);

    final nextTurnIndex = snapshot.turnIndex + 1;
    final winningLine = WinChecker.findWinningLine(
      activeMoves: moves,
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
        removedMove: null,
        placedMove: placedMove,
      );
    }

    final occupiedCells = xMoves.length + oMoves.length;
    if (occupiedCells >= GameConstants.boardCellCount) {
      final next = GameSnapshot(
        xMoves: xMoves,
        oMoves: oMoves,
        currentPlayer: player,
        turnIndex: nextTurnIndex,
        status: GameStatus.draw,
        winningLine: null,
        winner: null,
      );
      return GameEngineResult(
        snapshot: next,
        moveAccepted: true,
        removedMove: null,
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
      removedMove: null,
      placedMove: placedMove,
    );
  }

  bool _isOccupied(GameSnapshot snapshot, Position position) {
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
