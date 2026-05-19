import '../../../game/presentation/widgets/board_cell.dart';
import '../../../onboarding/presentation/widgets/mini_board_preview.dart';

/// Static mini-board frames for the How to Play screen.
abstract final class HowToPlayBoardFrames {
  HowToPlayBoardFrames._();

  /// Familiar tic-tac-toe starting position.
  static final classicStart = MiniBoardFrame(const [
    BoardCellAppearance.empty,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
  ]);

  /// Both players at the three-mark limit (row-major, 1-based rows/cols).
  ///
  /// X: (1,1), (2,2), (3,1) — O: (1,2), (2,3), (3,3).
  static final threeActiveMarks = MiniBoardFrame(const [
    BoardCellAppearance.xFaded, // row 1, col 1
    BoardCellAppearance.oFaded, // row 1, col 2
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.xSolid, // row 2, col 2
    BoardCellAppearance.oSolid, // row 2, col 3
    BoardCellAppearance.xSolid, // row 3, col 1
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid, // row 3, col 3
  ]);

  /// Winning horizontal line for player X.
  static final winRow = MiniBoardFrame(const [
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.empty,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.xSolid,
    BoardCellAppearance.empty,
    BoardCellAppearance.oSolid,
    BoardCellAppearance.empty,
  ]);
}
