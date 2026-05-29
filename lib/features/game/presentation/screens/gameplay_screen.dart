import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/audio/app_audio.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../domain/models/game_session_config.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../../domain/models/game_mode.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import '../widgets/board_cell.dart';
import '../widgets/exit_game_dialog.dart';
import '../widgets/game_board.dart';
import '../widgets/pause_bottom_sheet.dart';
import '../widgets/player_panel.dart';
import '../widgets/player_turn_indicator.dart';
import '../widgets/match_result.dart';
import '../widgets/match_result_dialog.dart';

/// First playable screen: local multiplayer board driven by [GameCubit].
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({
    super.key,
    this.session = const GameSessionConfig.shift(),
  });

  final GameSessionConfig session;

  /// Active rule set; convenience for tests and mode-only call sites.
  GameMode get mode => session.mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => switch (session.mode) {
        GameMode.shift => GameCubit.shift(),
        GameMode.classic => GameCubit.classic(),
      },
      child: const _GameplayLifecycleScope(),
    );
  }
}

/// Observes app lifecycle to pause the match in the background and reopen the
/// pause menu when the player returns.
class _GameplayLifecycleScope extends StatefulWidget {
  const _GameplayLifecycleScope();

  @override
  State<_GameplayLifecycleScope> createState() =>
      _GameplayLifecycleScopeState();
}

