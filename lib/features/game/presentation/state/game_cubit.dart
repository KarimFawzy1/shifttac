import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/game_constants.dart';
import '../../domain/logic/classic_bot_strategy.dart';
import '../../domain/logic/classic_bot_strategy_factory.dart';
import '../../domain/logic/classic_game_engine.dart';
import '../../domain/logic/game_engine_result.dart';
import '../../domain/logic/game_rules.dart';
import '../../domain/logic/shift_game_engine.dart';
import '../../domain/models/bot_opponent_config.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/models/game_session_config.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
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
  GameCubit({
    required GameRules rules,
    BotOpponentConfig? bot,
    Player? startingPlayer,
    Random? botRandom,
    ClassicBotStrategy? botStrategy,
  }) : this._(
         rules: rules,
         bot: bot,
         startingPlayer: startingPlayer,
         matchRandom: botRandom,
         botStrategy: bot == null
             ? null
             : (botStrategy ??
                   ClassicBotStrategyFactory.forDifficulty(
                     bot.difficulty,
                     random: botRandom,
                   )),
         initialState: GameState.initialFor(
           rules,
           startingPlayer: startingPlayer,
         ),
       );

  GameCubit._({
    required GameRules rules,
    required BotOpponentConfig? bot,
    required Player? startingPlayer,
    required Random? matchRandom,
    required ClassicBotStrategy? botStrategy,
    required GameState initialState,
  }) : _rules = rules,
       _bot = bot,
       _startingPlayer = startingPlayer,
       _matchRandom = matchRandom,
       _botStrategy = botStrategy,
       super(initialState) {
    assert(
      bot == null || rules.mode == GameMode.classic,
      'Bot opponents are only supported in classic mode',
    );
    _matchStopwatch.start();
    _startMatchDurationTicker();
    _scheduleBotMoveIfNeeded();
  }

  GameCubit.shift() : this(rules: ShiftGameEngine.instance);

  GameCubit.classic() : this(rules: ClassicGameEngine.instance);

  /// Test-only entry point with a prebuilt [GameState].
  @visibleForTesting
  factory GameCubit.forTest({
    required GameRules rules,
    required GameState initialState,
    BotOpponentConfig? bot,
    Player? startingPlayer,
    ClassicBotStrategy? botStrategy,
  }) {
    final strategy =
        bot == null
            ? null
            : (botStrategy ??
                ClassicBotStrategyFactory.forDifficulty(bot.difficulty));
    return GameCubit._(
      rules: rules,
      bot: bot,
      startingPlayer: startingPlayer,
      matchRandom: null,
      botStrategy: strategy,
      initialState: initialState,
    );
  }

  factory GameCubit.fromSession(
    GameSessionConfig session, {
    Random? botRandom,
    ClassicBotStrategy? botStrategy,
  }) {
    final rules = switch (session.mode) {
      GameMode.shift => ShiftGameEngine.instance,
      GameMode.classic => ClassicGameEngine.instance,
    };
    return GameCubit(
      rules: rules,
      bot: session.bot,
      startingPlayer: session.startingPlayer,
      botRandom: botRandom,
      botStrategy: botStrategy,
    );
  }

  final GameRules _rules;
  final BotOpponentConfig? _bot;
  final Player? _startingPlayer;
  final Random? _matchRandom;
  final ClassicBotStrategy? _botStrategy;

  Player _randomAiStartingPlayer() {
    final rng = _matchRandom ?? Random();
    return rng.nextBool() ? humanPlayer! : botPlayer!;
  }

  GameMode get mode => _rules.mode;

  GameRules get rules => _rules;

  bool get isAiSession => _bot != null;

  Player? get humanPlayer => _bot?.botPlayer.opponent;

  Player? get botPlayer => _bot?.botPlayer;

  final Stopwatch _matchStopwatch = Stopwatch();
  Timer? _inputUnlockTimer;
  Timer? _botMoveTimer;
  Timer? _matchDurationTicker;
  bool _matchPaused = false;
  bool _pauseSheetRequestedForBackground = false;
  int _inputLockGeneration = 0;
  int _botMoveGeneration = 0;

  bool get _isBotTurn {
    final bot = _bot;
    return bot != null &&
        state.snapshot.status == GameStatus.playing &&
        state.snapshot.currentPlayer == bot.botPlayer;
  }

  /// Whether the human cannot place a mark because the bot is deciding.
  bool get isBotTurn => _isBotTurn;

  @override
  Future<void> close() {
    _cancelBotMove();
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
    _cancelBotMove();
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
      _scheduleBotMoveIfNeeded();
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

  void _cancelBotMove() {
    _botMoveTimer?.cancel();
    _botMoveTimer = null;
    _botMoveGeneration++;
  }

  CellTapResult onCellTapped(Position p) {
    if (state.snapshot.status != GameStatus.playing) {
      return CellTapResult.rejectedNotPlaying;
    }

    if (_isBotTurn) {
      return CellTapResult.rejectedLocked;
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

    _applyAcceptedMove(result);
    _scheduleBotMoveIfNeeded();
    return CellTapResult.accepted;
  }

  void _applyAcceptedMove(GameEngineResult result) {
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
  }

  void _scheduleBotMoveIfNeeded() {
    final bot = _bot;
    if (bot == null || _botStrategy == null || _matchPaused) {
      return;
    }
    if (state.snapshot.status != GameStatus.playing) {
      return;
    }
    if (state.snapshot.currentPlayer != bot.botPlayer) {
      return;
    }

    _botMoveTimer?.cancel();
    final generation = ++_botMoveGeneration;
    _botMoveTimer = Timer(
      const Duration(milliseconds: GameConstants.botMoveDelayMs),
      () => _performBotMove(generation),
    );
  }

  void _performBotMove(int generation) {
    if (isClosed || generation != _botMoveGeneration) {
      return;
    }
    if (_matchPaused) {
      return;
    }
    final bot = _bot;
    final botStrategy = _botStrategy;
    if (bot == null || botStrategy == null) {
      return;
    }
    if (state.snapshot.status != GameStatus.playing) {
      return;
    }
    if (state.snapshot.currentPlayer != bot.botPlayer) {
      return;
    }

    final position = botStrategy.chooseMove(
      snapshot: state.snapshot,
      botPlayer: bot.botPlayer,
    );

    final result = _rules.attemptMove(
      snapshot: state.snapshot,
      position: position,
    );

    if (!result.moveAccepted) {
      return;
    }

    _applyAcceptedMove(result);
  }

  void restart() {
    _matchPaused = false;
    _pauseSheetRequestedForBackground = false;
    _cancelBotMove();
    _inputUnlockTimer?.cancel();
    _inputUnlockTimer = null;
    _inputLockGeneration++;
    _matchDurationTicker?.cancel();
    _matchDurationTicker = null;
    _matchStopwatch
      ..reset()
      ..start();
    final startingPlayer = isAiSession ? _randomAiStartingPlayer() : _startingPlayer;
    emit(GameState.initialFor(_rules, startingPlayer: startingPlayer));
    _startMatchDurationTicker();
    _scheduleBotMoveIfNeeded();
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
