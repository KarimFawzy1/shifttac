import 'dart:math';

import 'package:fake_async/fake_async.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/bot_opponent_config.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';
import 'package:shifttac/features/game/presentation/state/game_state.dart';

final class _NoOpBotStrategy implements BotStrategy {
  const _NoOpBotStrategy();

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    throw StateError('Bot chooseMove should not run');
  }
}

final class _FixedBotStrategy implements BotStrategy {
  const _FixedBotStrategy(this.position);

  final Position position;

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    return position;
  }
}

GameSnapshot _applyShift(GameSnapshot snapshot, int row, int col) {
  return ShiftGameEngine.instance
      .attemptMove(
        snapshot: snapshot,
        position: Position(row: row, col: col),
      )
      .snapshot;
}

GameCubit _shiftAiCubit({Random? botRandom, BotStrategy? botStrategy}) {
  return GameCubit.fromSession(
    const GameSessionConfig(
      mode: GameMode.shift,
      bot: BotOpponentConfig(
        difficulty: BotDifficulty.easy,
        botPlayer: Player.o,
      ),
      startingPlayer: Player.x,
    ),
    botRandom: botRandom,
    botStrategy: botStrategy,
  );
}

GameSnapshot _snapshotWithBotThreeMarks() {
  var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
  snapshot = _applyShift(snapshot, 0, 0);
  snapshot = _applyShift(snapshot, 1, 1);
  snapshot = _applyShift(snapshot, 0, 1);
  snapshot = _applyShift(snapshot, 2, 0);
  snapshot = _applyShift(snapshot, 1, 2);
  snapshot = _applyShift(snapshot, 2, 2);
  snapshot = _applyShift(snapshot, 2, 1);
  expect(snapshot.currentPlayer, Player.o);
  expect(snapshot.oMoves.length, GameConstants.maxActiveMarks);
  return snapshot;
}

