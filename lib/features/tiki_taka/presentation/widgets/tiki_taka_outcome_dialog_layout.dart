import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Formats elapsed match time as `m:ss`.
String formatTikiMatchDuration(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  final seconds = elapsed.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Shared stat card for Tiki-Taka outcome dialogs.
class TikiOutcomeStatsCard extends StatelessWidget {
  const TikiOutcomeStatsCard({
    super.key,
    required this.elapsed,
    required this.hearts,
  });

  final Duration elapsed;
  final int hearts;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
              label: 'Match time',
              value: formatTikiMatchDuration(elapsed),
              showDivider: true,
            ),
            _StatRow(
              label: 'Hearts remaining',
              value: '$hearts',
              showDivider: false,
            ),
          ],
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

/// Centered outcome modal shell shared by first-win, completion, and lost dialogs.
class TikiOutcomeDialogCard extends StatelessWidget {
  const TikiOutcomeDialogCard({
    super.key,
    required this.title,
    required this.body,
    required this.stats,
    required this.actions,
    this.icon,
  });

  final String title;
  final String body;
  final TikiOutcomeStatsCard stats;
  final Widget actions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final outerVerticalPadding = AppSpacing.stackLg.h + AppSpacing.stackMd.h;
    final maxHeight = mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.vertical -
        outerVerticalPadding;

    return Dialog(
      clipBehavior: Clip.none,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusXl,
        side: const BorderSide(color: AppColors.surfaceContainerHighest),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.stackLg.w),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 336.w,
          maxHeight: maxHeight.clamp(0.0, double.infinity),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding.w,
            AppSpacing.stackLg.h,
            AppSpacing.containerPadding.w,
            AppSpacing.stackMd.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                SizedBox(height: AppSpacing.stackLg.h),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.stackSm.h),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
              ),
              SizedBox(height: AppSpacing.stackLg.h),
              stats,
              SizedBox(height: AppSpacing.stackLg.h),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
