import '../../domain/logic/game_snapshot.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';

/// Terminal match outcome shown in [MatchResultDialog].
enum MatchResultKind { xWin, oWin, draw }

class MatchResult {
  const MatchResult({
    required this.kind,
    required this.totalMoves,
    required this.matchDurationMs,
  });

  final MatchResultKind kind;
  final int totalMoves;
  final int matchDurationMs;

  static MatchResult? fromSnapshot(GameSnapshot snapshot) {
    return switch (snapshot.status) {
      GameStatus.won when snapshot.winner == Player.x => MatchResult(
        kind: MatchResultKind.xWin,
        totalMoves: snapshot.turnIndex,
        matchDurationMs: 0,
      ),
      GameStatus.won when snapshot.winner == Player.o => MatchResult(
        kind: MatchResultKind.oWin,
        totalMoves: snapshot.turnIndex,
        matchDurationMs: 0,
      ),
      GameStatus.draw => MatchResult(
        kind: MatchResultKind.draw,
        totalMoves: snapshot.turnIndex,
        matchDurationMs: 0,
      ),
      _ => null,
    };
  }

  factory MatchResult.xWin({
    required int totalMoves,
    required int matchDurationMs,
  }) => MatchResult(
    kind: MatchResultKind.xWin,
    totalMoves: totalMoves,
    matchDurationMs: matchDurationMs,
  );

  factory MatchResult.oWin({
    required int totalMoves,
    required int matchDurationMs,
  }) => MatchResult(
    kind: MatchResultKind.oWin,
    totalMoves: totalMoves,
    matchDurationMs: matchDurationMs,
  );

  factory MatchResult.draw({
    required int totalMoves,
    required int matchDurationMs,
  }) => MatchResult(
    kind: MatchResultKind.draw,
    totalMoves: totalMoves,
    matchDurationMs: matchDurationMs,
  );
}
