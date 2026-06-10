import '../models/move.dart';
import '../models/player.dart';
import '../models/position.dart';

class WinChecker {
  const WinChecker._();

  static const List<List<Position>> allLines = [
    [
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 0, col: 2),
    ],
    [
      Position(row: 1, col: 0),
      Position(row: 1, col: 1),
      Position(row: 1, col: 2),
    ],
    [
      Position(row: 2, col: 0),
      Position(row: 2, col: 1),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 0),
      Position(row: 1, col: 0),
      Position(row: 2, col: 0),
    ],
    [
      Position(row: 0, col: 1),
      Position(row: 1, col: 1),
      Position(row: 2, col: 1),
    ],
    [
      Position(row: 0, col: 2),
      Position(row: 1, col: 2),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 0),
      Position(row: 1, col: 1),
      Position(row: 2, col: 2),
    ],
    [
      Position(row: 0, col: 2),
      Position(row: 1, col: 1),
      Position(row: 2, col: 0),
    ],
  ];

  /// Full-board completion reveal: columns, rows, then diagonals.
  static final List<List<Position>> tikiCompletionRevealOrder = [
    allLines[3],
    allLines[4],
    allLines[5],
    allLines[0],
    allLines[1],
    allLines[2],
    allLines[6],
    allLines[7],
  ];

  static List<Position>? findWinningLine({
    required List<Move> activeMoves,
    required Player player,
  }) {
    final ownedPositions = activeMoves
        .where((move) => move.player == player)
        .map((move) => move.position)
        .toSet();

    for (final line in allLines) {
      if (line.every(ownedPositions.contains)) {
        return List<Position>.unmodifiable(line);
      }
    }

    return null;
  }
}
