import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/presentation/widgets/match_result.dart';

void main() {
  group('MatchResult.fromSnapshot', () {
    test('maps X win, O win, and draw', () {
      expect(
        MatchResult.fromSnapshot(
          GameSnapshot(
            xMoves: const [],
            oMoves: const [],
            currentPlayer: Player.o,
            turnIndex: 5,
            status: GameStatus.won,
            winner: Player.x,
          ),
        )?.kind,
        MatchResultKind.xWin,
      );
      expect(
        MatchResult.fromSnapshot(
          GameSnapshot(
            xMoves: const [],
            oMoves: const [],
            currentPlayer: Player.x,
            turnIndex: 6,
            status: GameStatus.won,
            winner: Player.o,
          ),
        )?.kind,
        MatchResultKind.oWin,
      );
      expect(
        MatchResult.fromSnapshot(
          GameSnapshot(
            xMoves: const [],
            oMoves: const [],
            currentPlayer: Player.x,
            turnIndex: 9,
            status: GameStatus.draw,
          ),
        )?.kind,
        MatchResultKind.draw,
      );
    });

    test('returns null for non-terminal statuses', () {
      expect(
        MatchResult.fromSnapshot(GameSnapshot.initial(startingPlayer: Player.x)),
        isNull,
      );
    });
  });
}