class _GameplayLifecycleScopeState extends State<_GameplayLifecycleScope>
    with WidgetsBindingObserver {
  bool _matchResultPresenting = false;

  Future<void> _presentMatchResultDialogWhenReady(BuildContext context) async {
    if (_matchResultPresenting || !context.mounted) {
      return;
    }
    final cubit = context.read<GameCubit>();
    final state = cubit.state;
    final baseResult = MatchResult.fromSnapshot(state.snapshot);
    if (baseResult == null) {
      return;
    }
    final result = MatchResult(
      kind: baseResult.kind,
      totalMoves: state.snapshot.turnIndex,
      matchDurationMs: state.matchDurationMs,
    );

    _matchResultPresenting = true;
    try {
      final audio = AppAudioScope.read(context);
      unawaited(
        switch (result.kind) {
          MatchResultKind.draw => audio.playDraw(),
          _ => audio.playWin(),
        },
      );
      await MatchResultDialog.show(
        context,
        result: result,
        onPlayAgain: cubit.restart,
        onBackToHome: () {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        },
      );
    } finally {
      if (mounted) {
        _matchResultPresenting = false;
      }
    }
  }

  Future<void> _presentDrawResultAfterBoardSettles(BuildContext context) async {
    await Future<void>.delayed(
      const Duration(milliseconds: GameConstants.inputLockMs),
    );
    if (!mounted || !context.mounted) {
      return;
    }
    await _presentMatchResultDialogWhenReady(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<GameCubit>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        cubit.onAppBackgrounded();
      case AppLifecycleState.resumed:
        _presentPauseSheetIfNeeded(cubit);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _presentPauseSheetIfNeeded(GameCubit cubit) {
    if (!cubit.shouldPresentPauseAfterBackground) {
      return;
    }
    if (PauseBottomSheet.isVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!cubit.shouldPresentPauseAfterBackground) {
        return;
      }
      if (PauseBottomSheet.isVisible) {
        return;
      }
      if (cubit.state.snapshot.status != GameStatus.playing) {
        return;
      }
      unawaited(PauseBottomSheet.show(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameCubit, GameState>(
      listenWhen: (previous, current) =>
          previous.snapshot.status != GameStatus.draw &&
          current.snapshot.status == GameStatus.draw,
      listener: (context, state) {
        unawaited(_presentDrawResultAfterBoardSettles(context));
      },
      child: _GameplayBody(
        onMatchResultReady: () =>
            unawaited(_presentMatchResultDialogWhenReady(context)),
      ),
    );
  }
}

class _GameplayBody extends StatelessWidget {
  const _GameplayBody({required this.onMatchResultReady});

  final VoidCallback onMatchResultReady;

  static final SystemUiOverlayStyle _systemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.warmIvory,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_handleBack(context));
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemUi,
        child: AppScaffold(
          fullWidthHeader: true,
          header: _GameplayHeader(onBack: () => unawaited(_handleBack(context))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.stackMd.h),
              const PlayerTurnIndicator(),
              SizedBox(height: AppSpacing.stackMd.h),
              const _MoveCounterPill(),
              SizedBox(height: AppSpacing.stackSm.h),
              SizedBox(height: AppSpacing.stackLg.h),
              Expanded(
                child: _GameplayBoardArea(
                  onWinRevealComplete: onMatchResultReady,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _handleBack(BuildContext context) async {
    if (PauseBottomSheet.isVisible) {
      return;
    }
    final confirmed = await ExitGameDialog.show(context);
    if (!context.mounted || !confirmed) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.home);
    }
  }
}

class _GameplayHeader extends StatelessWidget {
  const _GameplayHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.inkNavy.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: SizedBox(
        height: 64.h,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 16.h,
            horizontal: AppSpacing.containerPadding.w,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIconButton(
                iconAsset: IconConstant.back,
                semanticLabel: 'Back',
                onPressed: onBack,
                iconColor: AppColors.primary,
                transparentMaterial: true,
                iconSize: 20.w,
              ),
              const Expanded(child: Center(child: _NavIconRestartButton())),
              AppIconButton(
                iconAsset: IconConstant.pause,
                semanticLabel: 'Pause match',
                iconColor: AppColors.primary,
                transparentMaterial: true,
                iconSize: 28.w,
                onPressed: () => unawaited(PauseBottomSheet.show(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Center header logo: tap restarts the match with a horizontal Y-axis spin.
class _NavIconRestartButton extends StatefulWidget {
  const _NavIconRestartButton();

  static const Duration _spinDuration = Duration(milliseconds: 600);

  @override
  State<_NavIconRestartButton> createState() => _NavIconRestartButtonState();
}

class _NavIconRestartButtonState extends State<_NavIconRestartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late final Animation<double> _spin;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: _NavIconRestartButton._spinDuration,
    );
    _spin = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOutCubic,
    );
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _spinController.reset();
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _onTap() {
    GameplayHaptics.onRestartTap(context);
    context.read<GameCubit>().restart();
    if (_spinController.isAnimating) {
      _spinController.reset();
    }
    unawaited(_spinController.forward());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Restart match',
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, child) {
            final angle = _spin.value * 2 * math.pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
              child: child,
            );
          },
          child: Image.asset(
            ImageConstant.navIcon,
            height: 32.h,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _MoveCounterPill extends StatelessWidget {
  const _MoveCounterPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BlocSelector<GameCubit, GameState, int>(
            selector: (state) => state.matchDurationMs,
            builder: (context, matchDurationMs) {
              return Text(
                'Time: ${matchDurationMs ~/ 1000}s',
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 0.7,
                ),
              );
            },
          ),
          SizedBox(width: 40.h),
          BlocSelector<GameCubit, GameState, int>(
            selector: (state) => state.snapshot.turnIndex,
            builder: (context, moves) {
              return Text(
                'Moves: $moves',
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 0.7,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GameplayBoardArea extends StatelessWidget {
  const _GameplayBoardArea({required this.onWinRevealComplete});

  final VoidCallback onWinRevealComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppSpacing.stackMd.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GameBoard(onWinningLineRevealComplete: onWinRevealComplete),
                SizedBox(height: AppSpacing.stackLg.h),
                SizedBox(height: AppSpacing.stackMd.h),
                SizedBox(height: AppSpacing.stackMd.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: PlayerPanel(player: Player.x)),
                      SizedBox(width: AppSpacing.gridGutter.w),
                      const Expanded(child: PlayerPanel(player: Player.o)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
