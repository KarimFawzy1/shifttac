import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shifttac/core/audio/app_audio.dart';
import 'package:shifttac/core/constants/app_constants.dart';
import 'package:shifttac/core/routing/app_router.dart';
import 'package:shifttac/core/settings/app_settings_controller.dart';
import 'package:shifttac/features/game/domain/logic/classic_game_engine.dart';
import 'package:shifttac/features/game/domain/logic/game_snapshot.dart';
import 'package:shifttac/features/game/domain/logic/shift_game_engine.dart';
import 'package:shifttac/features/game/domain/models/bot_difficulty.dart';
import 'package:shifttac/features/game/domain/models/bot_opponent_config.dart';
import 'package:shifttac/features/game/domain/models/game_mode.dart';
import 'package:shifttac/features/game/domain/models/game_session_config.dart';
import 'package:shifttac/features/game/domain/models/game_status.dart';
import 'package:shifttac/features/game/domain/models/player.dart';
import 'package:shifttac/features/game/domain/models/position.dart';
import 'package:shifttac/features/game/presentation/screens/gameplay_screen.dart';
import 'package:shifttac/features/game/presentation/state/game_cubit.dart';
import 'package:shifttac/features/game/presentation/state/game_state.dart';
import 'package:shifttac/features/game/presentation/widgets/match_result.dart';
import 'package:shifttac/features/game/presentation/widgets/match_result_dialog.dart';
import 'package:shifttac/features/game/presentation/widgets/player_panel.dart';
import 'package:shifttac/features/game/presentation/widgets/player_turn_indicator.dart';

/// Deterministic ShiftTac AI session (human X, bot O, human starts).
const GameSessionConfig _shiftAiSession = GameSessionConfig(
  mode: GameMode.shift,
  bot: BotOpponentConfig(
    difficulty: BotDifficulty.easy,
    botPlayer: Player.o,
  ),
  startingPlayer: Player.x,
);

Widget _gameplayTestApp({required Widget home}) {
  final settings = AppSettingsController();
  return AppSettingsScope(
    settings: settings,
    child: AppAudioScope(
      audio: AppAudio(settings),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (context, child) =>
            MaterialApp(onGenerateRoute: AppRouter.onGenerateRoute, home: home),
      ),
    ),
  );
}

GameSnapshot _xWinSnapshot() {
  return GameSnapshot(
    xMoves: const [],
    oMoves: const [],
    currentPlayer: Player.x,
    turnIndex: 5,
    status: GameStatus.won,
    winner: Player.x,
    winningLine: const [
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 0, col: 2),
    ],
  );
}

GameSnapshot _oWinSnapshot() {
  return GameSnapshot(
    xMoves: const [],
    oMoves: const [],
    currentPlayer: Player.o,
    turnIndex: 6,
    status: GameStatus.won,
    winner: Player.o,
    winningLine: const [
      Position(row: 0, col: 0),
      Position(row: 1, col: 0),
      Position(row: 2, col: 0),
    ],
  );
}

GameSnapshot _drawSnapshot() {
  return GameSnapshot(
    xMoves: const [],
    oMoves: const [],
    currentPlayer: Player.x,
    turnIndex: 9,
    status: GameStatus.draw,
  );
}

/// Presents [MatchResultDialog] when the cubit snapshot is terminal (AI session).
class _AiMatchResultProbe extends StatefulWidget {
  const _AiMatchResultProbe({required this.cubit});

  final GameCubit cubit;

  @override
  State<_AiMatchResultProbe> createState() => _AiMatchResultProbeState();
}

