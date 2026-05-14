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

/// Player card: inactive (muted white + 1px border) vs active (accent ring + glow).
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key, required this.player});

  static const Duration _panelAnimDuration = Duration(milliseconds: 220);
  static const Curve _panelAnimCurve = Curves.easeOutCubic;

  final Player player;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameState>(
      buildWhen: (prev, next) =>
          prev.snapshot.currentPlayer != next.snapshot.currentPlayer ||
          prev.snapshot.status != next.snapshot.status ||
          prev.snapshot.winner != next.snapshot.winner,
      builder: (context, state) {
        final snap = state.snapshot;
        final isPlaying = snap.status == GameStatus.playing;
        final isWinner = snap.status == GameStatus.won && snap.winner == player;
        final active = (isPlaying && snap.currentPlayer == player) || isWinner;

        final subtitleUpper = isWinner
            ? 'WINNER'
            : (active ? 'YOUR TURN' : 'Waiting ...');
        final isX = player == Player.x;
        final accent = isX ? AppColors.softCoral : AppColors.primary;

        final inactiveAvatarBg = isX
            ? AppColors.softCoral.withValues(alpha: 0.2)
            : AppColors.primaryContainer.withValues(alpha: 0.2);
        final activeAvatarBg = isX
            ? AppColors.softCoral.withValues(alpha: 0.3)
            : AppColors.primaryContainer.withValues(alpha: 0.3);

        final avatarSize = 49.w;
        final iconSizeLarge = isX ? 25.5.w : 29.w;
        final iconSizeSmall = isX ? 17.5.w : 20.w;

        final titleStyleInactive = AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w400,
          height: 26 / 16,
          color: AppColors.onSurfaceVariant,
        );
        final subtitleStyleInactive = AppTextStyles.labelSm.copyWith(
          fontWeight: FontWeight.w400,
          height: 14 / 12,
          color: AppColors.outline,
        );
        final titleStyleActive = AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w600,
          height: 26 / 16,
          color: accent,
        );
        final subtitleStyleActive = AppTextStyles.labelSm.copyWith(
          fontWeight: FontWeight.w500,
          height: 14 / 12,
          letterSpacing: 0.6,
          color: accent,
        );

        final decoration = active
            ? BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(color: accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              )
            : BoxDecoration(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(color: AppColors.surfaceVariant, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkNavy.withValues(alpha: 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              );

        return AnimatedContainer(
          duration: _panelAnimDuration,
          curve: _panelAnimCurve,
          clipBehavior: Clip.antiAlias,
          padding: active
              ? EdgeInsets.all(16.w)
              : EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
          decoration: decoration,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? activeAvatarBg : inactiveAvatarBg,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: _panelAnimDuration,
                            curve: _panelAnimCurve,
                            width: active ? iconSizeLarge : iconSizeSmall,
                            height: active ? iconSizeLarge : iconSizeSmall,
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SvgPicture.asset(
                                isX ? IconConstant.x : IconConstant.o,
                                width: iconSizeLarge,
                                height: iconSizeLarge,
                                colorFilter: ColorFilter.mode(
                                  accent,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 7.h),
                    Text(
                      isX ? 'Player X' : 'Player O',
                      style: active ? titleStyleActive : titleStyleInactive,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitleUpper,
                      style: active
                          ? subtitleStyleActive
                          : subtitleStyleInactive,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
