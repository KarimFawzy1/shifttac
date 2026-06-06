import 'package:equatable/equatable.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

import '../../data/models/tiki_board.dart';
import 'tiki_cell.dart';
import 'tiki_game_status.dart';

/// In-memory match state for 1 Player Tiki-Taka.
class TikiGameState extends Equatable {
  const TikiGameState({
    required this.status,
    this.board,
    this.cells = const [],
    this.usedPlayerIds = const {},
    this.hearts = startingHearts,
    this.elapsed = Duration.zero,
    this.winningLine,
  });

  static const int startingHearts = 5;
  static const int boardCellCount = 9;

  final TikiGameStatus status;
  final TikiBoard? board;
  final List<TikiCell> cells;
  final Set<String> usedPlayerIds;
  final int hearts;
  final Duration elapsed;
  final List<Position>? winningLine;

  bool get isPlayable =>
      status == TikiGameStatus.ongoing || status == TikiGameStatus.continuing;

  int get filledCellCount => cells.where((cell) => cell.isFilled).length;

  TikiCell cellAt(int row, int col) {
    return cells.firstWhere((cell) => cell.row == row && cell.col == col);
  }

  TikiGameState copyWith({
    TikiGameStatus? status,
    TikiBoard? board,
    List<TikiCell>? cells,
    Set<String>? usedPlayerIds,
    int? hearts,
    Duration? elapsed,
    List<Position>? winningLine,
    bool clearWinningLine = false,
  }) {
    return TikiGameState(
      status: status ?? this.status,
      board: board ?? this.board,
      cells: cells ?? this.cells,
      usedPlayerIds: usedPlayerIds ?? this.usedPlayerIds,
      hearts: hearts ?? this.hearts,
      elapsed: elapsed ?? this.elapsed,
      winningLine: clearWinningLine ? null : (winningLine ?? this.winningLine),
    );
  }

  @override
  List<Object?> get props => [
    status,
    board,
    cells,
    usedPlayerIds,
    hearts,
    elapsed,
    winningLine,
  ];
}
