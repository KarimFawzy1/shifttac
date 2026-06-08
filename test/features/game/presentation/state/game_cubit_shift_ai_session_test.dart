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

final class _RecordingShiftBotStrategy implements BotStrategy {
  const _RecordingShiftBotStrategy();

  @override
  Position chooseMove({
    required GameSnapshot snapshot,
    required Player botPlayer,
  }) {
    return const Position(row: 1, col: 1);
  }
}

void main() {
  group('GameCubit — ShiftTac AI session', () {
    test('fromSession constructs ShiftTac AI cubit with injected strategy', () {
      final session = GameSessionConfig.shiftAi(
        BotDifficulty.easy,
        random: Random(0),
      );
      final cubit = GameCubit.fromSession(
        session,
        botStrategy: const _RecordingShiftBotStrategy(),
      );
      addTearDown(cubit.close);

      expect(cubit.mode, GameMode.shift);
      expect(cubit.rules, ShiftGameEngine.instance);
      expect(cubit.isAiSession, isTrue);
      expect(cubit.humanPlayer, Player.x);
      expect(cubit.botPlayer, Player.o);
      expect(cubit.state.snapshot.currentPlayer, session.startingPlayer);
      expect(cubit.state.snapshot.status, GameStatus.playing);
    });

    test('fromSession without injected strategy schedules easy bot moves', () {
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

        async.elapse(Duration(milliseconds: GameConstants.botMoveDelayMs));

        expect(cubit.state.snapshot.oMoves, isNotEmpty);
        cubit.close();
      });
    });

    test('forTest accepts ShiftTac bot config without classic-only restriction', () {
      final cubit = GameCubit.forTest(
        rules: ShiftGameEngine.instance,
        initialState: GameState.initialFor(ShiftGameEngine.instance),
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.intermediate,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        botStrategy: const _RecordingShiftBotStrategy(),
      );
      addTearDown(cubit.close);

      expect(cubit.mode, GameMode.shift);
      expect(cubit.isAiSession, isTrue);
    });
  });
}
