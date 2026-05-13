import '../models/move.dart';
import '../models/player.dart';
import '../models/position.dart';

class WinChecker {
  const WinChecker._();

  static const List<List<Position>> _winningLines = [
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

  static List<Position>? findWinningLine({
    required List<Move> activeMoves,
    required Player player,
  }) {
    final ownedPositions = activeMoves
        .where((move) => move.player == player)
        .map((move) => move.position)
        .toSet();

    for (final line in _winningLines) {
      if (line.every(ownedPositions.contains)) {
        return List<Position>.unmodifiable(line);
      }
    }

    return null;
  }
}
