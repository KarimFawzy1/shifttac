import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/game_constants.dart';
import '../../domain/logic/game_engine.dart';
import '../../domain/models/position.dart';
import 'game_state.dart';

/// Coordinates UI state with [GameEngine]; does not implement gameplay rules.
class GameCubit extends Cubit<GameState> {
  GameCubit() : super(GameState.initial()) {
    _matchStopwatch.start();
  }

  final Stopwatch _matchStopwatch = Stopwatch();
  Timer? _inputUnlockTimer;

  @override
  Future<void> close() {
    _inputUnlockTimer?.cancel();
    return super.close();
  }

  void onCellTapped(Position p) {
    if (state.inputLocked) {
      return;
    }

    final result = GameEngine.attemptMove(
      snapshot: state.snapshot,
      position: p,
    );

    if (!result.moveAccepted) {
      return;
    }

    _inputUnlockTimer?.cancel();
    emit(
      state.copyWith(
        snapshot: result.snapshot,
        inputLocked: true,
        lastPlacedPosition: result.placedMove?.position,
        lastRemovedPosition: result.removedMove?.position,
        matchDurationMs: _matchStopwatch.elapsedMilliseconds,
      ),
    );

    _inputUnlockTimer = Timer(
      const Duration(milliseconds: GameConstants.inputLockMs),
      () {
        if (isClosed) {
          return;
        }
        emit(state.copyWith(inputLocked: false));
      },
    );
  }

  void restart() {
    _inputUnlockTimer?.cancel();
    _inputUnlockTimer = null;
    _matchStopwatch
      ..reset()
      ..start();
    emit(GameState.initial());
  }

  void clearLastEventMarkers() {
    emit(
      state.copyWith(
        lastPlacedPosition: null,
        lastRemovedPosition: null,
      ),
    );
  }
}
