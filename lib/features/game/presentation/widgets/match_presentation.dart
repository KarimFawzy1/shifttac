import '../../domain/logic/game_snapshot.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';

String playerTurnIndicatorLabel(GameSnapshot snapshot) {
  switch (snapshot.status) {
    case GameStatus.won:
      return snapshot.winner == Player.x ? 'X wins!' : 'O wins!';
    case GameStatus.draw:
      return 'Draw';
    case GameStatus.playing:
      return snapshot.currentPlayer == Player.x ? "X's turn" : "O's turn";
    case GameStatus.idle:
      return '—';
  }
}

String playerPanelSubtitle({
  required GameSnapshot snapshot,
  required Player player,
}) {
  if (snapshot.status == GameStatus.draw) {
    return 'DRAW';
  }

  final isWinner = snapshot.status == GameStatus.won && snapshot.winner == player;
  if (isWinner) {
    return 'WINNER';
  }

  final isTurnActive =
      snapshot.status == GameStatus.playing && snapshot.currentPlayer == player;
  if (isTurnActive) {
    return 'YOUR TURN';
  }

  return 'Waiting';
}

bool playerPanelHighlighted({
  required GameSnapshot snapshot,
  required Player player,
}) {
  if (snapshot.status == GameStatus.draw) {
    return false;
  }

  final isWinner = snapshot.status == GameStatus.won && snapshot.winner == player;
  final isTurnActive =
      snapshot.status == GameStatus.playing && snapshot.currentPlayer == player;
  return isTurnActive || isWinner;
}

bool playerPanelShowsWaitingDots({
  required GameSnapshot snapshot,
  required Player player,
}) {
  return snapshot.status == GameStatus.playing &&
      snapshot.currentPlayer != player;
}
