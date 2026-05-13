import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player.dart';
import '../state/game_cubit.dart';
import '../state/game_state.dart';

/// Bottom player card with symbol and active glow on that player's turn.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot.currentPlayer != next.snapshot.currentPlayer ||
          prev.snapshot.status != next.snapshot.status,
      builder: (context, state) {
        final snap = state.snapshot;
        final active =
            snap.status == GameStatus.playing && snap.currentPlayer == player;
        final isX = player == Player.x;
        final markColor = isX ? AppColors.softCoral : AppColors.teal;
        final accent = markColor;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(
              alpha: active ? 1 : 0.8,
            ),
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(
              color: active ? accent : AppColors.outlineVariant,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0D1D2330),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44.r,
                height: 44.r,
                child: SvgPicture.asset(
                  isX ? IconConstant.x : IconConstant.o,
                  colorFilter: ColorFilter.mode(
                    markColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isX ? 'Player X' : 'Player O',
                style: AppTextStyles.labelBold,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
