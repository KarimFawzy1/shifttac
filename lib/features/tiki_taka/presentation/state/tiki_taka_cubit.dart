import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/daos/board_dao.dart';
import '../../data/local/daos/player_search_dao.dart';
import '../../data/local/daos/validation_dao.dart';
import '../../data/local/tiki_taka_database.dart';
import '../../data/models/tiki_board.dart';
import '../../data/models/tiki_player_search_result.dart';
import '../../domain/logic/tiki_taka_game_engine.dart';
import '../../domain/models/tiki_game_status.dart';
import '../../domain/services/answer_validator.dart';
import '../../domain/services/tiki_random_board_generator.dart';
import 'tiki_taka_state.dart';

/// Outcome of tapping a board cell.
enum TikiCellTapResult {
  openedSearch,
  rejectedOccupied,
  rejectedNotPlayable,
  rejectedLocked,
  rejectedDialogOpen,
}

/// Outcome of confirming a player for the active cell.
enum TikiSelectPlayerResult {
  accepted,
  rejectedInvalid,
  rejectedDuplicatePlayer,
  rejectedNoActiveCell,
  rejectedLocked,
  rejectedNotPlayable,
}

/// Injectable collaborators for [TikiTakaCubit].
class TikiTakaDependencies {
  const TikiTakaDependencies({
    required this.boardDao,
    required this.playerSearchDao,
    required this.answerValidator,
    required this.randomBoardGenerator,
    this.engine = TikiTakaGameEngine.instance,
  });

  final BoardDao boardDao;
  final PlayerSearchDao playerSearchDao;
  final AnswerValidator answerValidator;
  final TikiRandomBoardGenerator randomBoardGenerator;
  final TikiTakaGameEngine engine;

  factory TikiTakaDependencies.fromDatabase(Database database) {
    final validationDao = ValidationDao(database);
    return TikiTakaDependencies(
      boardDao: BoardDao(database),
      playerSearchDao: PlayerSearchDao(database),
      answerValidator: AnswerValidator(validationDao),
      randomBoardGenerator: TikiRandomBoardGenerator(database: database),
    );
  }
}

/// Coordinates DAOs, validation, and the Tiki-Taka domain engine for 1P mode.
class TikiTakaCubit extends Cubit<TikiTakaState> {
  TikiTakaCubit({
    required TikiTakaDependencies dependencies,
    bool autoLoadBoard = false,
  }) : _boardDao = dependencies.boardDao,
       _playerSearchDao = dependencies.playerSearchDao,
       _answerValidator = dependencies.answerValidator,
       _randomBoardGenerator = dependencies.randomBoardGenerator,
       _engine = dependencies.engine,
       super(TikiTakaState.initial(dependencies.engine.initial())) {
    if (autoLoadBoard) {
      unawaited(loadBoard());
    }
  }

  /// App runtime entry point after [TikiTakaDatabase.open].
  factory TikiTakaCubit.production({bool autoLoadBoard = true}) {
    return TikiTakaCubit(
      dependencies: TikiTakaDependencies.fromDatabase(
        TikiTakaDatabase.instance.database,
      ),
      autoLoadBoard: autoLoadBoard,
    );
  }

  @visibleForTesting
  factory TikiTakaCubit.forTest({
    required TikiTakaDependencies dependencies,
    required TikiTakaState initialState,
  }) {
    return TikiTakaCubit._(
      dependencies: dependencies,
      initialState: initialState,
    );
  }

  TikiTakaCubit._({
    required TikiTakaDependencies dependencies,
    required TikiTakaState initialState,
  }) : _boardDao = dependencies.boardDao,
       _playerSearchDao = dependencies.playerSearchDao,
       _answerValidator = dependencies.answerValidator,
       _randomBoardGenerator = dependencies.randomBoardGenerator,
       _engine = dependencies.engine,
       super(initialState);

  final BoardDao _boardDao;
  final PlayerSearchDao _playerSearchDao;
  final AnswerValidator _answerValidator;
  final TikiRandomBoardGenerator _randomBoardGenerator;
  final TikiTakaGameEngine _engine;

  final Stopwatch _matchStopwatch = Stopwatch();
  Timer? _durationTicker;
  bool _timerPaused = false;
  int _searchGeneration = 0;
  int _selectionGeneration = 0;

  bool get isTimerPaused => _timerPaused;

