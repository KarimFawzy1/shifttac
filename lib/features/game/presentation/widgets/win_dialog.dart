import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/models/player.dart';

/// Win celebration modal aligned with `css/WinDialog.css` (tokens only).
class WinDialog extends StatelessWidget {
  const WinDialog({
    super.key,
    required this.winner,
    required this.totalMoves,
    required this.matchDurationMs,
    required this.onPlayAgain,
    required this.onBackToHome,
  });

  final Player winner;
  final int totalMoves;
  final int matchDurationMs;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToHome;

  static Future<void> show(
    BuildContext context, {
    required Player winner,
    required int totalMoves,
    required int matchDurationMs,
    required VoidCallback onPlayAgain,
    required VoidCallback onBackToHome,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.inkNavy.withValues(alpha: 0.35),
      builder: (dialogContext) {
        return WinDialog(
          winner: winner,
          totalMoves: totalMoves,
          matchDurationMs: matchDurationMs,
          onPlayAgain: () {
            Navigator.of(dialogContext).pop();
            onPlayAgain();
          },
          onBackToHome: () {
            Navigator.of(dialogContext).pop();
            onBackToHome();
          },
        );
      },
    );
  }

  String get _title => winner == Player.x ? 'X Wins!' : 'O Wins!';

  String _formatDuration() {
    final d = Duration(milliseconds: matchDurationMs);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final symbolSize = 72.r;
    final symbolColor =
        winner == Player.x ? AppColors.softCoral : AppColors.primary;
    final symbolAsset = winner == Player.x ? IconConstant.x : IconConstant.o;

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusXl,
        side: const BorderSide(color: AppColors.surfaceContainerHighest),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.stackLg.w),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 336.w),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.stackLg.h,
            AppSpacing.containerPadding.w,
            AppSpacing.stackMd.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                symbolAsset,
                width: symbolSize,
                height: symbolSize,
                colorFilter: ColorFilter.mode(symbolColor, BlendMode.srcIn),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(color: AppColors.onSurface),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                'Victory is yours.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppSpacing.borderRadiusMd,
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.stackMd.w),
                  child: Column(
                    children: [
                      _StatRow(
                        label: 'Total moves',
                        value: '$totalMoves',
                        showDivider: true,
                      ),
                      _StatRow(
                        label: 'Match time',
                        value: _formatDuration(),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              PrimaryButton(
                label: 'Play Again',
                leading: SvgPicture.asset(
                  IconConstant.restart,
                  width: 18.w,
                  height: 18.w,
                  colorFilter: const ColorFilter.mode(
                    AppColors.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: onPlayAgain,
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              SecondaryButton(
                label: 'Back to Home',
                leading: SvgPicture.asset(
                  IconConstant.home,
                  width: 18.w,
                  height: 18.w,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: onBackToHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
