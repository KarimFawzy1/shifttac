import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import '../widgets/game_board.dart';
import '../widgets/pause_bottom_sheet.dart';
import '../widgets/player_panel.dart';
import '../widgets/player_turn_indicator.dart';
import '../widgets/win_dialog.dart';

/// First playable screen: local multiplayer board driven by [GameCubit].
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameCubit(),
      child: BlocListener<GameCubit, GameState>(
        listenWhen: (prev, next) =>
            prev.snapshot.status != GameStatus.won &&
            next.snapshot.status == GameStatus.won,
        listener: (context, _) {
          unawaited(_presentWinDialogWhenReady(context));
        },
        child: const _GameplayBody(),
      ),
    );
  }
}

Future<void> _presentWinDialogWhenReady(BuildContext context) async {
  await Future<void>.delayed(
    const Duration(milliseconds: GameConstants.dialogEntranceMs),
  );
  if (!context.mounted) {
    return;
  }
  final cubit = context.read<GameCubit>();
  final state = cubit.state;
  if (state.snapshot.status != GameStatus.won ||
      state.snapshot.winner == null) {
    return;
  }
  await WinDialog.show(
    context,
    winner: state.snapshot.winner!,
    totalMoves: state.snapshot.turnIndex,
    matchDurationMs: state.matchDurationMs,
    onPlayAgain: cubit.restart,
    onBackToHome: () {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    },
  );
}

class _GameplayBody extends StatelessWidget {
  const _GameplayBody();

  static final SystemUiOverlayStyle _systemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.warmIvory,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUi,
      child: AppScaffold(
        fullWidthHeader: true,
        header: _GameplayHeader(onBack: () => _handleBack(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.stackMd.h),
            const PlayerTurnIndicator(),
            SizedBox(height: AppSpacing.stackMd.h),
            const _MoveCounterPill(),
            SizedBox(height: AppSpacing.stackSm.h),
            SizedBox(height: AppSpacing.stackLg.h),
            const Expanded(child: _GameplayBoardArea()),
          ],
        ),
      ),
    );
  }

  static void _handleBack(BuildContext context) {
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
                iconAsset: IconConstant.home,
                semanticLabel: 'Back',
                onPressed: onBack,
                iconColor: AppColors.primary,
                transparentMaterial: true,
                iconSize: 22.w,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMd.copyWith(
                      color: AppColors.onSurface,
                      height: 31 / 24,
                      letterSpacing: 2.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onLongPress: () => PauseBottomSheet.show(context),
                child: AppIconButton(
                  iconAsset: IconConstant.restart,
                  semanticLabel: 'Restart match; long-press opens pause menu',
                  iconColor: AppColors.primary,
                  transparentMaterial: true,
                  iconSize: 22.w,
                  onPressed: () => context.read<GameCubit>().restart(),
                ),
              ),
            ],
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
  const _GameplayBoardArea();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppSpacing.stackMd.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const GameBoard(),
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
