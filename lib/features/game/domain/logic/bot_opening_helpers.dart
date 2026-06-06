import '../models/player.dart';
import '../models/position.dart';
import 'game_snapshot.dart';

const Position botOpeningCenter = Position(row: 1, col: 1);

/// True when the bot opens the match as [Player.o] on an empty board.
bool isOBotOpeningTurn({
  required GameSnapshot snapshot,
  required Player botPlayer,
}) {
  return botPlayer == Player.o &&
      snapshot.turnIndex == 0 &&
      snapshot.xMoves.isEmpty &&
      snapshot.oMoves.isEmpty &&
      snapshot.currentPlayer == botPlayer;
}

/// Forces center on O's opening move in AI sessions; otherwise returns null.
Position? forcedOBotCenterOpening({
  required GameSnapshot snapshot,
  required Player botPlayer,
}) {
  if (!isOBotOpeningTurn(snapshot: snapshot, botPlayer: botPlayer)) {
    return null;
  }
  return botOpeningCenter;
}
