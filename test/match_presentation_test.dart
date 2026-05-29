import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/widgets/match_presentation.dart';

GameSnapshot _drawSnapshot() {
  return GameSnapshot(
    xMoves: const [],
    oMoves: const [],
    currentPlayer: Player.x,
    turnIndex: 9,
    status: GameStatus.draw,
  );
}

GameSnapshot _xWinSnapshot() {
  return GameSnapshot(
    xMoves: const [],
    oMoves: const [],
    currentPlayer: Player.x,
    turnIndex: 5,
    status: GameStatus.won,
    winner: Player.x,
    winningLine: const [
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 0, col: 2),
    ],
  );
}

void main() {
  group('match presentation — draw state', () {
    test('turn indicator shows draw label, not a winner', () {
      expect(playerTurnIndicatorLabel(_drawSnapshot()), 'Draw');
      expect(playerTurnIndicatorLabel(_drawSnapshot()), isNot(contains('wins')));
    });

    test('player panels show neutral draw subtitle', () {
      final snapshot = _drawSnapshot();

      expect(
        playerPanelSubtitle(snapshot: snapshot, player: Player.x),
        'DRAW',
      );
      expect(
        playerPanelSubtitle(snapshot: snapshot, player: Player.o),
        'DRAW',
      );
    });

    test('no player panel is highlighted on draw', () {
      final snapshot = _drawSnapshot();

      expect(
        playerPanelHighlighted(snapshot: snapshot, player: Player.x),
        isFalse,
      );
      expect(
        playerPanelHighlighted(snapshot: snapshot, player: Player.o),
        isFalse,
      );
    });

    test('winner label still appears for won matches', () {
      final snapshot = _xWinSnapshot();

      expect(playerTurnIndicatorLabel(snapshot), 'X wins!');
      expect(
        playerPanelSubtitle(snapshot: snapshot, player: Player.x),
        'WINNER',
      );
      expect(
        playerPanelHighlighted(snapshot: snapshot, player: Player.x),
        isTrue,
      );
    });
  });

  group('match presentation — AI classic', () {
    GameSnapshot playingBotTurn() {
      return GameSnapshot(
        xMoves: const [],
        oMoves: const [],
        currentPlayer: Player.o,
        turnIndex: 1,
        status: GameStatus.playing,
      );
    }

    test('panel titles distinguish you from AI', () {
      expect(
        playerPanelTitle(
          player: Player.x,
          isAiSession: true,
          humanPlayer: Player.x,
        ),
        'You',
      );
      expect(
        playerPanelTitle(
          player: Player.o,
          isAiSession: true,
          humanPlayer: Player.x,
        ),
        'AI',
      );
    });

    test('local panels keep Player X and Player O titles', () {
      expect(playerPanelTitle(player: Player.x), 'Player X');
      expect(playerPanelTitle(player: Player.o), 'Player O');
    });

    test('turn indicator shows bot thinking on bot turn', () {
      final snapshot = playingBotTurn();
      expect(
        playerTurnIndicatorLabel(
          snapshot,
          isAiSession: true,
          botPlayer: Player.o,
        ),
        'Bot thinking...',
      );
    });

    test('bot panel shows THINKING with waiting dots on bot turn', () {
      final snapshot = playingBotTurn();
      expect(
        playerPanelSubtitle(
          snapshot: snapshot,
          player: Player.o,
          isAiSession: true,
          botPlayer: Player.o,
        ),
        'THINKING',
      );
      expect(
        playerPanelShowsWaitingDots(
          snapshot: snapshot,
          player: Player.o,
          isAiSession: true,
          botPlayer: Player.o,
        ),
        isTrue,
      );
    });
  });
}