void main() {
  group('GameCubit — AI ShiftTac', () {
    test('initial AI session fixes human as X and bot as O', () {
      final cubit = _shiftAiCubit();
      addTearDown(cubit.close);

      expect(cubit.mode, GameMode.shift);
      expect(cubit.isAiSession, isTrue);
      expect(cubit.humanPlayer, Player.x);
      expect(cubit.botPlayer, Player.o);
      expect(cubit.state.snapshot.currentPlayer, Player.x);
    });

    test('shiftAi session resolves easy bot without injection', () {
      final cubit = GameCubit.fromSession(
        GameSessionConfig.shiftAi(BotDifficulty.easy, random: Random(0)),
        botRandom: Random(0),
      );
      addTearDown(cubit.close);

      expect(cubit.isAiSession, isTrue);
      expect(cubit.mode, GameMode.shift);
    });

    test('AI session can start on bot turn and schedules opening move', () {
      fakeAsync((async) {
        final cubit = GameCubit.fromSession(
          GameSessionConfig.shiftAi(
            BotDifficulty.easy,
            random: Random(1),
          ),
          botRandom: Random(1),
        );

        if (cubit.state.snapshot.currentPlayer != Player.o) {
          cubit.close();
          return;
        }

        expect(cubit.state.snapshot.oMoves, isEmpty);

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.oMoves, isNotEmpty);
        cubit.close();
      });
    });

    test('human move schedules a bot move', () {
      fakeAsync((async) {
        final cubit = _shiftAiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        expect(cubit.state.snapshot.currentPlayer, Player.o);
        expect(cubit.state.snapshot.oMoves, isEmpty);

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));
        async.elapse(Duration(milliseconds: GameConstants.inputLockMs));

        expect(cubit.state.snapshot.oMoves, isNotEmpty);
        cubit.close();
      });
    });

    test('human move does not schedule bot move after win', () {
      fakeAsync((async) {
        var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
        snapshot = _applyShift(snapshot, 0, 0);
        snapshot = _applyShift(snapshot, 1, 0);
        snapshot = _applyShift(snapshot, 0, 1);
        snapshot = _applyShift(snapshot, 2, 2);

        final cubit = GameCubit.forTest(
          rules: ShiftGameEngine.instance,
          bot: const BotOpponentConfig(
            difficulty: BotDifficulty.easy,
            botPlayer: Player.o,
          ),
          startingPlayer: Player.x,
          botStrategy: const _NoOpBotStrategy(),
          initialState: GameState(
            snapshot: snapshot,
            inputLocked: false,
            lastPlacedPosition: null,
            lastRemovedPosition: null,
            matchDurationMs: 0,
          ),
        );

        cubit.onCellTapped(const Position(row: 0, col: 2));
        expect(cubit.state.snapshot.status, GameStatus.won);
        expect(cubit.state.snapshot.turnIndex, 5);

        async.elapse(
          Duration(milliseconds: GameConstants.botMoveDelayMs + 200),
        );
        expect(cubit.state.snapshot.turnIndex, 5);
        cubit.close();
      });
    });

    test('human taps during bot turn are rejected', () {
      fakeAsync((async) {
        final cubit = _shiftAiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        expect(cubit.state.snapshot.currentPlayer, Player.o);

        expect(
          cubit.onCellTapped(const Position(row: 0, col: 0)),
          CellTapResult.rejectedLocked,
        );
        expect(cubit.state.snapshot.oMoves, isEmpty);

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));
        cubit.close();
      });
    });

    test('bot move updates snapshot through ShiftGameEngine', () {
      fakeAsync((async) {
        final cubit = _shiftAiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.xMoves.length, 1);
        expect(cubit.state.snapshot.oMoves.length, 1);
        expect(cubit.state.snapshot.turnIndex, 2);
        expect(cubit.state.lastRemovedPosition, isNull);
        cubit.close();
      });
    });

    test('bot move can remove oldest bot mark through FIFO', () {
      fakeAsync((async) {
        final cubit = GameCubit.forTest(
          rules: ShiftGameEngine.instance,
          bot: const BotOpponentConfig(
            difficulty: BotDifficulty.easy,
            botPlayer: Player.o,
          ),
          startingPlayer: Player.x,
          botStrategy: const _FixedBotStrategy(Position(row: 0, col: 2)),
          initialState: GameState(
            snapshot: _snapshotWithBotThreeMarks(),
            inputLocked: false,
            lastPlacedPosition: null,
            lastRemovedPosition: null,
            matchDurationMs: 0,
          ),
        );

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.oMoves.length, GameConstants.maxActiveMarks);
        expect(cubit.state.lastRemovedPosition, const Position(row: 1, col: 1));
        expect(cubit.state.lastPlacedPosition, const Position(row: 0, col: 2));
        cubit.close();
      });
    });

    test('restart cancels pending bot move', () {
      fakeAsync((async) {
        final cubit = _shiftAiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        cubit.restart();

        final starter = cubit.state.snapshot.currentPlayer;
        expect(cubit.state.snapshot.turnIndex, 0);
        expect(cubit.state.snapshot.oMoves, isEmpty);
        expect(starter, isIn([Player.x, Player.o]));

        async.elapse(
          Duration(milliseconds: GameConstants.botMoveDelayMs + 200),
        );
        if (starter == Player.o) {
          expect(cubit.state.snapshot.oMoves, isNotEmpty);
        } else {
          expect(cubit.state.snapshot.oMoves, isEmpty);
        }
        cubit.close();
      });
    });

    test('restart randomizes starting player in AI sessions', () {
      final cubit = GameCubit.fromSession(
        GameSessionConfig.shiftAi(
          BotDifficulty.easy,
          random: Random(2),
        ),
        botRandom: Random(2),
      );
      addTearDown(cubit.close);

      final starters = <Player>{cubit.state.snapshot.currentPlayer};
      for (var i = 0; i < 12; i++) {
        cubit.restart();
        starters.add(cubit.state.snapshot.currentPlayer);
      }

      expect(starters, contains(Player.x));
      expect(starters, contains(Player.o));
    });

    test('pauseMatch cancels pending bot move until resume', () {
      fakeAsync((async) {
        final cubit = _shiftAiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        cubit.pauseMatch();

        async.elapse(
          Duration(milliseconds: GameConstants.botMoveDelayMs + 200),
        );
        expect(cubit.state.snapshot.oMoves, isEmpty);

        cubit.resumeMatch();
        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));
        expect(cubit.state.snapshot.oMoves, isNotEmpty);
        cubit.close();
      });
    });
  });
}
