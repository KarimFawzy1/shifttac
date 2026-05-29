import 'dart:math';

import 'package:fake_async/fake_async.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/constants/game_constants.dart';
import 'package:shifttac/features/game/domain/logic/bot_strategy.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/presentation/state/game_state.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/bot_opponent_config.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';

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

GameCubit _aiCubit({Random? botRandom, BotStrategy? botStrategy}) {
  return GameCubit.fromSession(
    const GameSessionConfig(
      mode: GameMode.classic,
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

void main() {
  group('GameCubit — AI classic', () {
    test('initial AI session fixes human as X and bot as O', () {
      final cubit = _aiCubit();
      addTearDown(cubit.close);

      expect(cubit.isAiSession, isTrue);
      expect(cubit.humanPlayer, Player.x);
      expect(cubit.botPlayer, Player.o);
      expect(cubit.state.snapshot.currentPlayer, Player.x);
    });

    test('AI session can start on bot turn and schedules opening move', () {
      fakeAsync((async) {
        final cubit = GameCubit.fromSession(
          const GameSessionConfig(
            mode: GameMode.classic,
            bot: BotOpponentConfig(
              difficulty: BotDifficulty.easy,
              botPlayer: Player.o,
            ),
            startingPlayer: Player.o,
          ),
          botRandom: Random(0),
        );

        expect(cubit.state.snapshot.currentPlayer, Player.o);
        expect(cubit.state.snapshot.oMoves, isEmpty);

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.oMoves, isNotEmpty);
        cubit.close();
      });
    });

    test('human move schedules a bot move', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

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
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 0, col: 0),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 1, col: 1),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 0, col: 1),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 2, col: 0),
            )
            .snapshot;

        final cubit = GameCubit.forTest(
          rules: ClassicGameEngine.instance,
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

    test('human move does not schedule bot move after draw', () {
      fakeAsync((async) {
        var snapshot = GameSnapshot.initial(startingPlayer: Player.x);
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 0, col: 0),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 1, col: 1),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 0, col: 1),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 2, col: 2),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 2, col: 0),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 0, col: 2),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 2, col: 1),
            )
            .snapshot;
        snapshot = ClassicGameEngine.instance
            .attemptMove(
              snapshot: snapshot,
              position: const Position(row: 1, col: 0),
            )
            .snapshot;

        final cubit = GameCubit.forTest(
          rules: ClassicGameEngine.instance,
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

        expect(cubit.state.snapshot.currentPlayer, Player.x);
        cubit.onCellTapped(const Position(row: 1, col: 2));
        expect(cubit.state.snapshot.status, GameStatus.draw);
        expect(cubit.state.snapshot.turnIndex, 9);

        async.elapse(
          Duration(milliseconds: GameConstants.botMoveDelayMs + 200),
        );
        expect(cubit.state.snapshot.turnIndex, 9);
        cubit.close();
      });
    });

    test('human taps during bot turn are rejected', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

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

    test('bot move updates snapshot through classic rules', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.xMoves.length, 1);
        expect(cubit.state.snapshot.oMoves.length, 1);
        expect(cubit.state.snapshot.turnIndex, 2);
        expect(cubit.state.lastRemovedPosition, isNull);
        cubit.close();
      });
    });

    test('restart cancels pending bot move', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

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
        const GameSessionConfig(
          mode: GameMode.classic,
          bot: BotOpponentConfig(
            difficulty: BotDifficulty.easy,
            botPlayer: Player.o,
          ),
          startingPlayer: Player.x,
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

    test('close cancels pending bot move', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

        cubit.onCellTapped(const Position(row: 1, col: 1));
        cubit.close();

        async.elapse(
          Duration(milliseconds: GameConstants.botMoveDelayMs + 200),
        );
      });
    });

    test('pauseMatch cancels pending bot move until resume', () {
      fakeAsync((async) {
        final cubit = _aiCubit(botRandom: Random(0));

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

  group('GameCubit — local modes unchanged', () {
    test('ShiftTac cubit has no AI session', () {
      final cubit = GameCubit.shift();
      addTearDown(cubit.close);
      expect(cubit.isAiSession, isFalse);
      expect(cubit.botPlayer, isNull);
    });

    test('local classic cubit has no AI session', () {
      final cubit = GameCubit.classic();
      addTearDown(cubit.close);
      expect(cubit.isAiSession, isFalse);
    });
  });
}
