import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/game_constants.dart';
import '../../domain/logic/classic_game_engine.dart';
import '../../domain/logic/game_rules.dart';
import '../../domain/logic/shift_game_engine.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/position.dart';
import 'game_state.dart';

/// Outcome of a board cell tap for haptics and UI feedback.
enum CellTapResult {
  accepted,
  rejectedInvalid,
  rejectedLocked,
  rejectedNotPlaying,
}

/// Coordinates UI lifecycle with a [GameRules] implementation.
class GameCubit extends Cubit<GameState> {
  GameCubit({required GameRules rules})
    : _rules = rules,
      super(GameState.initialFor(rules)) {
    _matchStopwatch.start();
    _startMatchDurationTicker();
  }

  GameCubit.shift() : this(rules: ShiftGameEngine.instance);

  GameCubit.classic() : this(rules: ClassicGameEngine.instance);

  final GameRules _rules;

  GameMode get mode => _rules.mode;

  final Stopwatch _matchStopwatch = Stopwatch();
  Timer? _inputUnlockTimer;
  Timer? _matchDurationTicker;
  bool _matchPaused = false;
  bool _pauseSheetRequestedForBackground = false;
  int _inputLockGeneration = 0;

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

  CellTapResult onCellTapped(Position p) {
    if (state.snapshot.status != GameStatus.playing) {
      return CellTapResult.rejectedNotPlaying;
    }

    if (state.inputLocked) {
      return CellTapResult.rejectedLocked;
    }

    final result = _rules.attemptMove(
      snapshot: state.snapshot,
      position: p,
    );

    if (!result.moveAccepted) {
      return CellTapResult.rejectedInvalid;
    }

    _inputUnlockTimer?.cancel();
    final lockGeneration = ++_inputLockGeneration;
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
        if (isClosed || lockGeneration != _inputLockGeneration) {
          return;
        }
        emit(state.copyWith(inputLocked: false));
      },
    );
    return CellTapResult.accepted;
  }

  void restart() {
    _matchPaused = false;
    _pauseSheetRequestedForBackground = false;
    _inputUnlockTimer?.cancel();
    _inputUnlockTimer = null;
    _inputLockGeneration++;
    _matchDurationTicker?.cancel();
    _matchDurationTicker = null;
    _matchStopwatch
      ..reset()
      ..start();
    emit(GameState.initialFor(_rules));
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
