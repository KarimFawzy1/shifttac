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
  bool _matchPaused = false;
  bool _pauseSheetRequestedForBackground = false;

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

  void pauseMatch() {
    if (_matchPaused) {
      return;
    }
    _matchPaused = true;
    _matchStopwatch.stop();
    _matchDurationTicker?.cancel();
    _matchDurationTicker = null;
  }

  void resumeMatch() {
    if (!_matchPaused || isClosed) {
      return;
    }
    _matchPaused = false;
    _pauseSheetRequestedForBackground = false;
    if (state.snapshot.status == GameStatus.playing) {
      _matchStopwatch.start();
      _startMatchDurationTicker();
    }
  }

  /// Pauses an in-progress match when the app leaves the foreground.
  void onAppBackgrounded() {
    if (state.snapshot.status != GameStatus.playing) {
      return;
    }
    final wasRunning = !_matchPaused;
    pauseMatch();
    if (wasRunning) {
      _pauseSheetRequestedForBackground = true;
    }
  }

  /// Whether the pause menu should open after returning from the background.
  bool get shouldPresentPauseAfterBackground =>
      _pauseSheetRequestedForBackground &&
      state.snapshot.status == GameStatus.playing;

  void clearPauseSheetRequestForBackground() {
    _pauseSheetRequestedForBackground = false;
  }

  void _emitElapsedIfPlaying() {
    if (isClosed) {
      return;
    }
    if (_matchPaused || state.snapshot.status != GameStatus.playing) {
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
    _matchPaused = false;
    _pauseSheetRequestedForBackground = false;
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
