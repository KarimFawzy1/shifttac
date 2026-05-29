import 'dart:math';

import '../models/game_status.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/position.dart';

/// Authoritative game state shared by all local modes.
///
/// Move lists are ordered oldest → newest (index `0` is the oldest mark).
/// ShiftTac caps active marks per player; classic keeps every mark on the board.
class GameSnapshot {
  GameSnapshot({
    required List<Move> xMoves,
    required List<Move> oMoves,
    required this.currentPlayer,
    required this.turnIndex,
    required this.status,
    this.winningLine,
    this.winner,
  }) : xMoves = List<Move>.unmodifiable(xMoves),
       oMoves = List<Move>.unmodifiable(oMoves);

  factory GameSnapshot.initial({Player? startingPlayer}) {
    final first =
        startingPlayer ??
        (Random().nextBool() ? Player.x : Player.o);
    return GameSnapshot(
      xMoves: const [],
      oMoves: const [],
      currentPlayer: first,
      turnIndex: 0,
      status: GameStatus.playing,
      winningLine: null,
      winner: null,
    );
  }

  final List<Move> xMoves;
  final List<Move> oMoves;
  final Player currentPlayer;
  final int turnIndex;
  final GameStatus status;
  final List<Position>? winningLine;
  final Player? winner;

  List<Move> movesFor(Player player) => player == Player.x ? xMoves : oMoves;
}
