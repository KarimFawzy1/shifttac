import '../../../../core/constants/game_constants.dart';
import '../../domain/logic/game_rules.dart';
import '../../domain/logic/game_snapshot.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../../domain/models/position.dart';
import 'board_cell.dart';

/// Whether board taps should be ignored for the current match status.
bool isBoardFrozen(GameStatus status) => status != GameStatus.playing;

Player? occupantAt(GameSnapshot snapshot, Position position) {
  for (final m in snapshot.xMoves) {
    if (m.position == position) {
      return Player.x;
    }
  }
  for (final m in snapshot.oMoves) {
    if (m.position == position) {
      return Player.o;
    }
  }
  return null;
}

/// Maps engine snapshot and active rules to per-cell board visuals.
BoardCellAppearance boardCellAppearanceFor({
  required GameRules rules,
  required GameSnapshot snapshot,
  required Position position,
}) {
  final occupant = occupantAt(snapshot, position);
  if (occupant == null) {
    return BoardCellAppearance.empty;
  }

  final playing = snapshot.status == GameStatus.playing;
  final faded = rules.mode == GameMode.shift &&
      playing &&
      snapshot.movesFor(snapshot.currentPlayer).length >=
          GameConstants.maxActiveMarks &&
      rules.oldestPositionFor(snapshot.currentPlayer, snapshot) == position &&
      occupant == snapshot.currentPlayer;

  if (occupant == Player.x) {
    return faded ? BoardCellAppearance.xFaded : BoardCellAppearance.xSolid;
  }
  return faded ? BoardCellAppearance.oFaded : BoardCellAppearance.oSolid;
}