  /// Forces a timer sync; used by tests when periodic timers are not pumped.
  @visibleForTesting
  void refreshElapsedForTest() => _emitElapsedIfRunning();

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }

  Future<void> loadBoard() async {
    if (isClosed) {
      return;
    }

    var game = _engine.beginLoadingBoard(state.game);
    emit(
      state.copyWith(
        game: game,
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
        inputLocked: false,
      ),
    );

    final board =
        await _randomBoardGenerator.generate() ??
        await _boardDao.loadRandomDefaultBoard();

    if (isClosed) {
      return;
    }

    if (board == null) {
      emit(TikiTakaState.initial(_engine.initial()));
      return;
    }

    game = _engine.boardLoaded(game, board);
    _logBoardAttributes(board);
    emit(
      state.copyWith(
        game: game,
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
        inputLocked: false,
      ),
    );
    _resetTimer();
  }

  void _logBoardAttributes(TikiBoard board) {
    if (!kDebugMode) {
      return;
    }
    final header1 =
        board.rowAttributes.map((attribute) => attribute.displayName).join(', ');
    final header2 =
        board.columnAttributes
            .map((attribute) => attribute.displayName)
            .join(', ');
    debugPrint('Header1 =>  $header1');
    debugPrint('Header2 =>  $header2');
  }

  TikiCellTapResult onCellTapped(int row, int col) {
    if (state.activeCell != null) {
      return TikiCellTapResult.rejectedDialogOpen;
    }

    if (state.inputLocked) {
      return TikiCellTapResult.rejectedLocked;
    }

    if (!state.game.isPlayable) {
      return TikiCellTapResult.rejectedNotPlayable;
    }

    if (state.game.cellAt(row, col).isFilled) {
      return TikiCellTapResult.rejectedOccupied;
    }

    emit(
      state.copyWith(
        activeCell: TikiActiveCell(row: row, col: col),
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
      ),
    );
    return TikiCellTapResult.openedSearch;
  }

  void closeSearch() {
    if (state.activeCell == null) {
      return;
    }

    emit(
      state.copyWith(
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
      ),
    );
  }

  Future<void> searchPlayers(String query) async {
    final generation = ++_searchGeneration;
    emit(state.copyWith(searchQuery: query, isSearching: true));

    final results = await _playerSearchDao.search(query);
    if (isClosed || generation != _searchGeneration) {
      return;
    }

    emit(state.copyWith(searchResults: results, isSearching: false));
  }

  Future<TikiSelectPlayerResult> selectPlayer(
    TikiPlayerSearchResult player,
  ) async {
    final activeCell = state.activeCell;
    if (activeCell == null) {
      return TikiSelectPlayerResult.rejectedNoActiveCell;
    }

    if (state.inputLocked) {
      return TikiSelectPlayerResult.rejectedLocked;
    }

    if (!state.game.isPlayable) {
      return TikiSelectPlayerResult.rejectedNotPlayable;
    }

    final board = state.game.board;
    if (board == null) {
      return TikiSelectPlayerResult.rejectedNotPlayable;
    }

    final selectionGeneration = ++_selectionGeneration;
    emit(state.copyWith(inputLocked: true));

    final validation = await _answerValidator.validate(
      playerId: player.id,
      rowAttributeId: board.rowAttributes[activeCell.row].id,
      colAttributeId: board.columnAttributes[activeCell.col].id,
      usedPlayerIds: state.game.usedPlayerIds,
    );

    if (isClosed || selectionGeneration != _selectionGeneration) {
      return TikiSelectPlayerResult.rejectedLocked;
    }

    final answer = _engine.attemptAnswer(
      state: _engine.updateElapsed(state.game, _matchStopwatch.elapsed),
      row: activeCell.row,
      col: activeCell.col,
      player: player,
      validation: validation,
    );

    emit(
      state.copyWith(
        game: answer.state,
        inputLocked: false,
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
      ),
    );

    _syncTimerToStatus(answer.state.status);

    if (answer.accepted) {
      return TikiSelectPlayerResult.accepted;
    }

    if (answer.rejectionReason == AnswerValidationReason.duplicatePlayer) {
      return TikiSelectPlayerResult.rejectedDuplicatePlayer;
    }

    return TikiSelectPlayerResult.rejectedInvalid;
  }

  void continueAfterFirstWin() {
    if (state.game.status != TikiGameStatus.firstWin) {
      return;
    }

    emit(
      state.copyWith(
        game: _engine.continuePlaying(state.game),
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
      ),
    );
  }

  Future<void> restart() async {
    closeSearch();
    _stopTimer();
    await loadBoard();
  }

  void clearBoard() {
    final cleared = _engine.clearBoard(state.game);
    if (cleared == null) {
      return;
    }

    closeSearch();
    emit(
      state.copyWith(
        game: cleared,
        inputLocked: false,
        clearActiveCell: true,
        searchResults: const [],
        searchQuery: '',
        isSearching: false,
      ),
    );
    _syncTimerToStatus(cleared.status);
  }

  void pauseTimer() {
    if (_timerPaused || !_isTimerRunningStatus(state.game.status)) {
      return;
    }

    _timerPaused = true;
    _matchStopwatch.stop();
    _durationTicker?.cancel();
    _durationTicker = null;
  }

  void resumeTimer() {
    if (!_timerPaused || isClosed) {
      return;
    }

    _timerPaused = false;
    if (_isTimerRunningStatus(state.game.status)) {
      _matchStopwatch.start();
      _startDurationTicker();
    }
  }

  void exitMatch() {
    _stopTimer();
    emit(TikiTakaState.initial(_engine.initial()));
  }

  void _resetTimer() {
    _timerPaused = false;
    _matchStopwatch
      ..reset()
      ..start();
    _startDurationTicker();
    _emitElapsedIfRunning();
  }

  void _stopTimer() {
    _timerPaused = false;
    _matchStopwatch.stop();
    _durationTicker?.cancel();
    _durationTicker = null;
  }

  void _syncTimerToStatus(TikiGameStatus status) {
    if (_isTimerRunningStatus(status)) {
      if (!_matchStopwatch.isRunning && !_timerPaused) {
        _matchStopwatch.start();
        _startDurationTicker();
      }
      _emitElapsedIfRunning();
      return;
    }

    _stopTimer();
    emit(
      state.copyWith(
        game: _engine.updateElapsed(state.game, _matchStopwatch.elapsed),
      ),
    );
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitElapsedIfRunning(),
    );
    _emitElapsedIfRunning();
  }

  void _emitElapsedIfRunning() {
    if (isClosed || _timerPaused) {
      return;
    }

    if (!_isTimerRunningStatus(state.game.status)) {
      _durationTicker?.cancel();
      _durationTicker = null;
      return;
    }

    final elapsed = _matchStopwatch.elapsed;
    if (elapsed == state.game.elapsed) {
      return;
    }

    emit(
      state.copyWith(game: _engine.updateElapsed(state.game, elapsed)),
    );
  }

  bool _isTimerRunningStatus(TikiGameStatus status) {
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
