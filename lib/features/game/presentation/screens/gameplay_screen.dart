import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/infinity_logo.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../domain/models/player.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';
import '../widgets/game_board.dart';
import '../widgets/player_panel.dart';
import '../widgets/player_turn_indicator.dart';

/// First playable screen: local multiplayer board driven by [GameCubit].
class GameplayScreen extends StatelessWidget {
  const GameplayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameCubit(),
      child: const _GameplayBody(),
    );
  }
}

class _GameplayBody extends StatelessWidget {
  const _GameplayBody();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: _GameplayHeader(onBack: () => _handleBack(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.stackSm.h),
          const PlayerTurnIndicator(),
          SizedBox(height: AppSpacing.stackSm.h),
          const _MoveCounterPill(),
          SizedBox(height: AppSpacing.stackLg.h),
          const Expanded(
            child: _GameplayBoardArea(),
          ),
        ],
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
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: const Color(0x0D1D2330),
      borderRadius: AppSpacing.borderRadiusDefault,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: ScreenHeader(
          leadingIconAsset: IconConstant.home,
          leadingSemanticLabel: 'Back',
          onLeadingPressed: onBack,
          center: InfinityLogo(size: (AppSpacing.stackLg * 1.1).r),
          trailing: AppIconButton(
            iconAsset: IconConstant.restart,
            semanticLabel: 'Restart match',
            iconColor: AppColors.primary,
            backgroundColor: AppColors.surfaceContainerLowest,
            onPressed: () => context.read<GameCubit>().restart(),
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
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot.turnIndex != next.snapshot.turnIndex,
      builder: (context, state) {
        final moves = state.snapshot.turnIndex;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Moves',
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 0.7,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$moves',
                style: AppTextStyles.titleMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        );
      },
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
          padding: EdgeInsets.only(bottom: AppSpacing.stackMd.h),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GameBoard(),
                SizedBox(height: AppSpacing.stackLg.h),
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
