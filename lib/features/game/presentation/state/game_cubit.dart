import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/game_constants.dart';
import '../../domain/logic/game_engine.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/position.dart';
import 'game_state.dart';

/// Coordinates UI state with [GameEngine]; does not implement gameplay rules.
class GameCubit extends Cubit<GameState> {
  GameCubit() : super(GameState.initial()) {
    _matchStopwatch.start();
    _startMatchDurationTicker();
  }

  final Stopwatch _matchStopwatch = Stopwatch();
  Timer? _inputUnlockTimer;
  Timer? _matchDurationTicker;

  @override
  Future<void> close() {
    _inputUnlockTimer?.cancel();
    _matchDurationTicker?.cancel();
    return super.close();
  }

  void _startMatchDurationTicker() {
    _matchDurationTicker?.cancel();
    _matchDurationTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitElapsedIfPlaying(),
    );
    _emitElapsedIfPlaying();
  }

  void _emitElapsedIfPlaying() {
    if (isClosed) {
      return;
    }
    if (state.snapshot.status != GameStatus.playing) {
      _matchDurationTicker?.cancel();
      _matchDurationTicker = null;
      return;
    }
    final ms = _matchStopwatch.elapsedMilliseconds;
    if (ms == state.matchDurationMs) {
      return;
    }
    emit(state.copyWith(matchDurationMs: ms));
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
    _matchDurationTicker?.cancel();
    _matchDurationTicker = null;
    _matchStopwatch
      ..reset()
      ..start();
    emit(GameState.initial());
    _startMatchDurationTicker();
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
