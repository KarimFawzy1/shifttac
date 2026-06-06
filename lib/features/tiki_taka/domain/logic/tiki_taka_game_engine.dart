import 'package:shifttac/features/game/domain/logic/win_checker.dart';
import 'package:shifttac/features/game/domain/models/move.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';

import '../../data/models/tiki_board.dart';
import '../../data/models/tiki_player_search_result.dart';
import '../models/tiki_cell.dart';
import '../models/tiki_game_state.dart';
import '../models/tiki_game_status.dart';
import '../services/answer_validator.dart';

/// Outcome of applying one answer attempt to the engine.
class TikiAnswerResult {
  const TikiAnswerResult({
    required this.state,
    required this.accepted,
    this.rejectionReason,
  });

  final TikiGameState state;
  final bool accepted;
  final AnswerValidationReason? rejectionReason;
}

/// Pure 1 Player Tiki-Taka rules engine (no UI, no timer scheduling).
class TikiTakaGameEngine {
  const TikiTakaGameEngine._();

  static const TikiTakaGameEngine instance = TikiTakaGameEngine._();

  TikiGameState initial() => const TikiGameState(status: TikiGameStatus.initial);

  TikiGameState beginLoadingBoard(TikiGameState state) {
    return state.copyWith(status: TikiGameStatus.loadingBoard);
  }

  TikiGameState boardLoaded(TikiGameState state, TikiBoard board) {
    return TikiGameState(
      status: TikiGameStatus.ongoing,
      board: board,
      cells: TikiCell.emptyBoard(),
      usedPlayerIds: const {},
      hearts: TikiGameState.startingHearts,
      elapsed: Duration.zero,
      winningLine: null,
    );
  }

  TikiGameState continuePlaying(TikiGameState state) {
    if (state.status != TikiGameStatus.firstWin) {
      return state;
    }

    return state.copyWith(status: TikiGameStatus.continuing);
  }

  TikiGameState updateElapsed(TikiGameState state, Duration elapsed) {
    if (!_timerActive(state.status)) {
      return state;
    }

    return state.copyWith(elapsed: elapsed);
  }

  TikiAnswerResult attemptAnswer({
    required TikiGameState state,
    required int row,
    required int col,
    required TikiPlayerSearchResult player,
    required AnswerValidationResult validation,
  }) {
    if (!state.isPlayable) {
      return TikiAnswerResult(state: state, accepted: false);
    }

    final cell = state.cellAt(row, col);
    if (cell.isFilled) {
      return TikiAnswerResult(state: state, accepted: false);
    }

    if (!validation.isValid) {
      final nextHearts = state.hearts - 1;
      return TikiAnswerResult(
        state: state.copyWith(
          hearts: nextHearts,
          status: nextHearts == 0 ? TikiGameStatus.lost : state.status,
        ),
        accepted: false,
        rejectionReason: validation.reason,
      );
    }

    final validatedPlayer = validation.player ?? player;
    final updatedCells = state.cells
        .map(
          (current) => current.row == row && current.col == col
              ? current.copyWith(player: validatedPlayer)
              : current,
        )
        .toList(growable: false);

    final usedPlayerIds = {
      ...state.usedPlayerIds,
      validatedPlayer.id,
    };
    final filledCount = updatedCells.where((item) => item.isFilled).length;
    final winningLine = _findWinningLine(updatedCells);
    final nextStatus = _resolveStatusAfterValidFill(
      currentStatus: state.status,
      filledCount: filledCount,
      winningLine: winningLine,
    );

    return TikiAnswerResult(
      state: state.copyWith(
        cells: updatedCells,
        usedPlayerIds: usedPlayerIds,
        winningLine: winningLine,
        status: nextStatus,
      ),
      accepted: true,
    );
  }

  TikiGameStatus _resolveStatusAfterValidFill({
    required TikiGameStatus currentStatus,
    required int filledCount,
    required List<Position>? winningLine,
  }) {
    if (filledCount >= TikiGameState.boardCellCount) {
      return TikiGameStatus.completed;
    }

    if (winningLine != null && currentStatus == TikiGameStatus.ongoing) {
      return TikiGameStatus.firstWin;
    }

    return currentStatus;
  }

  List<Position>? _findWinningLine(List<TikiCell> cells) {
    final moves = <Move>[];
    var turnIndex = 0;

    for (final cell in cells) {
      if (!cell.isFilled) {
        continue;
      }

      moves.add(
        Move(
          player: Player.x,
          position: Position(row: cell.row, col: cell.col),
          turnIndex: turnIndex,
        ),
      );
      turnIndex++;
    }

    return WinChecker.findWinningLine(activeMoves: moves, player: Player.x);
  }

  bool _timerActive(TikiGameStatus status) {
    return switch (status) {
      TikiGameStatus.ongoing ||
      TikiGameStatus.continuing ||
      TikiGameStatus.firstWin => true,
      TikiGameStatus.initial ||
      TikiGameStatus.loadingBoard ||
      TikiGameStatus.completed ||
      TikiGameStatus.lost => false,
    };
  }
}