class _AiMatchResultProbeState extends State<_AiMatchResultProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowResult());
  }

  Future<void> _maybeShowResult() async {
    if (!mounted) {
      return;
    }
    final result = MatchResult.fromSnapshot(widget.cubit.state.snapshot);
    if (result == null) {
      return;
    }
    await MatchResultDialog.show(
      context,
      result: result,
      onPlayAgain: widget.cubit.restart,
      onBackToHome: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerTurnIndicator(),
          Row(
            children: [
              Expanded(child: PlayerPanel(player: Player.x)),
              Expanded(child: PlayerPanel(player: Player.o)),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  group('Gameplay AI presentation', () {
    testWidgets('AI session shows You and AI labels', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: GameplayScreen(
            session: GameSessionConfig.classicAi(BotDifficulty.easy),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('You'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Player X'), findsNothing);
      expect(find.text('Player O'), findsNothing);
    });

    testWidgets('local classic keeps Player X and Player O labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: GameSessionConfig.classic()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Player X'), findsOneWidget);
      expect(find.text('Player O'), findsOneWidget);
      expect(find.text('AI'), findsNothing);
    });

    testWidgets('bot turn shows thinking indicator', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: GameplayScreen(
            session: GameSessionConfig.classicAi(BotDifficulty.easy),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      await tester.pump();

      expect(find.text('Bot thinking...'), findsOneWidget);
      expect(find.text('THINKING'), findsOneWidget);
    });

    testWidgets('restart keeps AI session config', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: GameplayScreen(
            session: GameSessionConfig.classicAi(BotDifficulty.easy),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      cubit.restart();

      expect(cubit.isAiSession, isTrue);
      expect(cubit.botPlayer, Player.o);
      expect(
        cubit.state.snapshot.currentPlayer,
        isIn([Player.x, Player.o]),
      );
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('human win shows result dialog in AI session', (tester) async {
      final cubit = GameCubit.forTest(
        rules: ClassicGameEngine.instance,
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        initialState: GameState(
          snapshot: _xWinSnapshot(),
          inputLocked: false,
          lastPlacedPosition: null,
          lastRemovedPosition: null,
          matchDurationMs: 1000,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _gameplayTestApp(home: _AiMatchResultProbe(cubit: cubit)),
      );
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      expect(find.text('X Wins!'), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
    });

    testWidgets('bot win shows result dialog in AI session', (tester) async {
      final cubit = GameCubit.forTest(
        rules: ClassicGameEngine.instance,
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        initialState: GameState(
          snapshot: _oWinSnapshot(),
          inputLocked: false,
          lastPlacedPosition: null,
          lastRemovedPosition: null,
          matchDurationMs: 1000,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _gameplayTestApp(home: _AiMatchResultProbe(cubit: cubit)),
      );
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      expect(find.text('O Wins!'), findsOneWidget);
    });

    testWidgets('draw shows result dialog in AI session', (tester) async {
      final cubit = GameCubit.forTest(
        rules: ClassicGameEngine.instance,
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        initialState: GameState(
          snapshot: _drawSnapshot(),
          inputLocked: false,
          lastPlacedPosition: null,
          lastRemovedPosition: null,
          matchDurationMs: 1000,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _gameplayTestApp(home: _AiMatchResultProbe(cubit: cubit)),
      );
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      expect(find.text("It's a Draw!"), findsOneWidget);
    });
  });

  group('ShiftTac AI presentation', () {
    testWidgets('AI session shows You and AI labels', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('You'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Player X'), findsNothing);
      expect(find.text('Player O'), findsNothing);
    });

    testWidgets('local ShiftTac multiplayer does not show AI labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: GameSessionConfig.shift()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Player X'), findsOneWidget);
      expect(find.text('Player O'), findsOneWidget);
      expect(find.text('AI'), findsNothing);
    });

    testWidgets('bot turn shows thinking indicator', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      await tester.pump();

      expect(find.text('Bot thinking...'), findsOneWidget);
      expect(find.text('THINKING'), findsOneWidget);
    });

    testWidgets('board rejects human taps during bot turn', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      await tester.pump();

      expect(cubit.isBotTurn, isTrue);
      final turnAfterHuman = cubit.state.snapshot.turnIndex;

      final rejectResult = cubit.onCellTapped(const Position(row: 0, col: 0));
      expect(rejectResult, CellTapResult.rejectedLocked);
      expect(cubit.state.snapshot.turnIndex, turnAfterHuman);
    });

    testWidgets('human win shows result dialog in ShiftTac AI session', (
      tester,
    ) async {
      final cubit = GameCubit.forTest(
        rules: ShiftGameEngine.instance,
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        initialState: GameState(
          snapshot: _xWinSnapshot(),
          inputLocked: false,
          lastPlacedPosition: null,
          lastRemovedPosition: null,
          matchDurationMs: 1000,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _gameplayTestApp(home: _AiMatchResultProbe(cubit: cubit)),
      );
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      expect(find.text('X Wins!'), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
    });

    testWidgets('bot win shows result dialog in ShiftTac AI session', (
      tester,
    ) async {
      final cubit = GameCubit.forTest(
        rules: ShiftGameEngine.instance,
        bot: const BotOpponentConfig(
          difficulty: BotDifficulty.easy,
          botPlayer: Player.o,
        ),
        startingPlayer: Player.x,
        initialState: GameState(
          snapshot: _oWinSnapshot(),
          inputLocked: false,
          lastPlacedPosition: null,
          lastRemovedPosition: null,
          matchDurationMs: 1000,
        ),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        _gameplayTestApp(home: _AiMatchResultProbe(cubit: cubit)),
      );
      await tester.pump();
      await tester.pump(MatchResultDialog.animationDuration);

      expect(find.text('O Wins!'), findsOneWidget);
    });

    testWidgets('restart keeps ShiftTac AI session config', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      expect(cubit.rules.mode, GameMode.shift);
      cubit.onCellTapped(const Position(row: 1, col: 1));
      cubit.restart();

      expect(cubit.isAiSession, isTrue);
      expect(cubit.botPlayer, Player.o);
      expect(cubit.rules.mode, GameMode.shift);
      expect(find.text('AI'), findsOneWidget);
    });
  });

  group('Gameplay AI flows', () {
    testWidgets('exit dialog can be opened during bot turn', (tester) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: GameplayScreen(
            session: GameSessionConfig.classicAi(BotDifficulty.easy),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave match?'), findsOneWidget);
      expect(find.byType(GameplayScreen), findsOneWidget);
    });

    testWidgets('exit dialog can be opened during human turn in ShiftTac AI', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      expect(cubit.isBotTurn, isFalse);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave match?'), findsOneWidget);
    });

    testWidgets('exit dialog can be opened during bot turn in ShiftTac AI', (
      tester,
    ) async {
      await tester.pumpWidget(
        _gameplayTestApp(
          home: const GameplayScreen(session: _shiftAiSession),
        ),
      );
      await tester.pump();
      await tester.pump();

      final cubit = tester
          .element(find.byType(PlayerTurnIndicator))
          .read<GameCubit>();
      cubit.onCellTapped(const Position(row: 1, col: 1));
      await tester.pump();

      expect(cubit.isBotTurn, isTrue);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave match?'), findsOneWidget);
      expect(find.byType(GameplayScreen), findsOneWidget);
    });
  });
}
