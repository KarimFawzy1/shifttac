import '../../domain/logic/game_snapshot.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';

/// Human-readable panel title; local multiplayer keeps "Player X" / "Player O".
String playerPanelTitle({
  required Player player,
  bool isAiSession = false,
  Player? humanPlayer,
}) {
  if (!isAiSession) {
    return player == Player.x ? 'Player X' : 'Player O';
  }
  if (humanPlayer == player) {
    return 'You';
  }
  return 'AI';
}

String playerTurnIndicatorLabel(
  GameSnapshot snapshot, {
  bool isAiSession = false,
  Player? botPlayer,
}) {
  switch (snapshot.status) {
    case GameStatus.won:
      return snapshot.winner == Player.x ? 'X wins!' : 'O wins!';
    case GameStatus.draw:
      return 'Draw';
    case GameStatus.playing:
      if (isAiSession && botPlayer == snapshot.currentPlayer) {
        return 'Bot thinking...';
      }
      return snapshot.currentPlayer == Player.x ? "X's turn" : "O's turn";
    case GameStatus.idle:
      return '—';
  }
}

String playerPanelSubtitle({
  required GameSnapshot snapshot,
  required Player player,
  bool isAiSession = false,
  Player? botPlayer,
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
    if (isAiSession && botPlayer == player) {
      return 'THINKING';
    }
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
  bool isAiSession = false,
  Player? botPlayer,
}) {
  if (snapshot.status != GameStatus.playing) {
    return false;
  }

  if (!isAiSession) {
    return snapshot.currentPlayer != player;
  }

  if (botPlayer == player && snapshot.currentPlayer == player) {
    return true;
  }

  return snapshot.currentPlayer != player;
}
