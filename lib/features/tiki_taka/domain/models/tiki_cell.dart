import 'package:equatable/equatable.dart';

import '../../data/models/tiki_player_search_result.dart';

/// One playable intersection on the 3×3 board.
class TikiCell extends Equatable {
  const TikiCell({
    required this.row,
    required this.col,
    this.player,
  });

  final int row;
  final int col;
  final TikiPlayerSearchResult? player;

  bool get isEmpty => player == null;
  bool get isFilled => player != null;

  TikiCell copyWith({TikiPlayerSearchResult? player, bool clearPlayer = false}) {
    return TikiCell(
      row: row,
      col: col,
      player: clearPlayer ? null : (player ?? this.player),
    );
  }

  static List<TikiCell> emptyBoard() {
    return [
      for (var row = 0; row < 3; row++)
        for (var col = 0; col < 3; col++) TikiCell(row: row, col: col),
    ];
  }

  @override
  List<Object?> get props => [row, col, player];
}
